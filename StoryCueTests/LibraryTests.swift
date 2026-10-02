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
        let fileSize: @Sendable (URL) -> Int64?
    }

    private let deck = Deck.v1Decks[0]
    private let savedOutcome: SegmentOutcome = .saved(url: URL(fileURLWithPath: "/unused"))

    private func makeFixture(
        capacity: Int64? = 10_000_000_000,
        fileSize: @escaping @Sendable (URL) -> Int64? = AppModel.attributesFileSize
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
            fileSize: fileSize
        )
        let index = SessionIndex(directory: segmentDirectory)
        let ledger = SegmentLedger(directory: segmentDirectory)
        let library = Library(
            segmentDirectory: segmentDirectory,
            index: index,
            ledger: ledger,
            exporter: exporter,
            availableCapacity: { capacity },
            fileSize: fileSize
        )
        return Fixture(
            library: library,
            index: index,
            ledger: ledger,
            exporter: exporter,
            segmentDirectory: segmentDirectory,
            temporaryRoot: temporaryRoot,
            capacity: capacity,
            fileSize: fileSize
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
            fileSize: fixture.fileSize
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

    func testLoadSkipsUnindexedEntryWithoutFileOrDeck() async throws {
        let fixture = try makeFixture()
        let noFile = try makeSegment(fixture, deck.questions[0].id, nil, bytes: 0)
        let noDeck = try makeSegment(fixture, "nonexistent.deck.1", nil)
        try await recordLedger(fixture, noFile)
        try await recordLedger(fixture, noDeck)

        await fixture.library.load()

        XCTAssertTrue(fixture.library.sessions.isEmpty)
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
        let stubbedSize: @Sendable (URL) -> Int64? = { url in
            if SegmentFiles.segmentID(from: url) == stuckID { return 4 }
            return AppModel.attributesFileSize(url)
        }
        let fixture = try makeFixture(fileSize: stubbedSize)
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
}
