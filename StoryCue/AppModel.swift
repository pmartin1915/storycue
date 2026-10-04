import Foundation

/// One camera, one session at a time. A new `SessionStore` AND a new capture service per
/// recording session: `AsyncStream` is single-consumer, so a second store can't re-iterate
/// the first service's `events`. The ledger is one instance app-wide (one file, one actor).
@MainActor
@Observable
final class AppModel {
    struct ActiveSession {
        let id: UUID
        let startedAt: Date
        let deck: Deck
        let store: SessionStore
        let capture: any CaptureService
    }

    private(set) var active: ActiveSession?
    /// The session `endSession` just finished, when finish left a keep-worthy record.
    /// RootView binds this to a `navigationDestination(item:)`; `beginSession` clears it.
    var finishedSessionID: UUID?
    /// The shutdown + finish of the session `endSession` just closed. `beginSession` waits for
    /// it, so the camera is released and the old session stays protected until finish lands.
    @ObservationIgnored private var ending: Task<Void, Never>?
    let ledger: SegmentLedger
    let segmentDirectory: URL
    let library: Library
    let exporter: Exporter

    private let makeCapture: @MainActor (URL) -> any CaptureService
    private let makeBackground: @MainActor () -> any BackgroundTaskRunner

    /// attributesOfItem size, nil on error.
    nonisolated static let attributesFileSize: @Sendable (URL) -> Int64? = { url in
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value
    }

