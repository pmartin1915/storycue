import XCTest
@testable import StoryCue

/// ExportModel tests (S2b spec §8): real Library/SessionIndex/SegmentLedger in a temp
/// directory, an Exporter over MockStitcher / MockPhotoLibrary.
@MainActor
final class ExportModelTests: XCTestCase {
    private struct Fixture {
        let model: ExportModel
        let library: Library
        let stitcher: MockStitcher
        let segmentDirectory: URL
        let sessionID: UUID
        let segments: [Segment]
    }

    private let deck = Deck.v1Decks[0]
    private let savedOutcome: SegmentOutcome = .saved(url: URL(fileURLWithPath: "/unused"))

    /// Builds a loaded library holding one finished record. `layout` is one array of
    /// outcomes per clip; clip i is for question i. Every segment gets a real file.
    private func makeFixture(
        layout: [[SegmentOutcome?]],
        photosStatus: PhotoAddAuth = .authorized
    ) async throws -> Fixture {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportModelTests.\(UUID().uuidString)", isDirectory: true)
        let segmentDirectory = base.appendingPathComponent("Segments", isDirectory: true)
        let temporaryRoot = base.appendingPathComponent("Tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: segmentDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }

        let stitcher = MockStitcher()
        let exporter = Exporter(
            segmentDirectory: segmentDirectory,
            temporaryRoot: temporaryRoot,
            stitcher: stitcher,
            photos: MockPhotoLibrary(status: photosStatus),
            availableCapacity: { nil },
            fileSize: AppModel.attributesFileSize
        )
        let index = SessionIndex(directory: segmentDirectory)
        let library = Library(
            segmentDirectory: segmentDirectory,
            index: index,
            ledger: SegmentLedger(directory: segmentDirectory),
            exporter: exporter,
            availableCapacity: { nil },
            fileSize: AppModel.attributesFileSize
        )

        var allSegments: [Segment] = []
        var clips: [Clip] = []
        for (clipIndex, outcomes) in layout.enumerated() {
            let questionID = deck.questions[clipIndex].id
            var segments: [Segment] = []
            for outcome in outcomes {
                let id = UUID()
                try Data([0x01, 0x02, 0x03, 0x04]).write(to: SegmentFiles.url(for: id, in: segmentDirectory))
                let segment = Segment(
                    id: id,
                    questionID: questionID,
                    startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
                    endReason: nil,
                    outcome: outcome
                )
                segments.append(segment)
                allSegments.append(segment)
            }
            clips.append(Clip(questionID: questionID, segments: segments))
        }
        let record = SessionRecord(
            id: UUID(),
            deckID: deck.id,
            deckTitle: deck.title,
            startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            clips: clips,
            isFinished: true
        )
        try await index.save([record])
        await library.load()

        let model = ExportModel(sessionID: record.id, library: library, exporter: exporter)
        return Fixture(
            model: model,
            library: library,
            stitcher: stitcher,
            segmentDirectory: segmentDirectory,
            sessionID: record.id,
            segments: allSegments
        )
    }

    /// Polls until the model leaves `.running`.
    private func waitUntilSettled(_ model: ExportModel) async {
        for _ in 0..<500 {
            guard case .running = model.phase else { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("export did not settle")
    }

    func testCanExportFalseWithNothingSaved() async throws {
        let fixture = try await makeFixture(layout: [[nil]])

        XCTAssertFalse(fixture.model.canExport)
    }

    func testFilesExportGoesToSharing() async throws {
        let fixture = try await makeFixture(layout: [[savedOutcome], [savedOutcome]])
        let model = fixture.model
        XCTAssertTrue(model.canExport)

        model.start(.files)
        await waitUntilSettled(model)

        guard case let .sharing(result) = model.phase else {
            return XCTFail("expected .sharing, got \(model.phase)")
        }
        XCTAssertEqual(result.files.count, 2)
        XCTAssertTrue(fixture.library.exportingSessionIDs.contains(fixture.sessionID))
    }

    func testShareDismissedDiscardsTempDirectory() async throws {
        let fixture = try await makeFixture(layout: [[savedOutcome], [savedOutcome]])
        let model = fixture.model
        model.start(.files)
        await waitUntilSettled(model)
        guard case let .sharing(result) = model.phase else {
            return XCTFail("expected .sharing, got \(model.phase)")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.directory.path))

        await model.shareDismissed()

        XCTAssertFalse(FileManager.default.fileExists(atPath: result.directory.path))
        XCTAssertEqual(model.phase, .finished("Exported 2 videos."))
        XCTAssertTrue(fixture.library.exportingSessionIDs.isEmpty)

        // A second call is a no-op.
        await model.shareDismissed()
        XCTAssertEqual(model.phase, .finished("Exported 2 videos."))
    }

    func testPhotosExportFinishesWithCount() async throws {
        let fixture = try await makeFixture(layout: [[savedOutcome], [savedOutcome]])
        let model = fixture.model

        model.start(.photos)
        await waitUntilSettled(model)

        XCTAssertEqual(model.phase, .finished("Saved 2 videos to Photos."))
        XCTAssertTrue(fixture.library.exportingSessionIDs.isEmpty)
    }

    func testPhotosDeniedShowsMessage() async throws {
        let fixture = try await makeFixture(layout: [[savedOutcome]], photosStatus: .denied)
        let model = fixture.model

        model.start(.photos)
        await waitUntilSettled(model)

        XCTAssertEqual(model.phase, .failed(ExportFailure.photosDenied.userMessage))
    }

    func testCancelShowsCancelledMessage() async throws {
        let fixture = try await makeFixture(layout: [[savedOutcome]])
        let model = fixture.model
        await fixture.stitcher.setStallNextCall()

        model.start(.files)
        await fixture.stitcher.waitForCalls(1)
        await fixture.stitcher.waitForStall()
        model.cancel()
        await fixture.stitcher.resolveStall()
        await waitUntilSettled(model)

        XCTAssertEqual(model.phase, .failed(ExportFailure.cancelled.userMessage))
        XCTAssertTrue(fixture.library.exportingSessionIDs.isEmpty)
    }

    func testExportingFlagClearedOnFailure() async throws {
        let fixture = try await makeFixture(layout: [[savedOutcome]], photosStatus: .denied)
        let model = fixture.model

        model.start(.photos)
        XCTAssertTrue(fixture.library.exportingSessionIDs.contains(fixture.sessionID))
        await waitUntilSettled(model)

        guard case .failed = model.phase else {
            return XCTFail("expected .failed, got \(model.phase)")
        }
        XCTAssertTrue(fixture.library.exportingSessionIDs.isEmpty)
    }

    func testSummaryIncludesDroppedAndFlagged() async throws {
        // Clip 1: two saved segments, the second unreadable to the stitcher.
        // Clip 2: one kept-failed segment, so its output is flagged.
        let fixture = try await makeFixture(layout: [
            [savedOutcome, savedOutcome],
            [.failed(kept: true)],
        ])
        let unreadable = SegmentFiles.url(for: fixture.segments[1].id, in: fixture.segmentDirectory)
        await fixture.stitcher.setUnreadable([unreadable])
        let model = fixture.model

        model.start(.photos)
        await waitUntilSettled(model)

        let expected = "Saved 2 videos to Photos. "
            + "1 part couldn't be read and was left out. "
            + "Part of this export may be incomplete."
        XCTAssertEqual(model.phase, .finished(expected))
    }
}
