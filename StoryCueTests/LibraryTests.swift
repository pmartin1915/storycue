import XCTest
@testable import StoryCue

/// Library tests (S2b spec §8): a real SessionIndex and SegmentLedger in a fresh temp
/// directory, an Exporter over the S3 test doubles, and `fileSize` reading the real files
/// each test writes.
@MainActor
final class LibraryTests: XCTestCase {
    private struct Fixture {
        let library: Library
        let index: SessionIndex
        let ledger: SegmentLedger
        let exporter: Exporter
        let segmentDirectory: URL
        let temporaryRoot: URL
        let capacity: Int64?
        let fileState: @Sendable (URL) -> FileState
    }

    private let deck = Deck.v1Decks[0]
    private let savedOutcome: SegmentOutcome = .saved(url: URL(fileURLWithPath: "/unused"))

    private func makeFixture(
        capacity: Int64? = 10_000_000_000,
        fileState: @escaping @Sendable (URL) -> FileState = AppModel.attributesFileState
    ) throws -> Fixture {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryTests.\(UUID().uuidString)", isDirectory: true)
        let segmentDirectory = base.appendingPathComponent("Segments", isDirectory: true)
        let temporaryRoot = base.appendingPathComponent("Tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: segmentDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }

        let exporter = Exporter(
            segmentDirectory: segmentDirectory,
            temporaryRoot: temporaryRoot,
            stitcher: MockStitcher(),
            photos: MockPhotoLibrary(),
            availableCapacity: { capacity },
            fileSize: { fileState($0).size }
        )
        let index = SessionIndex(directory: segmentDirectory)
        let ledger = SegmentLedger(directory: segmentDirectory)
        let library = Library(
            segmentDirectory: segmentDirectory,
            index: index,
            ledger: ledger,
            exporter: exporter,
            availableCapacity: { capacity },
            fileState: fileState
        )
        return Fixture(
            library: library,
            index: index,
            ledger: ledger,
            exporter: exporter,
            segmentDirectory: segmentDirectory,
            temporaryRoot: temporaryRoot,
            capacity: capacity,
            fileState: fileState
        )
    }

    /// A second Library over the same directory (a "relaunch").
    private func makeSecondLibrary(_ fixture: Fixture) -> Library {
        let capacity = fixture.capacity
        return Library(
            segmentDirectory: fixture.segmentDirectory,
            index: SessionIndex(directory: fixture.segmentDirectory),
            ledger: SegmentLedger(directory: fixture.segmentDirectory),
            exporter: fixture.exporter,
            availableCapacity: { capacity },
            fileState: fixture.fileState
        )
    }

    private func noon(_ offsetSeconds: TimeInterval = 0) -> Date {
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 800_000_000))
        return day.addingTimeInterval(12 * 3600 + offsetSeconds)
    }

    private func makeSegment(
        _ fixture: Fixture,
        _ questionID: String,
        _ outcome: SegmentOutcome?,
        at startedAt: Date? = nil,
        bytes: Int = 4
    ) throws -> Segment {
        let id = UUID()
        if bytes > 0 {
            try Data(repeating: 0x01, count: bytes)
                .write(to: SegmentFiles.url(for: id, in: fixture.segmentDirectory))
        }
        return Segment(id: id, questionID: questionID, startedAt: startedAt ?? noon(), endReason: nil, outcome: outcome)
    }

    private func clip(_ questionID: String, _ segments: [Segment]) -> Clip {
        Clip(questionID: questionID, segments: segments)
    }

    private func makeRecord(
        _ clips: [Clip],
        finished: Bool = true,
        startedAt: Date? = nil,
        id: UUID = UUID()
    ) -> SessionRecord {
        SessionRecord(
            id: id,
            deckID: deck.id,
            deckTitle: deck.title,
            startedAt: startedAt ?? noon(),
            clips: clips,
            isFinished: finished
        )
    }

    private func recordLedger(_ fixture: Fixture, _ segment: Segment, finished: Bool = false) async throws {
        try await fixture.ledger.record(SegmentLedgerEntry(
            segmentID: segment.id,
            questionID: segment.questionID,
            fileURL: SegmentFiles.url(for: segment.id, in: fixture.segmentDirectory),
            startedAt: segment.startedAt,
            status: .writing
        ))
        if finished {
            try await fixture.ledger.markFinished(segment.id)
        }
    }

    private func fileExists(_ fixture: Fixture, _ segment: Segment) -> Bool {
        FileManager.default.fileExists(atPath: SegmentFiles.url(for: segment.id, in: fixture.segmentDirectory).path)
    }

    private func firstSegment(_ library: Library) -> Segment? {
        library.sessions.first?.clips.first?.segments.first
    }

    // MARK: - Checkpoint / finish

    func testCheckpointCreatesUnfinishedRecord() async throws {
        let fixture = try makeFixture()
        let library = fixture.library
        await library.load()
        let segment = try makeSegment(fixture, deck.questions[0].id, nil)
        let sessionID = UUID()

        library.checkpoint(
            sessionID: sessionID,
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[0].id, [segment])]
        )
        await library.waitForPendingSaves()

        XCTAssertEqual(library.sessions.count, 1)
        XCTAssertEqual(library.sessions.first?.id, sessionID)
        XCTAssertEqual(library.sessions.first?.isFinished, false)
        let onDisk = try await fixture.index.load()
        XCTAssertEqual(onDisk, library.sessions)
    }

    func testCheckpointIgnoresEmptyClips() async throws {
        let fixture = try makeFixture()
        let library = fixture.library
        await library.load()

        library.checkpoint(sessionID: UUID(), deck: deck, startedAt: noon(), clips: [])

        XCTAssertTrue(library.sessions.isEmpty)
    }

    func testCheckpointKeepsFinishedFlag() async throws {
        let fixture = try makeFixture()
        let library = fixture.library
        let first = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        let record = makeRecord([clip(deck.questions[0].id, [first])], finished: false)
        try await fixture.index.save([record])
        await library.load()
        XCTAssertEqual(library.sessions.first?.isFinished, true)

        let second = try makeSegment(fixture, deck.questions[1].id, savedOutcome)
        let newClips = [
            clip(deck.questions[0].id, [first]),
            clip(deck.questions[1].id, [second]),
        ]
        library.checkpoint(sessionID: record.id, deck: deck, startedAt: noon(), clips: newClips)

        XCTAssertEqual(library.sessions.count, 1)
        XCTAssertEqual(library.sessions.first?.clips, newClips)
        XCTAssertEqual(library.sessions.first?.isFinished, true)
    }

    func testCheckpointAfterFinishIgnored() async throws {
        let fixture = try makeFixture()
        let library = fixture.library
        await library.load()
        let sessionID = UUID()
        let segment = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        await library.finish(
            sessionID: sessionID,
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[0].id, [segment])]
        )
        let before = library.sessions

        let late = try makeSegment(fixture, deck.questions[1].id, nil)
        library.checkpoint(
            sessionID: sessionID,
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[1].id, [late])]
        )

        XCTAssertEqual(library.sessions, before)
        XCTAssertEqual(library.sessions.first?.isFinished, true)
    }

    func testFinishMarksFinished() async throws {
        let fixture = try makeFixture()
        let library = fixture.library
        await library.load()
        let sessionID = UUID()
        let first = try makeSegment(fixture, deck.questions[0].id, nil)
        library.checkpoint(
            sessionID: sessionID,
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[0].id, [first])]
        )
        XCTAssertEqual(library.sessions.first?.isFinished, false)

        var done = first
        done.outcome = savedOutcome
        let finalClips = [clip(deck.questions[0].id, [done])]
        await library.finish(sessionID: sessionID, deck: deck, startedAt: noon(), clips: finalClips)
        await library.waitForPendingSaves()

        XCTAssertEqual(library.sessions.count, 1)
        XCTAssertEqual(library.sessions.first?.isFinished, true)
        XCTAssertEqual(library.sessions.first?.clips, finalClips)
        let onDisk = try await fixture.index.load()
        XCTAssertEqual(onDisk, library.sessions)
    }

    func testFinishWithNothingKeepWorthyLeavesNoRecord() async throws {
        let fixture = try makeFixture()
        let library = fixture.library
        await library.load()
        let first = try makeSegment(fixture, deck.questions[0].id, .failed(kept: false))
        let second = try makeSegment(fixture, deck.questions[1].id, .failed(kept: false))
        try await recordLedger(fixture, first)
        try await recordLedger(fixture, second)

        await library.finish(
            sessionID: UUID(),
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[0].id, [first]), clip(deck.questions[1].id, [second])]
        )

        XCTAssertTrue(library.sessions.isEmpty)
        XCTAssertFalse(fileExists(fixture, first))
        XCTAssertFalse(fileExists(fixture, second))
        let entries = try await fixture.ledger.allEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    func testFinishKeepsNilSegmentWithBytes() async throws {
        let fixture = try makeFixture()
        let library = fixture.library
        await library.load()
        let segment = try makeSegment(fixture, deck.questions[0].id, nil)

        await library.finish(
            sessionID: UUID(),
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[0].id, [segment])]
        )

        XCTAssertEqual(library.sessions.count, 1)
        XCTAssertEqual(library.sessions.first?.isFinished, true)
        XCTAssertTrue(fileExists(fixture, segment))
    }

    // MARK: - Load / reconciliation

    func testLoadFinalizesInterruptedSession() async throws {
        let fixture = try makeFixture()
        let segment = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        try await fixture.index.save([makeRecord([clip(deck.questions[0].id, [segment])], finished: false)])

        await fixture.library.load()
        await fixture.library.waitForPendingSaves()

        XCTAssertEqual(fixture.library.sessions.first?.isFinished, true)
        let onDisk = try await fixture.index.load()
        XCTAssertEqual(onDisk.first?.isFinished, true)
    }

    func testLoadKeepsNilOutcomeWithFileAsRecovered() async throws {
        let fixture = try makeFixture()
        let segment = try makeSegment(fixture, deck.questions[0].id, nil)
        try await fixture.index.save([makeRecord([clip(deck.questions[0].id, [segment])], finished: false)])

        await fixture.library.load()

        let recovered = fixture.library.recovered
        XCTAssertEqual(recovered.map(\.id), [segment.id])
        XCTAssertNil(firstSegment(fixture.library)?.outcome)
        XCTAssertTrue(fileExists(fixture, segment))
    }

    func testLoadMarksNilOutcomeWithoutFileFailed() async throws {
        let fixture = try makeFixture()
        let segment = try makeSegment(fixture, deck.questions[0].id, nil, bytes: 0)
        try await recordLedger(fixture, segment)
        try await fixture.index.save([makeRecord([clip(deck.questions[0].id, [segment])], finished: false)])

        await fixture.library.load()

        XCTAssertEqual(firstSegment(fixture.library)?.outcome, .failed(kept: false))
        XCTAssertTrue(fixture.library.recovered.isEmpty)
        let entries = try await fixture.ledger.allEntries()
        XCTAssertEqual(entries.map(\.status), [.finished])
    }

    func testLoadSynthesizesRecordFromUnindexedLedgerEntries() async throws {
        let fixture = try makeFixture()
        let first = try makeSegment(fixture, deck.questions[0].id, nil, at: noon(0))
        let second = try makeSegment(fixture, deck.questions[1].id, nil, at: noon(60))
        try await recordLedger(fixture, first, finished: true)
        try await recordLedger(fixture, second)

        await fixture.library.load()

        XCTAssertEqual(fixture.library.sessions.count, 1)
        guard let record = fixture.library.sessions.first else { return }
        XCTAssertEqual(record.deckID, deck.id)
        XCTAssertEqual(record.deckTitle, deck.title)
        XCTAssertTrue(record.isFinished)
        XCTAssertEqual(record.clips.map(\.questionID), [deck.questions[0].id, deck.questions[1].id])
        XCTAssertEqual(record.clips[0].segments.first?.id, first.id)
        XCTAssertEqual(record.clips[0].segments.first?.outcome, .failed(kept: true))
        XCTAssertEqual(record.clips[1].segments.first?.id, second.id)
        XCTAssertNil(record.clips[1].segments.first?.outcome)
        XCTAssertEqual(fixture.library.recovered.map(\.id), [second.id])
    }

    func testLoadSkipsNoFileEntryAndAdoptsNoDeckFile() async throws {
        let fixture = try makeFixture()
        let noFile = try makeSegment(fixture, deck.questions[0].id, nil, bytes: 0)
        let noDeck = try makeSegment(fixture, "nonexistent.deck.1", nil)
        try await recordLedger(fixture, noFile)
        try await recordLedger(fixture, noDeck)

        await fixture.library.load()

        // The no-file entry makes no record. The no-deck file has bytes: it is never deleted,
        // and the sweep adopts it (docs/S2B-STORAGE-SWEEP-SPEC.md decision 1).
        XCTAssertEqual(fixture.library.sessions.count, 1)
        XCTAssertEqual(fixture.library.sessions.first?.deckID, "unsorted")
        XCTAssertEqual(fixture.library.recovered.map(\.id), [noDeck.id])
        XCTAssertTrue(fileExists(fixture, noDeck))
        XCTAssertTrue(fixture.library.isLoaded)
    }

    func testLoadQuarantinesUnreadableIndex() async throws {
        let fixture = try makeFixture()
        let indexURL = fixture.segmentDirectory.appendingPathComponent("session-index.json")
        let garbage = Data("not json".utf8)
        try garbage.write(to: indexURL)
        let segment = try makeSegment(fixture, deck.questions[0].id, nil)
        try await recordLedger(fixture, segment)

        await fixture.library.load()
        await fixture.library.waitForPendingSaves()

        let names = try FileManager.default.contentsOfDirectory(atPath: fixture.segmentDirectory.path)
        let aside = names.filter { $0.hasPrefix("session-index.unreadable-") && $0.hasSuffix(".json") }
        XCTAssertEqual(aside.count, 1)
        if let name = aside.first {
            let kept = try Data(contentsOf: fixture.segmentDirectory.appendingPathComponent(name))
            XCTAssertEqual(kept, garbage)
        }
        XCTAssertEqual(fixture.library.sessions.count, 1)
        // The rebuilt index replaced the unreadable one on disk.
        let rebuilt = try await fixture.index.load()
        XCTAssertEqual(rebuilt.count, 1)
    }

    func testLoadPurgesStaleExports() async throws {
        let fixture = try makeFixture()
        let stale = fixture.temporaryRoot
            .appendingPathComponent("Exports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
        try Data([0x00]).write(to: stale.appendingPathComponent("old.mov"))

        await fixture.library.load()

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
    }

    func testLoadIsIdempotent() async throws {
        let fixture = try makeFixture()
        let segment = try makeSegment(fixture, deck.questions[0].id, nil)
        try await fixture.index.save([makeRecord([clip(deck.questions[0].id, [segment])], finished: false)])

        await fixture.library.load()
        let first = fixture.library.sessions
        await fixture.library.load()

        XCTAssertEqual(fixture.library.sessions, first)
        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(fixture.library.isLoaded)
    }

    func testLoadNoOpWhileSessionActive() async throws {
        let fixture = try makeFixture()
        let segment = try makeSegment(fixture, deck.questions[0].id, nil)
        try await fixture.index.save([makeRecord([clip(deck.questions[0].id, [segment])], finished: false)])
        fixture.library.activeSessionID = UUID()

        await fixture.library.load()
        await fixture.library.waitForPendingSaves()

        XCTAssertFalse(fixture.library.isLoaded)
        XCTAssertTrue(fixture.library.sessions.isEmpty)
        let onDisk = try await fixture.index.load()
        XCTAssertEqual(onDisk.first?.isFinished, false)
    }

    func testLoadReadErrorSuspendsSaves() async throws {
        let fixture = try makeFixture()
        // A directory where the index file should be: reading it fails, but not as a decode error.
        let indexURL = fixture.segmentDirectory.appendingPathComponent("session-index.json")
        try FileManager.default.createDirectory(at: indexURL, withIntermediateDirectories: true)
        let library = fixture.library

        await library.load()

        XCTAssertTrue(library.isLoaded)
        XCTAssertTrue(library.sessions.isEmpty)
        var isDirectory: ObjCBool = false
        let stillThere = FileManager.default.fileExists(atPath: indexURL.path, isDirectory: &isDirectory)
        XCTAssertTrue(stillThere)
        XCTAssertTrue(isDirectory.boolValue)

        let segment = try makeSegment(fixture, deck.questions[0].id, nil)
        library.checkpoint(
            sessionID: UUID(),
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[0].id, [segment])]
        )
        await library.waitForPendingSaves()

        XCTAssertEqual(library.sessions.count, 1)   // in memory only
        let inside = try FileManager.default.contentsOfDirectory(atPath: indexURL.path)
        XCTAssertTrue(inside.isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: fixture.segmentDirectory.path)
        XCTAssertFalse(names.contains { $0.hasSuffix(".tmp") })
        XCTAssertFalse(names.contains { $0.hasPrefix("session-index.unreadable-") })
    }

    func testMutationsIgnoredBeforeLoad() async throws {
        let fixture = try makeFixture()
        let segment = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        let record = makeRecord([clip(deck.questions[0].id, [segment])])
        try await fixture.index.save([record])
        let library = fixture.library

        let deleted = await library.delete(sessionID: record.id)
        library.checkpoint(
            sessionID: UUID(),
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[0].id, [segment])]
        )

        XCTAssertFalse(deleted)
        XCTAssertTrue(library.sessions.isEmpty)
        XCTAssertTrue(fileExists(fixture, segment))
    }

    // MARK: - Keep / discard

    func testKeepFlagsClip() async throws {
        let fixture = try makeFixture()
        let segment = try makeSegment(fixture, deck.questions[0].id, nil)
        try await recordLedger(fixture, segment)
        try await fixture.index.save([makeRecord([clip(deck.questions[0].id, [segment])], finished: false)])
        let library = fixture.library
        await library.load()
        guard let recovered = library.recovered.first else { return XCTFail("expected a recovered clip") }

        await library.keep(recovered)

        XCTAssertEqual(firstSegment(library)?.outcome, .failed(kept: true))
        XCTAssertTrue(library.recovered.isEmpty)
        let entries = try await fixture.ledger.allEntries()
        XCTAssertEqual(entries.map(\.status), [.finished])
        XCTAssertEqual(library.sessions.first?.manifest.count, 1)
    }

    func testDiscardRemovesFileAndLedgerEntry() async throws {
        let fixture = try makeFixture()
        let kept = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        let undecided = try makeSegment(fixture, deck.questions[1].id, nil)
        try await recordLedger(fixture, kept, finished: true)
        try await recordLedger(fixture, undecided)
        try await fixture.index.save([makeRecord([
            clip(deck.questions[0].id, [kept]),
            clip(deck.questions[1].id, [undecided]),
        ], finished: false)])
        let library = fixture.library
        await library.load()
        guard let recovered = library.recovered.first else { return XCTFail("expected a recovered clip") }

        await library.discard(recovered)

        XCTAssertFalse(fileExists(fixture, undecided))
        XCTAssertTrue(fileExists(fixture, kept))
        let entries = try await fixture.ledger.allEntries()
        XCTAssertEqual(entries.map(\.segmentID), [kept.id])
        XCTAssertEqual(library.sessions.first?.clips[1].segments.first?.outcome, .failed(kept: false))
    }

    func testDiscardLastClipDeletesSession() async throws {
        let fixture = try makeFixture()
        let segment = try makeSegment(fixture, deck.questions[0].id, nil)
        try await recordLedger(fixture, segment)
        let record = makeRecord([clip(deck.questions[0].id, [segment])], finished: false)
        try await fixture.index.save([record])
        let library = fixture.library
        await library.load()
        guard let recovered = library.recovered.first else { return XCTFail("expected a recovered clip") }

        await library.discard(recovered)

        XCTAssertNil(library.record(id: record.id))
        XCTAssertFalse(fileExists(fixture, segment))
    }

    func testKeepRefusedForActiveSession() async throws {
        let fixture = try makeFixture()
        let segment = try makeSegment(fixture, deck.questions[0].id, nil)
        let record = makeRecord([clip(deck.questions[0].id, [segment])], finished: false)
        try await fixture.index.save([record])
        let library = fixture.library
        await library.load()
        library.activeSessionID = record.id

        await library.keep(RecoveredClip(sessionID: record.id, segment: segment))

        XCTAssertNil(firstSegment(library)?.outcome)
        XCTAssertTrue(library.recovered.isEmpty)   // the active session's nil is a live recording
    }

    // MARK: - Delete

    func testDeleteRemovesFilesLedgerAndRecord() async throws {
        let fixture = try makeFixture()
        let first = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        let second = try makeSegment(fixture, deck.questions[1].id, savedOutcome)
        try await recordLedger(fixture, first, finished: true)
        try await recordLedger(fixture, second, finished: true)
        let record = makeRecord([clip(deck.questions[0].id, [first]), clip(deck.questions[1].id, [second])])
        try await fixture.index.save([record])
        let library = fixture.library
        await library.load()

        let deleted = await library.delete(sessionID: record.id)
        await library.waitForPendingSaves()

        XCTAssertTrue(deleted)
        XCTAssertFalse(fileExists(fixture, first))
        XCTAssertFalse(fileExists(fixture, second))
        let entries = try await fixture.ledger.allEntries()
        XCTAssertTrue(entries.isEmpty)
        XCTAssertNil(library.record(id: record.id))
        let onDisk = try await fixture.index.load()
        XCTAssertTrue(onDisk.isEmpty)
    }

    func testDeleteAbortsWhenFileRemains() async throws {
        let stuckID = UUID()
        let stubbedState: @Sendable (URL) -> FileState = { url in
            if SegmentFiles.segmentID(from: url) == stuckID { return .present(4) }
            return AppModel.attributesFileState(url)
        }
        let fixture = try makeFixture(fileState: stubbedState)
        let first = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        let stuckFile = SegmentFiles.url(for: stuckID, in: fixture.segmentDirectory)
        try Data([0x01]).write(to: stuckFile)
        let stuck = Segment(
            id: stuckID,
            questionID: deck.questions[1].id,
            startedAt: noon(),
            endReason: nil,
            outcome: savedOutcome
        )
        try await recordLedger(fixture, first, finished: true)
        try await recordLedger(fixture, stuck, finished: true)
        let record = makeRecord([clip(deck.questions[0].id, [first]), clip(deck.questions[1].id, [stuck])])
        try await fixture.index.save([record])
        let library = fixture.library
        await library.load()

        let deleted = await library.delete(sessionID: record.id)

        XCTAssertFalse(deleted)
        XCTAssertNotNil(library.record(id: record.id))
        let entries = try await fixture.ledger.allEntries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(library.canDelete(record.id))   // not left in deletingSessionIDs
    }

    func testDeleteRefusedForActiveSession() async throws {
        let fixture = try makeFixture()
        let segment = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        let record = makeRecord([clip(deck.questions[0].id, [segment])])
        try await fixture.index.save([record])
        let library = fixture.library
        await library.load()
        library.activeSessionID = record.id

        let deleted = await library.delete(sessionID: record.id)

        XCTAssertFalse(deleted)
        XCTAssertNotNil(library.record(id: record.id))
        XCTAssertTrue(fileExists(fixture, segment))
    }

    func testDeleteRefusedWhileExporting() async throws {
        let fixture = try makeFixture()
        let segment = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        let record = makeRecord([clip(deck.questions[0].id, [segment])])
        try await fixture.index.save([record])
        let library = fixture.library
        await library.load()

        library.beginExport(record.id)
        let refused = await library.delete(sessionID: record.id)
        XCTAssertFalse(refused)
        XCTAssertNotNil(library.record(id: record.id))

        library.endExport(record.id)
        let allowed = await library.delete(sessionID: record.id)
        XCTAssertTrue(allowed)
    }

    // MARK: - Storage

    func testStorageLowBelowThreshold() async throws {
        let low = try makeFixture(capacity: 999_999_999)
        await low.library.load()
        XCTAssertTrue(low.library.storage.isLow)

        let edge = try makeFixture(capacity: 1_000_000_000)
        await edge.library.load()
        XCTAssertFalse(edge.library.storage.isLow)

        let unknown = try makeFixture(capacity: nil)
        await unknown.library.load()
        XCTAssertNil(unknown.library.storage.availableBytes)
        XCTAssertFalse(unknown.library.storage.isLow)
    }

    func testStorageCountsMovFilesOnly() async throws {
        let fixture = try makeFixture()
        let first = try makeSegment(fixture, deck.questions[0].id, savedOutcome, bytes: 3)
        let second = try makeSegment(fixture, deck.questions[1].id, savedOutcome, bytes: 5)
        try await recordLedger(fixture, first, finished: true)
        try Data("junk".utf8).write(to: fixture.segmentDirectory.appendingPathComponent("notes.txt"))
        try await fixture.index.save([makeRecord([
            clip(deck.questions[0].id, [first]),
            clip(deck.questions[1].id, [second]),
        ])])

        await fixture.library.load()

        XCTAssertEqual(fixture.library.storage.usedBytes, 8)
    }

    // MARK: - Storage sweep (docs/S2B-STORAGE-SWEEP-SPEC.md)

    private func bareFile(_ fixture: Fixture, bytes: Int) throws -> UUID {
        let id = UUID()
        try Data(repeating: 0x02, count: bytes).write(to: SegmentFiles.url(for: id, in: fixture.segmentDirectory))
        return id
    }

    private func movExists(_ fixture: Fixture, _ id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: SegmentFiles.url(for: id, in: fixture.segmentDirectory).path)
    }

    func testLoadDeletesZeroByteUnreferencedMov() async throws {
        let fixture = try makeFixture()
        let emptyID = try bareFile(fixture, bytes: 0)
        let segment = Segment(id: emptyID, questionID: deck.questions[0].id, startedAt: noon(), endReason: nil, outcome: nil)
        try await recordLedger(fixture, segment)

        await fixture.library.load()

        XCTAssertFalse(movExists(fixture, emptyID))
        XCTAssertTrue(fixture.library.sessions.isEmpty)
        let entries = try await fixture.ledger.allEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    func testLoadAdoptsUnreferencedMovWithBytes() async throws {
        let fixture = try makeFixture()
        let bareID = try bareFile(fixture, bytes: 6)

        await fixture.library.load()
        await fixture.library.waitForPendingSaves()

        XCTAssertTrue(movExists(fixture, bareID))
        XCTAssertEqual(fixture.library.sessions.count, 1)
        let record = try XCTUnwrap(fixture.library.sessions.first)
        XCTAssertNil(record.deck)
        XCTAssertEqual(record.deckTitle, UICopy.unsortedRecordingsTitle)
        XCTAssertTrue(record.isFinished)
        XCTAssertEqual(fixture.library.recovered.map(\.id), [bareID])
        XCTAssertEqual(fixture.library.storage.usedBytes, 6)

        let second = makeSecondLibrary(fixture)
        await second.load()
        XCTAssertEqual(second.sessions.count, 1)   // not duplicated
        XCTAssertEqual(second.sessions.first?.id, record.id)
    }

    func testLoadAdoptsLedgerEntryWithUnknownDeck() async throws {
        let fixture = try makeFixture()
        let orphan = try makeSegment(fixture, "nonexistent.deck.9", nil)
        try await recordLedger(fixture, orphan, finished: true)

        await fixture.library.load()

        XCTAssertEqual(fixture.library.recovered.map(\.id), [orphan.id])
        XCTAssertTrue(fileExists(fixture, orphan))
    }

    func testAdoptedClipCanBeDiscarded() async throws {
        let fixture = try makeFixture()
        let bareID = try bareFile(fixture, bytes: 6)
        let library = fixture.library
        await library.load()
        let adopted = try XCTUnwrap(library.recovered.first)

        await library.discard(adopted)

        XCTAssertFalse(movExists(fixture, bareID))
        XCTAssertTrue(library.sessions.isEmpty)
        XCTAssertEqual(library.storage.usedBytes, 0)
    }

    func testLoadSweepNeverTouchesReferencedFiles() async throws {
        let fixture = try makeFixture()
        let saved = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        let keptFailure = try makeSegment(fixture, deck.questions[1].id, .failed(kept: true))
        let undecided = try makeSegment(fixture, deck.questions[2].id, nil)
        let undecidedEmpty = try makeSegment(fixture, deck.questions[3].id, nil, bytes: 0)
        try await fixture.index.save([makeRecord([
            clip(deck.questions[0].id, [saved]),
            clip(deck.questions[1].id, [keptFailure]),
            clip(deck.questions[2].id, [undecided]),
            clip(deck.questions[3].id, [undecidedEmpty]),
        ])])

        await fixture.library.load()

        XCTAssertTrue(fileExists(fixture, saved))
        XCTAssertTrue(fileExists(fixture, keptFailure))
        XCTAssertTrue(fileExists(fixture, undecided))
        XCTAssertEqual(fixture.library.sessions.count, 1)   // nothing adopted
    }

    func testLoadSweepSkippedWhenIndexUnreadable() async throws {
        let fixture = try makeFixture()
        try FileManager.default.createDirectory(
            at: fixture.segmentDirectory.appendingPathComponent("session-index.json"),
            withIntermediateDirectories: true
        )
        let emptyID = try bareFile(fixture, bytes: 0)
        let fullID = try bareFile(fixture, bytes: 5)

        await fixture.library.load()

        XCTAssertTrue(fixture.library.isLoaded)
        XCTAssertTrue(movExists(fixture, emptyID))
        XCTAssertTrue(movExists(fixture, fullID))
        XCTAssertTrue(fixture.library.sessions.isEmpty)
    }

    func testLoadSweepSkippedWhenLedgerUnreadable() async throws {
        let fixture = try makeFixture()
        try Data("not json".utf8)
            .write(to: fixture.segmentDirectory.appendingPathComponent("segment-ledger.json"))
        let emptyID = try bareFile(fixture, bytes: 0)
        let fullID = try bareFile(fixture, bytes: 5)

        await fixture.library.load()

        XCTAssertTrue(movExists(fixture, emptyID))
        XCTAssertTrue(movExists(fixture, fullID))
        XCTAssertTrue(fixture.library.sessions.isEmpty)
    }

    func testFinishDeletesUnkeptFailureFilesInKeptSession() async throws {
        let fixture = try makeFixture()
        let library = fixture.library
        await library.load()
        let good = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        let partial = try makeSegment(fixture, deck.questions[1].id, .failed(kept: false))
        let undecided = try makeSegment(fixture, deck.questions[2].id, nil)
        try await recordLedger(fixture, good, finished: true)
        try await recordLedger(fixture, partial, finished: true)

        await library.finish(
            sessionID: UUID(),
            deck: deck,
            startedAt: noon(),
            clips: [
                clip(deck.questions[0].id, [good]),
                clip(deck.questions[1].id, [partial]),
                clip(deck.questions[2].id, [undecided]),
            ]
        )

        XCTAssertEqual(library.sessions.count, 1)
        XCTAssertTrue(fileExists(fixture, good))
        XCTAssertTrue(fileExists(fixture, undecided))
        XCTAssertFalse(fileExists(fixture, partial))
        let entries = try await fixture.ledger.allEntries()
        XCTAssertEqual(entries.map(\.segmentID), [good.id])
    }

    func testLoadDeletesUnkeptFailureFilesInKeptSession() async throws {
        let fixture = try makeFixture()
        let good = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        let partial = try makeSegment(fixture, deck.questions[1].id, .failed(kept: false))
        try await recordLedger(fixture, partial, finished: true)
        try await fixture.index.save([makeRecord([
            clip(deck.questions[0].id, [good]),
            clip(deck.questions[1].id, [partial]),
        ])])

        await fixture.library.load()

        XCTAssertTrue(fileExists(fixture, good))
        XCTAssertFalse(fileExists(fixture, partial))
        XCTAssertEqual(fixture.library.storage.usedBytes, 4)
        let entries = try await fixture.ledger.allEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    func testFinishNothingKeptKeepsLedgerEntryWhenRemovalFails() async throws {
        let stuckID = UUID()
        // The stub keeps reporting this file after removeItem, as if the removal had failed.
        let stubbedState: @Sendable (URL) -> FileState = { url in
            SegmentFiles.segmentID(from: url) == stuckID ? .present(4) : AppModel.attributesFileState(url)
        }
        let fixture = try makeFixture(fileState: stubbedState)
        let library = fixture.library
        await library.load()
        let removable = try makeSegment(fixture, deck.questions[0].id, .failed(kept: false))
        let stuckURL = SegmentFiles.url(for: stuckID, in: fixture.segmentDirectory)
        try Data([0x01, 0x02, 0x03, 0x04]).write(to: stuckURL)
        let stuck = Segment(
            id: stuckID, questionID: deck.questions[1].id, startedAt: noon(), endReason: nil,
            outcome: .failed(kept: false)
        )
        try await recordLedger(fixture, removable)
        try await recordLedger(fixture, stuck, finished: true)

        await library.finish(
            sessionID: UUID(),
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[0].id, [removable]), clip(deck.questions[1].id, [stuck])]
        )

        XCTAssertTrue(library.sessions.isEmpty)
        let entries = try await fixture.ledger.allEntries()
        XCTAssertEqual(entries.map(\.segmentID), [stuckID])

        // The surviving file stays recoverable: the next launch rebuilds it from the ledger.
        try Data([0x01, 0x02, 0x03, 0x04]).write(to: stuckURL)   // the real removal succeeded; restore the bytes
        let relaunch = makeSecondLibrary(fixture)
        await relaunch.load()
        XCTAssertEqual(relaunch.sessions.first?.clips.first?.segments.first?.id, stuckID)
    }

    func testLoadRemovesStrayTempFilesOnly() async throws {
        let fixture = try makeFixture()
        let directory = fixture.segmentDirectory
        let indexTemp = directory.appendingPathComponent("session-index.\(UUID().uuidString).tmp")
        let ledgerTemp = directory.appendingPathComponent("segment-ledger.\(UUID().uuidString).tmp")
        let unrelated = directory.appendingPathComponent("notes.tmp")
        let lookalike = directory.appendingPathComponent("session-index.keep.tmp")
        let quarantined = directory.appendingPathComponent("session-index.unreadable-20260101-000000-ABCDEFGH.json")
        for url in [indexTemp, ledgerTemp, unrelated, lookalike, quarantined] {
            try Data("x".utf8).write(to: url)
        }
        let segment = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        try await fixture.index.save([makeRecord([clip(deck.questions[0].id, [segment])])])

        await fixture.library.load()

        XCTAssertFalse(FileManager.default.fileExists(atPath: indexTemp.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ledgerTemp.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: lookalike.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: quarantined.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("session-index.json").path))
        XCTAssertTrue(fileExists(fixture, segment))
    }

    // MARK: - Ordering / persistence

    func testSessionsNewestFirst() async throws {
        let fixture = try makeFixture()
        let older = makeRecord([], startedAt: noon(-86_400 * 3))
        let newest = makeRecord([], startedAt: noon(86_400))
        let middle = makeRecord([], startedAt: noon())
        try await fixture.index.save([older, newest, middle])

        await fixture.library.load()

        XCTAssertEqual(fixture.library.sessions.map(\.id), [newest.id, middle.id, older.id])
    }

    func testRecordsPersistAcrossInstances() async throws {
        let fixture = try makeFixture()
        let library = fixture.library
        await library.load()
        let sessionID = UUID()
        let segment = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        await library.finish(
            sessionID: sessionID,
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[0].id, [segment])]
        )
        await library.waitForPendingSaves()

        let second = makeSecondLibrary(fixture)
        await second.load()

        XCTAssertEqual(second.sessions, library.sessions)
        XCTAssertEqual(second.sessions.first?.id, sessionID)
    }

    // MARK: - Unreadable stats and shared references (PR #8 audit)

    /// A segment `fileState` reports `.unreadable` for: its bytes are written, the stub hides them.
    private func makeUnreadableSegment(
        _ fixture: Fixture,
        id: UUID,
        _ questionID: String,
        _ outcome: SegmentOutcome?
    ) throws -> Segment {
        try Data([0x01, 0x02, 0x03, 0x04]).write(to: SegmentFiles.url(for: id, in: fixture.segmentDirectory))
        return Segment(id: id, questionID: questionID, startedAt: noon(), endReason: nil, outcome: outcome)
    }

    func testLoadLeavesUnreadableUndecidedSegmentUndecided() async throws {
        let unreadableID = UUID()
        let fixture = try makeFixture(fileState: { url in
            SegmentFiles.segmentID(from: url) == unreadableID ? .unreadable : AppModel.attributesFileState(url)
        })
        let segment = try makeUnreadableSegment(fixture, id: unreadableID, deck.questions[0].id, nil)
        try await recordLedger(fixture, segment)
        try await fixture.index.save([makeRecord([clip(deck.questions[0].id, [segment])], finished: false)])

        await fixture.library.load()

        XCTAssertNil(firstSegment(fixture.library)?.outcome)
        XCTAssertEqual(fixture.library.recovered.map(\.id), [unreadableID])
        XCTAssertTrue(fileExists(fixture, segment))
        let entries = try await fixture.ledger.allEntries()
        XCTAssertEqual(entries.map(\.status), [.writing])

        // The stat reads fine on the next launch: the clip is still undecided, its file intact.
        await fixture.library.waitForPendingSaves()
        let capacity = fixture.capacity
        let relaunch = Library(
            segmentDirectory: fixture.segmentDirectory,
            index: SessionIndex(directory: fixture.segmentDirectory),
            ledger: SegmentLedger(directory: fixture.segmentDirectory),
            exporter: fixture.exporter,
            availableCapacity: { capacity },
            fileState: AppModel.attributesFileState
        )
        await relaunch.load()
        XCTAssertNil(relaunch.sessions.first?.clips.first?.segments.first?.outcome)
        XCTAssertTrue(fileExists(fixture, segment))
    }

    func testFinishNothingKeptKeepsLedgerEntryWhenStatFails() async throws {
        let stuckID = UUID()
        // removeItem really succeeds; the stat afterwards fails, so "gone" is not proven.
        let fixture = try makeFixture(fileState: { url in
            SegmentFiles.segmentID(from: url) == stuckID ? .unreadable : AppModel.attributesFileState(url)
        })
        let library = fixture.library
        await library.load()
        let stuck = try makeUnreadableSegment(fixture, id: stuckID, deck.questions[0].id, .failed(kept: false))
        try await recordLedger(fixture, stuck, finished: true)

        await library.finish(
            sessionID: UUID(),
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[0].id, [stuck])]
        )

        XCTAssertTrue(library.sessions.isEmpty)
        let entries = try await fixture.ledger.allEntries()
        XCTAssertEqual(entries.map(\.segmentID), [stuckID])
    }

    func testDeleteAbortsWhenStatFails() async throws {
        let stuckID = UUID()
        let fixture = try makeFixture(fileState: { url in
            SegmentFiles.segmentID(from: url) == stuckID ? .unreadable : AppModel.attributesFileState(url)
        })
        let stuck = try makeUnreadableSegment(fixture, id: stuckID, deck.questions[0].id, savedOutcome)
        try await recordLedger(fixture, stuck, finished: true)
        let record = makeRecord([clip(deck.questions[0].id, [stuck])])
        try await fixture.index.save([record])
        let library = fixture.library
        await library.load()

        let deleted = await library.delete(sessionID: record.id)

        XCTAssertFalse(deleted)
        XCTAssertNotNil(library.record(id: record.id))
        let entries = try await fixture.ledger.allEntries()
        XCTAssertEqual(entries.map(\.segmentID), [stuckID])
    }

    func testLoadSweepKeepsFileAnotherRecordSaved() async throws {
        let fixture = try makeFixture()
        let shared = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        var unkeptCopy = shared
        unkeptCopy.outcome = .failed(kept: false)
        try await recordLedger(fixture, shared, finished: true)
        try await fixture.index.save([
            makeRecord([clip(deck.questions[0].id, [shared])]),
            makeRecord([clip(deck.questions[0].id, [unkeptCopy])], startedAt: noon(60)),
        ])

        await fixture.library.load()

        XCTAssertTrue(fileExists(fixture, shared))
        let entries = try await fixture.ledger.allEntries()
        XCTAssertEqual(entries.map(\.segmentID), [shared.id])
    }

    func testFinishKeepsFileAnotherRecordSaved() async throws {
        let fixture = try makeFixture()
        let library = fixture.library
        await library.load()
        let shared = try makeSegment(fixture, deck.questions[0].id, savedOutcome)
        try await recordLedger(fixture, shared, finished: true)
        await library.finish(
            sessionID: UUID(),
            deck: deck,
            startedAt: noon(),
            clips: [clip(deck.questions[0].id, [shared])]
        )
        var unkeptCopy = shared
        unkeptCopy.outcome = .failed(kept: false)
        let good = try makeSegment(fixture, deck.questions[1].id, savedOutcome)

        // Kept branch, then nothing-kept branch: neither may delete the shared file.
        await library.finish(
            sessionID: UUID(),
            deck: deck,
            startedAt: noon(60),
            clips: [clip(deck.questions[0].id, [unkeptCopy]), clip(deck.questions[1].id, [good])]
        )
        await library.finish(
            sessionID: UUID(),
            deck: deck,
            startedAt: noon(120),
            clips: [clip(deck.questions[0].id, [unkeptCopy])]
        )

        XCTAssertTrue(fileExists(fixture, shared))
        let entries = try await fixture.ledger.allEntries()
        XCTAssertEqual(entries.map(\.segmentID), [shared.id])
    }

    func testAttributesFileStateDistinguishesMissingFromUnreadable() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileStateTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("\(UUID().uuidString).mov")

        XCTAssertEqual(AppModel.attributesFileState(file), .missing)
        try Data([0x01, 0x02, 0x03]).write(to: file)
        XCTAssertEqual(AppModel.attributesFileState(file), .present(3))

        // A directory with no permissions: stat of its child fails with EACCES, not ENOENT.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: directory.path)
        let locked = AppModel.attributesFileState(file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        if locked == .present(3) {
            throw XCTSkip("permissions not enforced for this process (running as root?)")
        }
        XCTAssertEqual(locked, .unreadable)
    }
}