    /// attributesOfItem as a `FileState`: `.missing` only on a positive "no such file" error,
    /// any other error (or no size attribute) is `.unreadable`.
    nonisolated static let attributesFileState: @Sendable (URL) -> FileState = { url in
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = (attributes[.size] as? NSNumber)?.int64Value else { return .unreadable }
            return .present(size)
        } catch {
            return AppModel.isNoSuchFile(error as NSError) ? .missing : .unreadable
        }
    }

    nonisolated private static func isNoSuchFile(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain,
           error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError {
            return true
        }
        if error.domain == NSPOSIXErrorDomain, error.code == Int(ENOENT) { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return underlying.domain == NSPOSIXErrorDomain && underlying.code == Int(ENOENT)
        }
        return false
    }

    /// The volume's "important usage" available capacity for `url`, nil on error.
    nonisolated static func importantUsageCapacity(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    init(
        segmentDirectory: URL,
        makeCapture: @escaping @MainActor (URL) -> any CaptureService,
        makeBackground: @escaping @MainActor () -> any BackgroundTaskRunner,
        exporter: Exporter? = nil,
        availableCapacity: @escaping @Sendable () -> Int64? = { nil },
        fileState: @escaping @Sendable (URL) -> FileState = AppModel.attributesFileState
    ) {
        let ledger = SegmentLedger(directory: segmentDirectory)
        let resolvedExporter = exporter ?? Exporter(
            segmentDirectory: segmentDirectory,
            temporaryRoot: FileManager.default.temporaryDirectory,
            stitcher: AVStitcher(),
            photos: PHPhotoLibrarySaver(),
            availableCapacity: { AppModel.importantUsageCapacity(at: FileManager.default.temporaryDirectory) },
            fileSize: AppModel.attributesFileSize
        )
        self.segmentDirectory = segmentDirectory
        self.ledger = ledger
        self.exporter = resolvedExporter
        self.library = Library(
            segmentDirectory: segmentDirectory,
            index: SessionIndex(directory: segmentDirectory),
            ledger: ledger,
            exporter: resolvedExporter,
            availableCapacity: availableCapacity,
            fileState: fileState
        )
        self.makeCapture = makeCapture
        self.makeBackground = makeBackground
    }

    #if DEBUG
    /// Part B demo launch mode (`-StoryCueDemo`, used only by ScreenshotTests): swaps the
    /// camera preview for a warm gradient (RecorderView) and pre-seeds the library.
    var isDemo = false

    /// Demo wiring for the App Store screenshots: a temp segment directory, a
    /// `MockCaptureService` (default stubs are already authorized and report audio input),
    /// and two finished library records whose segment files are a few junk bytes written
    /// first (export is never exercised in demo mode). `seedForDemo` sets `isLoaded`, so
    /// the root `.task`'s `load()` no-ops and the seed is never re-read from disk.
    static func demo() -> AppModel {
        let segmentDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoryCueDemoSegments", isDirectory: true)
        try? FileManager.default.createDirectory(at: segmentDirectory, withIntermediateDirectories: true)

        let model = AppModel(
            segmentDirectory: segmentDirectory,
            makeCapture: { _ in MockCaptureService() },
            makeBackground: { UIKitBackgroundTaskRunner() },
            // The seed files are a few junk bytes; report a plausible clip size (only for files
            // that exist, so delete's "is it gone" check still works) and free space, so the
            // Recordings storage footer in the screenshot reads like a real phone.
            availableCapacity: { 96_000_000_000 },
            fileState: { url in
                let state = AppModel.attributesFileState(url)
                return state.size == nil ? state : .present(46_000_000)
            }
        )

        // Fixed recent dates at local noon so the Recordings list reads like a real week.
        let calendar = Calendar.current
        let grandparentsDay = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 12))
            ?? Date()
        let holidayTableDay = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12))
            ?? Date()

        var records: [SessionRecord] = []
        if let grandparents = Deck.v1Decks.first(where: { $0.id == "grandparents" }) {
            records.append(makeDemoRecord(deck: grandparents, clipCount: 3, startedAt: grandparentsDay, in: segmentDirectory))
        }
        if let holidayTable = Deck.v1Decks.first(where: { $0.id == "holiday-table" }) {
            records.append(makeDemoRecord(deck: holidayTable, clipCount: 5, startedAt: holidayTableDay, in: segmentDirectory))
        }
        model.library.seedForDemo(records)
        model.isDemo = true
        return model
    }

    /// One finished record: `clipCount` clips, one `.saved` segment each, using the deck's
    /// real first question IDs. Segment URLs come only from `SegmentFiles` and each file
    /// gets a few junk bytes before the record is built.
    private static func makeDemoRecord(deck: Deck, clipCount: Int, startedAt: Date, in directory: URL) -> SessionRecord {
        var clips: [Clip] = []
        for index in 0..<clipCount {
            let questionID = deck.questions[index].id
            let segmentID = UUID()
            let url = SegmentFiles.url(for: segmentID, in: directory)
            try? Data([0x00, 0x01, 0x02, 0x03, 0x04]).write(to: url)
            clips.append(Clip(
                questionID: questionID,
                segments: [Segment(
                    id: segmentID,
                    questionID: questionID,
                    startedAt: startedAt.addingTimeInterval(TimeInterval(index * 60)),
                    endReason: .userStop,
                    outcome: .saved(url: url)
                )]
            ))
        }
        return SessionRecord(
            id: UUID(),
            deckID: deck.id,
            deckTitle: deck.title,
            startedAt: startedAt,
            clips: clips,
            isFinished: true
        )
    }
    #endif

    /// Production wiring. Constructs NO capture service (the S1 nil-safety rule — nothing
    /// here touches a camera): the factories run inside `beginSession`, after the consent
    /// tap.
    static func production() -> AppModel {
        let segmentDirectory = (try? SegmentFiles.defaultDirectory())
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Segments", isDirectory: true)
        return AppModel(
            segmentDirectory: segmentDirectory,
            makeCapture: { AVCaptureService(segmentDirectory: $0) },
            makeBackground: { UIKitBackgroundTaskRunner() },
            availableCapacity: { AppModel.importantUsageCapacity(at: segmentDirectory) }
        )
    }

    private(set) var isPreparing = false

    /// Creates capture + store for `deck`, sets `active`, calls store.start(), sets
    /// isPreparing = true, awaits store.prepareCapture(), sets isPreparing = false.
    /// If a session is already active, does nothing. prepareCapture never throws
    /// (S1 §5 rule 5): failures land in store.captureAvailability, which the recorder shows
    /// as a blocking state — so `active` stays set on failure, by design, and the user
    /// leaves with "Done".
    func beginSession(deck: Deck) async {
        guard active == nil else { return }
        if let ending {
            await ending.value
            guard active == nil else { return }
        }
        finishedSessionID = nil
        let id = UUID()
        let startedAt = Date()
        let capture = makeCapture(segmentDirectory)
        let store = SessionStore(
            deck: deck,
            capture: capture,
            ledger: ledger,
            segmentDirectory: segmentDirectory,
            background: makeBackground(),
            archive: { [weak library = self.library] clips in
                library?.checkpoint(sessionID: id, deck: deck, startedAt: startedAt, clips: clips)
            }
        )
        active = ActiveSession(id: id, startedAt: startedAt, deck: deck, store: store, capture: capture)
        library.activeSessionID = id
        store.start()
        isPreparing = true
        await store.prepareCapture()
        isPreparing = false
    }

    /// Refuses (returns false, changes nothing) while isPreparing, or while the active
    /// store's phase is .recording or .finishing. The check, store.stop() and
    /// `active = nil` all happen synchronously on the main actor BEFORE the first await,
    /// so no event can slip between them (AppModel and SessionStore are both @MainActor);
    /// then the camera is released (`capture.shutdown()`) and the session is handed to the
    /// library. The clips captured here are final: this only proceeds from .idle/.paused,
    /// which the reducer reaches only after fileOutputFinished set the outcome; a still-queued
    /// .persistLedger only writes the ledger. No active session → true.
    @discardableResult
    func endSession() async -> Bool {
        guard let active else { return true }
        guard !isPreparing else { return false }
        switch active.store.state.phase {
        case .recording, .finishing:
            return false
        case .idle, .paused:
            break
        }
        let capture = active.capture
        let id = active.id
        let deck = active.deck
        let startedAt = active.startedAt
        let clips = active.store.state.clips
        active.store.stop()
        self.active = nil
        // activeSessionID is cleared only after finish: while the camera shuts down the
        // session must stay protected, or a delete/discard in that window is undone by
        // finish's stale clips. beginSession waits on `ending`, so nothing replaces the ID.
        let library = self.library
        let previous = ending
        let task = Task { @MainActor in
            await previous?.value
            await capture.shutdown()
            await library.finish(sessionID: id, deck: deck, startedAt: startedAt, clips: clips)
            if library.activeSessionID == id { library.activeSessionID = nil }
        }
        ending = task
        await task.value
        // Open the finished session only if nothing replaced it meanwhile: beginSession
        // also waits on `ending`, and its continuation may resume first and set `active`.
        if self.active == nil, library.record(id: id) != nil {   // self.: `active` here is the unwrapped local
            finishedSessionID = id
        }
        return true
    }
}
