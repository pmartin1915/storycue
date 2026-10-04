import Foundation
import Observation

struct StorageStatus: Equatable, Sendable {
    static let lowSpaceThreshold: Int64 = 1_000_000_000   // on the struct, not the @MainActor class
    let usedBytes: Int64            // sum of *.mov sizes in the segment directory
    let availableBytes: Int64?      // nil when the volume won't say
    var isLow: Bool { availableBytes.map { $0 < Self.lowSpaceThreshold } ?? false }
}

/// What a stat of a segment file said. `unreadable` (the stat threw for any reason other than
/// "no such file") means "can't tell": never relabel or delete on it, never treat it as gone.
enum FileState: Equatable, Sendable {
    case missing
    case present(Int64)
    case unreadable

    var size: Int64? {
        if case let .present(size) = self { return size }
        return nil
    }
}

struct RecoveredClip: Equatable, Identifiable, Sendable {
    let sessionID: UUID
    let segment: Segment            // outcome == nil
    var id: UUID { segment.id }
}

/// The session library: the index is the source of truth, the ledger its recovery backstop
/// (S2b spec decision 1). Every mutation updates `sessions` synchronously on the main actor,
/// then enqueues a serial, ordered index save. The only code that deletes a segment file is
/// `delete`, `discard`, `finish` (unkept failures only) and the launch sweep (provably-unkept
/// files only, see docs/S2B-STORAGE-SWEEP-SPEC.md); the export path never does.
@MainActor
@Observable
final class Library {
    private(set) var sessions: [SessionRecord] = []      // newest startedAt first
    private(set) var storage = StorageStatus(usedBytes: 0, availableBytes: nil)
    private(set) var isLoaded = false
    private(set) var exportingSessionIDs: Set<UUID> = []
    var activeSessionID: UUID?                           // set/cleared by AppModel

    /// Nil-outcome segments in `sessions` order, excluding the active session's (that nil is
    /// a live recording).
    var recovered: [RecoveredClip] {
        var result: [RecoveredClip] = []
        for record in sessions where record.id != activeSessionID {
            for clip in record.clips {
                for segment in clip.segments where segment.outcome == nil {
                    result.append(RecoveredClip(sessionID: record.id, segment: segment))
                }
            }
        }
        return result
    }

    private let segmentDirectory: URL
    private let index: SessionIndex
    private let ledger: SegmentLedger
    private let exporter: Exporter
    private let availableCapacity: @Sendable () -> Int64?
    private let fileState: @Sendable (URL) -> FileState

    private var closedSessionIDs: Set<UUID> = []
    private var deletingSessionIDs: Set<UUID> = []
    private var savesSuspended = false
    private var isLoading = false
    private var saveTask: Task<Void, Never>?

    init(
        segmentDirectory: URL,
        index: SessionIndex,
        ledger: SegmentLedger,
        exporter: Exporter,
        availableCapacity: @escaping @Sendable () -> Int64?,
        fileState: @escaping @Sendable (URL) -> FileState
    ) {
        self.segmentDirectory = segmentDirectory
        self.index = index
        self.ledger = ledger
        self.exporter = exporter
        self.availableCapacity = availableCapacity
        self.fileState = fileState
    }

    // MARK: - Launch reconciliation (decision 4)

    private struct DayGroup: Hashable {
        let deckID: String
        let day: Date
    }

