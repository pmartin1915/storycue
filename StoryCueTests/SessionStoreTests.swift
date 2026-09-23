import XCTest
@testable import StoryCue

/// SessionStore integration tests: real SegmentLedger + reducer + effect queue, with
/// MockCaptureService and FakeBackgroundTaskRunner underneath. Spec: docs/S1-SESSIONSTORE-SPEC.md §7.
@MainActor
final class SessionStoreTests: XCTestCase {
    private struct Fixture {
        let store: SessionStore
        let mock: MockCaptureService
        let ledger: SegmentLedger
        let background: FakeBackgroundTaskRunner
        let directory: URL
    }

    private let deck = Deck.v1Decks[0]

    private func makeStore() async -> Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let ledger = SegmentLedger(directory: directory)
        let mock = MockCaptureService()
        let background = FakeBackgroundTaskRunner()
        let store = SessionStore(
            deck: deck,
            capture: mock,
            ledger: ledger,
            segmentDirectory: directory,
            background: background
        )
        return Fixture(store: store, mock: mock, ledger: ledger, background: background, directory: directory)
    }

    /// The id and startedAt of the currently-.recording segment, or nil.
    private func currentRecording(_ store: SessionStore) -> (id: UUID, startedAt: Date)? {
        guard case let .recording(id) = store.state.phase,
              let segment = store.state.clips.flatMap(\.segments).first(where: { $0.id == id })
        else { return nil }
        return (id, segment.startedAt)
    }

    // MARK: - Ledger / capture ordering

    func testTapRecordRecordsLedgerWritingBeforeCaptureStart() async throws {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        store.send(.tapRecord)
        await store.waitForIdleEffects()

        guard let recording = currentRecording(store) else { return XCTFail("expected .recording") }

        // The ledger holds exactly one .writing entry, recorded before the capture start,
        // and its fileURL is the same URL SegmentFiles hands to the capture service.
        let entries = try await fixture.ledger.orphanedEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].status, .writing)
        XCTAssertEqual(entries[0].questionID, deck.questions[0].id)
        XCTAssertEqual(entries[0].fileURL, SegmentFiles.url(for: recording.id, in: fixture.directory))
        XCTAssertEqual(
            entries[0].startedAt.timeIntervalSinceReferenceDate,
            recording.startedAt.timeIntervalSinceReferenceDate,
            accuracy: 0.001
        )

        let started = await fixture.mock.startedSegments
        XCTAssertEqual(started.map(\.id), [recording.id])
    }

    func testSegmentFinishedEventMarksLedgerFinished() async throws {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        store.send(.tapRecord)
        await store.waitForIdleEffects()
        guard let recording = currentRecording(store) else { return XCTFail("expected .recording") }

        // Normal ordering: pause requests the finish, then the finish delegate arrives.
        store.send(.tapPause)
        await store.waitForIdleEffects()
        await fixture.mock.simulate(.segmentFinished(
            segmentID: recording.id,
            outcome: .saved(url: SegmentFiles.url(for: recording.id, in: fixture.directory))
        ))
        await store.waitForIdleEffects()

        XCTAssertEqual(store.state.phase, .paused(reason: .userPause))
        let orphans = try await fixture.ledger.orphanedEntries()
        XCTAssertTrue(orphans.isEmpty, "finished segment must not remain a .writing orphan")
    }

    func testEffectsExecuteInOrderAcrossSends() async {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        // Two back-to-back sends: the FIFO effect queue must run start-then-stop, never
        // reversed.
        store.send(.tapRecord)
        store.send(.tapPause)
        await store.waitForIdleEffects()

        let recording = currentRecording(store)
        XCTAssertNil(recording)   // already finishing/paused
        let started = await fixture.mock.startedSegments
        let stopped = await fixture.mock.stoppedSegmentIDs
        XCTAssertEqual(started.count, 1)
        XCTAssertEqual(stopped, [started[0].id])
        // The ordering claim itself: the separate arrays above would pass even if the stop
        // had run first.
        let callLog = await fixture.mock.callLog
        XCTAssertEqual(callLog, ["start:\(started[0].id)", "stop:\(started[0].id)"])
        guard case .finishing = store.state.phase else {
            return XCTFail("expected .finishing after tapPause, got \(store.state.phase)")
        }
    }

    // MARK: - Start failure

    func testStartFailurePausesWithoutStop() async throws {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        await fixture.mock.setStubStartError(.deviceUnavailable)

        store.send(.tapRecord)
        await store.waitForIdleEffects()

        // Capture never started, so no finish callback can come: the store must not wait in
        // .finishing for one. It pauses directly, requests no stop, and closes the ledger entry.
        XCTAssertEqual(store.state.phase, .paused(reason: .outputEndedUnexpectedly))
        let segments = store.state.clips.flatMap(\.segments)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.outcome, .failed(kept: false))
        let stopped = await fixture.mock.stoppedSegmentIDs
        XCTAssertTrue(stopped.isEmpty, "nothing was recording, so nothing to stop")
        let orphans = try await fixture.ledger.orphanedEntries()
        XCTAssertTrue(orphans.isEmpty, "the failed start must not leave a .writing entry")
    }

    func testStartFailureNotAuthorizedSetsAvailability() async {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        await fixture.mock.setStubStartError(.notAuthorized)

        store.send(.tapRecord)
        await store.waitForIdleEffects()

        XCTAssertEqual(store.captureAvailability, .notAuthorized)
    }

    // MARK: - Background tasks

    func testBackgroundTaskBeginsAndEndsAroundBackgroundedFinish() async {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        store.send(.tapRecord)
        await store.waitForIdleEffects()
        guard let recording = currentRecording(store) else { return XCTFail("expected .recording") }

        store.send(.sceneWillResignActive)
        await store.waitForIdleEffects()
        XCTAssertEqual(fixture.background.callLog, ["begin"])

        store.send(.sceneDidEnterBackground)
        await store.waitForIdleEffects()
        guard case let .finishing(id, .sceneBackgrounded) = store.state.phase else {
            return XCTFail("expected .finishing(id, .sceneBackgrounded), got \(store.state.phase)")
        }
        XCTAssertEqual(id, recording.id)
        // The task is NOT ended by backgrounding itself — only by the finish exit.
        XCTAssertEqual(fixture.background.callLog, ["begin"])

        await fixture.mock.simulate(.segmentFinished(
            segmentID: id,
            outcome: .saved(url: SegmentFiles.url(for: id, in: fixture.directory))
        ))
        await store.waitForIdleEffects()
        XCTAssertEqual(fixture.background.callLog, ["begin", "end"])
        XCTAssertEqual(store.state.phase, .paused(reason: .sceneBackgrounded))
    }

    func testBackgroundExpirationEndsTask() async {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        store.send(.tapRecord)
        await store.waitForIdleEffects()

        store.send(.sceneWillResignActive)
        await store.waitForIdleEffects()
        XCTAssertEqual(fixture.background.beginCount, 1)

        fixture.background.fireExpiration()
        await store.waitForIdleEffects()

        XCTAssertEqual(fixture.background.endCount, 1)
        XCTAssertFalse(store.state.backgroundTaskActive)
        // The reducer's .backgroundTaskExpired handling ends the task (via the handler
        // itself, as UIKit requires) and emits no further effects.
        XCTAssertEqual(fixture.background.callLog, ["begin", "end"])
    }

    // MARK: - Thermal / media-services reset

    func testThermalRunsReduceFrameRateBeforeStop() async {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        store.send(.tapRecord)
        await store.waitForIdleEffects()

        store.send(.thermalPressureCritical)
        await store.waitForIdleEffects()

        let reduceFrameRateCount = await fixture.mock.reduceFrameRateCount
        XCTAssertEqual(reduceFrameRateCount, 1)
        let stopped = await fixture.mock.stoppedSegmentIDs
        XCTAssertEqual(stopped.count, 1)
    }

    func testMediaServicesResetRecreatesSession() async {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()

        await fixture.mock.simulate(.mediaServicesReset)
        await store.waitForIdleEffects()

        let recreateCount = await fixture.mock.recreateCount
        XCTAssertEqual(recreateCount, 1)
        XCTAssertEqual(store.captureAvailability, .ready)
    }

    func testMediaServicesResetWhileRecordingDoesNotWedge() async throws {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        store.send(.tapRecord)
        await store.waitForIdleEffects()
        guard let recording = currentRecording(store) else { return XCTFail("expected .recording") }

        // No finish callback is ever simulated: the rebuilt session lost it.
        await fixture.mock.simulate(.mediaServicesReset)
        await store.waitForIdleEffects()

        XCTAssertEqual(store.state.phase, .paused(reason: .mediaServicesReset))
        let segment = store.state.clips.flatMap(\.segments).first(where: { $0.id == recording.id })
        XCTAssertEqual(segment?.outcome, .failed(kept: true))
        let recreateCount = await fixture.mock.recreateCount
        XCTAssertEqual(recreateCount, 1)
        let orphans = try await fixture.ledger.orphanedEntries()
        XCTAssertTrue(orphans.isEmpty)
    }

    func testRecreateRefreshesAudioInput() async {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        await store.prepareCapture()
        XCTAssertTrue(store.hasAudioInput)

        await fixture.mock.setStubHasAudioInput(false)
        await fixture.mock.simulate(.mediaServicesReset)
        await store.waitForIdleEffects()

        XCTAssertFalse(store.hasAudioInput)
    }

    func testRecreateFailureMarksUnavailable() async {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        await fixture.mock.setStubRecreateError(.deviceUnavailable)

        await fixture.mock.simulate(.mediaServicesReset)
        await store.waitForIdleEffects()

        let recreateCount = await fixture.mock.recreateCount
        XCTAssertEqual(recreateCount, 1)
        XCTAssertEqual(store.captureAvailability, .unavailable)
    }

    // MARK: - Segment cap (the store owns time)

    func testTickPastCapSendsSegmentCapOnce() async {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        store.send(.tapRecord)
        await store.waitForIdleEffects()
        guard let recording = currentRecording(store) else { return XCTFail("expected .recording") }

        store.tick(now: recording.startedAt.addingTimeInterval(601))
        await store.waitForIdleEffects()
        store.tick(now: recording.startedAt.addingTimeInterval(602))
        await store.waitForIdleEffects()

        let stopped = await fixture.mock.stoppedSegmentIDs
        XCTAssertEqual(stopped, [recording.id], "exactly one stop for the capped segment")

        await fixture.mock.simulate(.segmentFinished(
            segmentID: recording.id,
            outcome: .saved(url: SegmentFiles.url(for: recording.id, in: fixture.directory))
        ))
        await store.waitForIdleEffects()
        XCTAssertEqual(store.state.phase, .paused(reason: .segmentCapReached))
    }

    func testTickBelowCapDoesNothing() async {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        store.send(.tapRecord)
        await store.waitForIdleEffects()
        guard let recording = currentRecording(store) else { return XCTFail("expected .recording") }

        store.tick(now: recording.startedAt.addingTimeInterval(599))
        await store.waitForIdleEffects()

        XCTAssertEqual(store.state.phase, .recording(segmentID: recording.id))
        let stopped = await fixture.mock.stoppedSegmentIDs
        XCTAssertTrue(stopped.isEmpty)
    }

    func testElapsedInSegmentZeroUnlessRecording() async {
        let fixture = await makeStore()
        let store = fixture.store
        store.start()
        await store.waitForIdleEffects()
        XCTAssertEqual(store.elapsedInSegment, 0)

        store.send(.tapRecord)
        await store.waitForIdleEffects()
        guard let recording = currentRecording(store) else { return XCTFail("expected .recording") }

        store.tick(now: recording.startedAt.addingTimeInterval(42))
        XCTAssertEqual(store.elapsedInSegment, 42, accuracy: 0.001)
    }

    // MARK: - Question navigation

    func testNextQuestionPreviewNilAtLastQuestion() async {
        let fixture = await makeStore()
        let store = fixture.store

        XCTAssertEqual(store.currentQuestion, deck.questions[0])
        XCTAssertEqual(store.nextQuestionPreview, deck.questions[1])

        for _ in 0..<(deck.questions.count - 1) {
            store.send(.tapSkip)
        }
        await store.waitForIdleEffects()

        XCTAssertEqual(store.currentQuestion, deck.questions[deck.questions.count - 1])
        XCTAssertNil(store.nextQuestionPreview)
    }

    // MARK: - prepareCapture

    func testPrepareCaptureDeniedCamera() async {
        let fixture = await makeStore()
        let store = fixture.store
        await fixture.mock.setStubAuthorization(CaptureAuthorization(camera: .denied, microphone: .authorized))

        await store.prepareCapture()

        XCTAssertEqual(store.captureAvailability, .notAuthorized)
        let configured = await fixture.mock.configured
        XCTAssertFalse(configured, "configureSession must not run without camera authorization")
    }

    func testPrepareCaptureRequestsWhenNotDetermined() async {
        let fixture = await makeStore()
        let store = fixture.store
        await fixture.mock.setStubAuthorization(CaptureAuthorization(camera: .notDetermined, microphone: .notDetermined))

        await store.prepareCapture()

        let requestAuthorizationCount = await fixture.mock.requestAuthorizationCount
        XCTAssertEqual(requestAuthorizationCount, 1)
        XCTAssertEqual(store.captureAvailability, .ready)
    }

    func testPrepareCaptureReportsNoAudio() async {
        let fixture = await makeStore()
        let store = fixture.store
        await fixture.mock.setStubHasAudioInput(false)

        await store.prepareCapture()

        XCTAssertFalse(store.hasAudioInput)
        XCTAssertEqual(store.captureAvailability, .ready)
    }

    // MARK: - Orphan recovery

    func testRecoverOrphansUsesSegmentIDNotStoredPath() async throws {
        let fixture = await makeStore()
        let store = fixture.store

        // The real file lives at the SegmentFiles-derived location...
        let segmentID = UUID()
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        let realURL = SegmentFiles.url(for: segmentID, in: fixture.directory)
        try Data([0x00, 0x01, 0x02]).write(to: realURL)
        // ...while the ledger entry's stored fileURL points into a container that no
        // longer exists (an absolute path recorded before an app update).
        let staleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("old-container-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("\(segmentID.uuidString).mov")
        try await fixture.ledger.record(SegmentLedgerEntry(
            segmentID: segmentID,
            questionID: "grandparents.001",
            fileURL: staleURL,
            startedAt: Date(),
            status: .writing
        ))

        await store.recoverOrphans()

        XCTAssertEqual(store.recoveredSegments.count, 1)
        XCTAssertEqual(store.recoveredSegments[0].entry.segmentID, segmentID)
        XCTAssertTrue(
            store.recoveredSegments[0].fileExists,
            "file existence must be checked at the SegmentFiles-derived path, not the stored one"
        )
    }

    func testRecoverOrphansReportsWritingEntries() async throws {
        let fixture = await makeStore()
        let store = fixture.store

        // One .writing entry whose file exists on disk (with bytes)...
        let existingID = UUID()
        let existingURL = SegmentFiles.url(for: existingID, in: fixture.directory)
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        try Data([0x00, 0x01, 0x02]).write(to: existingURL)
        // ...and one whose file was never written.
        let missingID = UUID()

        try await fixture.ledger.record(SegmentLedgerEntry(
            segmentID: existingID,
            questionID: "grandparents.001",
            fileURL: existingURL,
            startedAt: Date(),
            status: .writing
        ))
        try await fixture.ledger.record(SegmentLedgerEntry(
            segmentID: missingID,
            questionID: "grandparents.001",
            fileURL: SegmentFiles.url(for: missingID, in: fixture.directory),
            startedAt: Date(),
            status: .writing
        ))

        await store.recoverOrphans()

        XCTAssertEqual(store.recoveredSegments.count, 2)
        XCTAssertEqual(store.recoveredSegments[0].entry.segmentID, existingID)
        XCTAssertTrue(store.recoveredSegments[0].fileExists)
        XCTAssertEqual(store.recoveredSegments[1].entry.segmentID, missingID)
        XCTAssertFalse(store.recoveredSegments[1].fileExists)
    }
}