    func load() async {
        guard !isLoaded, !isLoading, activeSessionID == nil else { return }
        isLoading = true
        defer { isLoading = false }

        // 1. Nothing can be exporting at launch.
        await exporter.purgeStaleExports()

        // 2. Load the index.
        var records: [SessionRecord] = []
        var changed = false
        var skipReconciliation = false
        var ledgerReadable = false
        do {
            records = try await index.load()
        } catch is DecodingError {
            // Move the unreadable file aside, never overwrite or delete it. If even that
            // fails the file is still in the way: treat it like an I/O error.
            do {
                _ = try await index.quarantineUnreadable(now: Date())
                changed = true
            } catch {
                savesSuspended = true
                skipReconciliation = true
            }
        } catch {
            savesSuspended = true
            skipReconciliation = true
        }

        if !skipReconciliation {
            // 3. An app kill mid-session: the record is finished now.
            for i in records.indices where !records[i].isFinished {
                records[i].isFinished = true
                changed = true
            }

            // 4. Undecided segments: bytes on disk stay recovered, no bytes -> unkept failure.
            //    An unreadable stat is not "no bytes": the segment stays undecided.
            var emptyIDs: [UUID] = []
            for i in records.indices {
                for c in records[i].clips.indices {
                    for s in records[i].clips[c].segments.indices {
                        let segment = records[i].clips[c].segments[s]
                        guard segment.outcome == nil else { continue }
                        let url = SegmentFiles.url(for: segment.id, in: segmentDirectory)
                        let state = fileState(url)
                        if state == .unreadable { continue }
                        if let size = state.size, size > 0 { continue }
                        records[i].clips[c].segments[s].outcome = .failed(kept: false)
                        emptyIDs.append(segment.id)
                        changed = true
                    }
                }
            }
            for id in emptyIDs {
                try? await ledger.markFinished(id)
            }

            // 5. Ledger entries no record mentions.
            var knownIDs: Set<UUID> = []
            for record in records {
                for clip in record.clips {
                    for segment in clip.segments { knownIDs.insert(segment.id) }
                }
            }
            if let entries = try? await ledger.allEntries() {
                ledgerReadable = true
                let synthesized = synthesizeRecords(from: entries, excluding: knownIDs)
                if !synthesized.isEmpty {
                    records.append(contentsOf: synthesized)
                    changed = true
                }
            }
        }

        // Storage sweep (sweep spec decision 5). Needs proof: both the index and the ledger were
        // read, and no recording is live. Synchronous up to its single ledger cleanup await.
        if !skipReconciliation, ledgerReadable, activeSessionID == nil {
            let outcome = sweepStorage(records: &records)
            if outcome.adopted { changed = true }
            if !outcome.removedIDs.isEmpty {
                try? await ledger.remove(segmentIDs: outcome.removedIDs)
            }
        }

        // 6. Assign in one synchronous step after the last await.
        records.sort { $0.startedAt > $1.startedAt }
        sessions = records
        if changed { enqueueSave() }
        refreshStorage()
        isLoaded = true
    }

    private func synthesizeRecords(from entries: [SegmentLedgerEntry], excluding knownIDs: Set<UUID>) -> [SessionRecord] {
        let calendar = Calendar.current
        var groups: [DayGroup: [(entry: SegmentLedgerEntry, deck: Deck)]] = [:]
        for entry in entries where !knownIDs.contains(entry.segmentID) {
            let url = SegmentFiles.url(for: entry.segmentID, in: segmentDirectory)
            guard let size = fileState(url).size, size > 0 else { continue }
            guard let deck = Deck.v1Decks.first(where: { deck in
                deck.questions.contains { $0.id == entry.questionID }
            }) else { continue }
            let key = DayGroup(deckID: deck.id, day: calendar.startOfDay(for: entry.startedAt))
            groups[key, default: []].append((entry, deck))
        }

        var result: [SessionRecord] = []
        for (_, members) in groups {
            let sorted = members.sorted { $0.entry.startedAt < $1.entry.startedAt }
            guard let first = sorted.first else { continue }
            var questionOrder: [String] = []
            var segmentsByQuestion: [String: [Segment]] = [:]
            for member in sorted {
                let entry = member.entry
                let outcome: SegmentOutcome? = entry.status == .finished ? .failed(kept: true) : nil
                let segment = Segment(
                    id: entry.segmentID,
                    questionID: entry.questionID,
                    startedAt: entry.startedAt,
                    endReason: nil,
                    outcome: outcome
                )
                if segmentsByQuestion[entry.questionID] == nil {
                    questionOrder.append(entry.questionID)
                }
                segmentsByQuestion[entry.questionID, default: []].append(segment)
            }
            var clips: [Clip] = []
            for questionID in questionOrder {
                clips.append(Clip(questionID: questionID, segments: segmentsByQuestion[questionID] ?? []))
            }
            result.append(SessionRecord(
                id: UUID(),
                deckID: first.deck.id,
                deckTitle: first.deck.title,
                startedAt: first.entry.startedAt,
                clips: clips,
                isFinished: true
            ))
        }
        return result
    }

    // MARK: - Storage sweep (docs/S2B-STORAGE-SWEEP-SPEC.md)

    /// Deletes each segment's .mov and returns the IDs whose file is verifiably gone: already
    /// `.missing`, or removed without error and `.missing` afterwards. A failed removal or an
    /// unreadable stat is a survivor, so its ledger entry (and its record) stay.
    private func removeFiles(for ids: [UUID]) -> Set<UUID> {
        var gone: Set<UUID> = []
        for id in ids {
            let url = SegmentFiles.url(for: id, in: segmentDirectory)
            if fileState(url) == .missing {
                gone.insert(id)
                continue
            }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                continue
            }
            if fileState(url) == .missing { gone.insert(id) }
        }
        return gone
    }

    /// IDs some reference still needs: any outcome other than `.failed(kept: false)`. A file is
    /// deleted only when every reference to its ID is an unkept failure.
    private static func protectedIDs(in records: [SessionRecord]) -> Set<UUID> {
        var result: Set<UUID> = []
        for record in records {
            for clip in record.clips {
                for segment in clip.segments where !isUnkeptFailure(segment.outcome) {
                    result.insert(segment.id)
                }
            }
        }
        return result
    }

    /// Deletes only what is provably not part of a kept session: the file of a
    /// `.failed(kept: false)` segment, an unreferenced zero-byte `<UUID>.mov`, and a stray
    /// atomic-save temp file. An unreferenced `.mov` with bytes is adopted into one synthesized
    /// record for the user to keep or discard, never deleted.
    private func sweepStorage(records: inout [SessionRecord]) -> (removedIDs: Set<UUID>, adopted: Bool) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: segmentDirectory.path)) ?? []

        for name in names where Self.isStrayTemporaryName(name) {
            try? FileManager.default.removeItem(at: segmentDirectory.appendingPathComponent(name))
        }

        let protected = Self.protectedIDs(in: records)
        var referenced: Set<UUID> = []
        var unkept: [UUID] = []
        for record in records {
            for clip in record.clips {
                for segment in clip.segments {
                    referenced.insert(segment.id)
                    // Only a file that exists is swept (a missing one has nothing to delete), and
                    // never one another reference still needs.
                    if Self.isUnkeptFailure(segment.outcome),
                       !protected.contains(segment.id),
                       fileState(SegmentFiles.url(for: segment.id, in: segmentDirectory)) != .missing {
                        unkept.append(segment.id)
                    }
                }
            }
        }
        var removed = removeFiles(for: unkept)

        var emptyBare: [UUID] = []
        var adoptable: [(id: UUID, createdAt: Date)] = []
        for name in names {
            let url = segmentDirectory.appendingPathComponent(name)
            guard let id = SegmentFiles.segmentID(from: url), !referenced.contains(id) else { continue }
            guard let size = fileState(url).size else { continue }     // can't tell: leave it alone
            if size == 0 {
                emptyBare.append(id)
            } else {
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                adoptable.append((id, (attributes?[.creationDate] as? Date) ?? Date()))
            }
        }
        removed.formUnion(removeFiles(for: emptyBare))

        guard !adoptable.isEmpty else { return (removed, false) }
        adoptable.sort { $0.createdAt < $1.createdAt }
        let segments = adoptable.map {
            Segment(id: $0.id, questionID: Self.unknownQuestionID, startedAt: $0.createdAt, endReason: nil, outcome: nil)
        }
        records.append(SessionRecord(
            id: UUID(),
            deckID: Self.unsortedDeckID,
            deckTitle: UICopy.unsortedRecordingsTitle,
            startedAt: adoptable[0].createdAt,
            clips: [Clip(questionID: Self.unknownQuestionID, segments: segments)],
            isFinished: true
        ))
        return (removed, true)
    }

    private static let unknownQuestionID = "unknown"
    private static let unsortedDeckID = "unsorted"

    /// Exactly `session-index.<UUID>.tmp` / `segment-ledger.<UUID>.tmp`; nothing else.
    private static func isStrayTemporaryName(_ name: String) -> Bool {
        guard name.hasSuffix(".tmp") else { return false }
        let stem = String(name.dropLast(".tmp".count))
        for prefix in ["session-index.", "segment-ledger."] where stem.hasPrefix(prefix) {
            return UUID(uuidString: String(stem.dropFirst(prefix.count))) != nil
        }
        return false
    }

    // MARK: - Checkpoint / finish (decision 3)

    private static func isKeepWorthy(_ outcome: SegmentOutcome?) -> Bool {
        switch outcome {
        case .saved: return true
        case let .failed(kept): return kept
        case nil: return true
        }
    }

    private static func isUnkeptFailure(_ outcome: SegmentOutcome?) -> Bool {
        outcome == .failed(kept: false)
    }

    func checkpoint(sessionID: UUID, deck: Deck, startedAt: Date, clips: [Clip]) {
        guard isLoaded, !clips.isEmpty, !closedSessionIDs.contains(sessionID) else { return }
        if let i = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[i].clips = clips      // keeps its isFinished
        } else {
            insert(SessionRecord(
                id: sessionID,
                deckID: deck.id,
                deckTitle: deck.title,
                startedAt: startedAt,
                clips: clips,
                isFinished: false
            ))
        }
        enqueueSave()
        refreshStorage()
    }

    func finish(sessionID: UUID, deck: Deck, startedAt: Date, clips: [Clip]) async {
        guard isLoaded else { return }
        closedSessionIDs.insert(sessionID)

        var segments: [Segment] = []
        for clip in clips { segments.append(contentsOf: clip.segments) }

        if segments.contains(where: { Self.isKeepWorthy($0.outcome) }) {
            if let i = sessions.firstIndex(where: { $0.id == sessionID }) {
                sessions[i].clips = clips
                sessions[i].isFinished = true
            } else {
                insert(SessionRecord(
                    id: sessionID,
                    deckID: deck.id,
                    deckTitle: deck.title,
                    startedAt: startedAt,
                    clips: clips,
                    isFinished: true
                ))
            }
            enqueueSave()
            // Unkept failures inside a kept session: their files are unusable and excluded
            // from export. A surviving file keeps its ledger entry; a file another reference
            // still needs is not touched.
            let protected = Self.protectedIDs(in: sessions)
            let unkept = segments
                .filter { Self.isUnkeptFailure($0.outcome) && !protected.contains($0.id) }
                .map(\.id)
            let gone = removeFiles(for: unkept)
            refreshStorage()
            if !gone.isEmpty { try? await ledger.remove(segmentIDs: gone) }
            return
        }

        // Nothing worth keeping: no record, and the unusable files go. The reducer already
        // judged these segments unusable.
        sessions.removeAll { $0.id == sessionID }
        enqueueSave()
        // Only a verified-gone file loses its ledger entry; a survivor stays recoverable. A file
        // another record still needs is not touched.
        let protected = Self.protectedIDs(in: sessions)
        let gone = removeFiles(for: segments
            .filter { Self.isUnkeptFailure($0.outcome) && !protected.contains($0.id) }
            .map(\.id))
        try? await ledger.remove(segmentIDs: gone)
        refreshStorage()
    }

    private func insert(_ record: SessionRecord) {
        sessions.append(record)
        sessions.sort { $0.startedAt > $1.startedAt }
    }

    // MARK: - Recovered clips

    private func locate(segmentID: UUID, in sessionID: UUID) -> (session: Int, clip: Int, segment: Int)? {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return nil }
        for c in sessions[i].clips.indices {
            for s in sessions[i].clips[c].segments.indices
            where sessions[i].clips[c].segments[s].id == segmentID {
                return (i, c, s)
            }
        }
        return nil
    }

    private func canDecide(_ clip: RecoveredClip) -> (session: Int, clip: Int, segment: Int)? {
        guard isLoaded,
              clip.sessionID != activeSessionID,
              !deletingSessionIDs.contains(clip.sessionID),
              let position = locate(segmentID: clip.segment.id, in: clip.sessionID),
              sessions[position.session].clips[position.clip].segments[position.segment].outcome == nil
        else { return nil }
        return position
    }

    func keep(_ clip: RecoveredClip) async {
        guard let position = canDecide(clip) else { return }
        sessions[position.session].clips[position.clip].segments[position.segment].outcome = .failed(kept: true)
        enqueueSave()
        try? await ledger.markFinished(clip.segment.id)
    }

    func discard(_ clip: RecoveredClip) async {
        guard let position = canDecide(clip) else { return }
        // A file that is still there (or can't be stat'd) must stay visible: abort rather than hide it.
        guard removeFiles(for: [clip.segment.id]).contains(clip.segment.id) else { return }
        sessions[position.session].clips[position.clip].segments[position.segment].outcome = .failed(kept: false)
        enqueueSave()
        refreshStorage()
        try? await ledger.remove(segmentIDs: [clip.segment.id])

        guard let record = record(id: clip.sessionID) else { return }
        var hasKeepWorthy = false
        for recordClip in record.clips {
            for segment in recordClip.segments where Self.isKeepWorthy(segment.outcome) {
                hasKeepWorthy = true
            }
        }
        if !hasKeepWorthy {
            _ = await deleteUnchecked(sessionID: clip.sessionID)
        }
    }

    // MARK: - Delete (decision 5)

    func canDelete(_ sessionID: UUID) -> Bool {
        isLoaded
            && sessionID != activeSessionID
            && !exportingSessionIDs.contains(sessionID)
            && !deletingSessionIDs.contains(sessionID)
    }

    func canStartExport(_ sessionID: UUID) -> Bool {
        isLoaded
            && sessionID != activeSessionID
            && !exportingSessionIDs.contains(sessionID)
            && !deletingSessionIDs.contains(sessionID)
    }

    @discardableResult
    func delete(sessionID: UUID) async -> Bool {
        guard canDelete(sessionID) else { return false }
        return await deleteUnchecked(sessionID: sessionID)
    }

    /// Files -> verify -> ledger -> index. If any file survives the removal attempts the
    /// delete aborts before touching the ledger or the index.
    private func deleteUnchecked(sessionID: UUID) async -> Bool {
        guard let record = record(id: sessionID) else { return false }
        deletingSessionIDs.insert(sessionID)
        closedSessionIDs.insert(sessionID)

        var segmentIDs: [UUID] = []
        for clip in record.clips {
            for segment in clip.segments { segmentIDs.append(segment.id) }
        }
        let gone = removeFiles(for: segmentIDs)
        guard gone.count == Set(segmentIDs).count else {
            deletingSessionIDs.remove(sessionID)
            return false
        }

        try? await ledger.remove(segmentIDs: Set(segmentIDs))
        sessions.removeAll { $0.id == sessionID }
        enqueueSave()
        refreshStorage()
        deletingSessionIDs.remove(sessionID)
        return true
    }

    // MARK: - Export flag

    func beginExport(_ sessionID: UUID) {
        guard canStartExport(sessionID) else { return }
        exportingSessionIDs.insert(sessionID)
    }

    func endExport(_ sessionID: UUID) {
        exportingSessionIDs.remove(sessionID)
    }

    // MARK: - Storage, lookup, saves

    func refreshStorage() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: segmentDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        var used: Int64 = 0
        for url in urls where url.pathExtension == "mov" {
            used += fileState(url).size ?? 0
        }
        storage = StorageStatus(usedBytes: used, availableBytes: availableCapacity())
    }

    func record(id: UUID) -> SessionRecord? {
        sessions.first { $0.id == id }
    }

    /// Serial and ordered: each save is chained after the previous one and writes the
    /// snapshot taken when it was enqueued. A failed save is not retried; the next mutation
    /// saves the whole array again. Nothing is saved while `savesSuspended`.
    private func enqueueSave() {
        guard !savesSuspended else { return }
        let snapshot = sessions
        let index = self.index
        let previous = saveTask
        saveTask = Task {
            await previous?.value
            try? await index.save(snapshot)
        }
    }

    /// Test hook: resumes when every queued save has finished.
    func waitForPendingSaves() async {
        await saveTask?.value
    }

    #if DEBUG
    /// Part B demo only: sets `sessions` directly and `isLoaded = true` (so `load()` no-ops). No save.
    func seedForDemo(_ records: [SessionRecord]) {
        sessions = records
        isLoaded = true
    }
    #endif
}
