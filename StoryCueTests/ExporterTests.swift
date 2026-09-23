import Photos
import XCTest
@testable import StoryCue

/// Exporter orchestration tests (S3 spec §6): MockStitcher + MockPhotoLibrary + a real
/// temp dir under FileManager.default.temporaryDirectory, with injected fileSize and
/// availableCapacity.
final class ExporterTests: XCTestCase {
    private struct Fixture {
        let exporter: Exporter
        let stitcher: MockStitcher
        let photos: MockPhotoLibrary
        let segmentDirectory: URL
        let temporaryRoot: URL
    }

    private let deck = Deck.v1Decks[0]

    private func makeFixture(
        photosStatus: PhotoAddAuth = .authorized,
        photosRequestResult: PhotoAddAuth = .authorized,
        capacity: Int64? = .max
    ) async throws -> Fixture {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExporterTests.\(UUID().uuidString)", isDirectory: true)
        let segmentDirectory = base.appendingPathComponent("Segments", isDirectory: true)
        let temporaryRoot = base.appendingPathComponent("Tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: segmentDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let stitcher = MockStitcher()
        let photos = MockPhotoLibrary(status: photosStatus, requestResult: photosRequestResult)
        // Production-shaped fileSize: attributesOfItem, nil for a missing file.
        let fileSize: @Sendable (URL) -> Int64? = { url in
            ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value
        }
        let exporter = Exporter(
            segmentDirectory: segmentDirectory,
            temporaryRoot: temporaryRoot,
            stitcher: stitcher,
            photos: photos,
            availableCapacity: { capacity },
            fileSize: fileSize
        )
        return Fixture(
            exporter: exporter,
            stitcher: stitcher,
            photos: photos,
            segmentDirectory: segmentDirectory,
            temporaryRoot: temporaryRoot
        )
    }

    /// A segment whose real file exists in the segment directory.
    private func seedSegment(questionID: String, in directory: URL, bytes: Int = 4) throws -> Segment {
        let id = UUID()
        let url = SegmentFiles.url(for: id, in: directory)
        try Data(Array(repeating: 0x01, count: bytes)).write(to: url)
        return Segment(id: id, questionID: questionID, startedAt: Date(), endReason: nil, outcome: .saved(url: url))
    }

    /// The per-export directories currently under <temporaryRoot>/Exports/.
    private func exportDirectories(_ fixture: Fixture) -> [URL] {
        let exports = fixture.temporaryRoot.appendingPathComponent("Exports", isDirectory: true)
        return (try? FileManager.default.contentsOfDirectory(
            at: exports,
            includingPropertiesForKeys: nil
        )) ?? []
    }

    private func exportError(
        _ fixture: Fixture,
        entries: [ClipManifestEntry],
        unit: ExportUnit = .perClip,
        destination: ExportDestination = .files
    ) async -> ExportFailure {
        do {
            _ = try await fixture.exporter.export(
                entries: entries,
                deck: deck,
                sessionDate: Date(),
                unit: unit,
                destination: destination
            )
            XCTFail("expected export to throw")
            return .failed(domain: "ExporterTests", code: -1)
        } catch let failure as ExportFailure {
            return failure
        } catch {
            XCTFail("expected ExportFailure, got \(error)")
            return .failed(domain: "ExporterTests", code: -1)
        }
    }

    func testFilesExportWritesOneFilePerClip() async throws {
        let fixture = try await makeFixture()
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let s2 = try seedSegment(questionID: q2, in: fixture.segmentDirectory)
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [s1]),
            ClipManifestEntry(questionID: q2, segments: [s2]),
        ]

        let result = try await fixture.exporter.export(
            entries: entries, deck: deck, sessionDate: Date(),
            unit: .perClip, destination: .files
        )

        XCTAssertEqual(result.files.count, 2)
        XCTAssertEqual(result.savedToPhotosCount, 0)
        XCTAssertTrue(result.dropped.isEmpty)
        XCTAssertTrue(result.flaggedSegmentIDs.isEmpty)
        for file in result.files {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        }
        XCTAssertEqual(result.files.map(\.deletingPathExtension.lastPathComponent).sorted(), [
            "StoryCue - Grandparents - \(Self.todayString()) - Q01",
            "StoryCue - Grandparents - \(Self.todayString()) - Q02",
        ].sorted())
        // .files keeps the temp directory for S2b's share sheet; discard(_:) removes it.
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.directory.path))
        await fixture.exporter.discard(result)
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.directory.path))
        let calls = await fixture.stitcher.calls
        XCTAssertEqual(calls.count, 2)
    }

    /// Today's date in the exporter's calendar (Gregorian, current time zone).
    private static func todayString() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    func testPhotosDeniedThrowsBeforeAnyStitch() async throws {
        let fixture = try await makeFixture(photosStatus: .denied)
        let q1 = deck.questions[0].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let entries = [ClipManifestEntry(questionID: q1, segments: [s1])]

        let error = await exportError(fixture, entries: entries, destination: .photos)

        XCTAssertEqual(error, .photosDenied)
        let calls = await fixture.stitcher.calls
        XCTAssertTrue(calls.isEmpty, "authorization resolves before any stitching")
    }

    func testPhotosNotDeterminedRequestsThenProceeds() async throws {
        let fixture = try await makeFixture(photosStatus: .notDetermined, photosRequestResult: .authorized)
        let q1 = deck.questions[0].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let entries = [ClipManifestEntry(questionID: q1, segments: [s1])]

        let result = try await fixture.exporter.export(
            entries: entries, deck: deck, sessionDate: Date(),
            unit: .perClip, destination: .photos
        )

        let requestCount = await fixture.photos.requestCount
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(result.savedToPhotosCount, 1)
        let saved = await fixture.photos.savedURLs
        XCTAssertEqual(saved, result.files)
        // The temp directory is removed after a successful Photos export.
        XCTAssertTrue(exportDirectories(fixture).isEmpty)
    }

    func testPhotosRestrictedThrows() async throws {
        let fixture = try await makeFixture(photosStatus: .restricted)
        let q1 = deck.questions[0].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let entries = [ClipManifestEntry(questionID: q1, segments: [s1])]

        let error = await exportError(fixture, entries: entries, destination: .photos)

        XCTAssertEqual(error, .photosRestricted)
        let calls = await fixture.stitcher.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testInsufficientSpaceThrowsBeforeAnyStitch() async throws {
        let fixture = try await makeFixture(capacity: 20)
        let q1 = deck.questions[0].id
        // 4 bytes each → totalSourceBytes 8 → needed Int64(8 * 1.1) = 8. Make it fail with
        // two 10-byte segments: total 20, needed 22 > 20 available.
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory, bytes: 10)
        let s2 = try seedSegment(questionID: q1, in: fixture.segmentDirectory, bytes: 10)
        let entries = [ClipManifestEntry(questionID: q1, segments: [s1, s2])]

        let error = await exportError(fixture, entries: entries)

        XCTAssertEqual(error, .insufficientSpace(neededBytes: 22, availableBytes: 20))
        let calls = await fixture.stitcher.calls
        XCTAssertTrue(calls.isEmpty, "preflight runs before any stitching")
    }

    func testNilCapacitySkipsPreflight() async throws {
        let fixture = try await makeFixture(capacity: nil)
        let q1 = deck.questions[0].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory, bytes: 10)
        let entries = [ClipManifestEntry(questionID: q1, segments: [s1])]

        let result = try await fixture.exporter.export(
            entries: entries, deck: deck, sessionDate: Date(),
            unit: .perClip, destination: .files
        )

        XCTAssertEqual(result.files.count, 1)
    }

    func testUnreadableSourcesMergedIntoDropped() async throws {
        let fixture = try await makeFixture()
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id
        // segA is a planner drop (missing file); segB is flagged but stitcher-unreadable;
        // segC stitches fine.
        let segA = Segment(
            id: UUID(), questionID: q1, startedAt: Date(), endReason: nil,
            outcome: .failed(kept: false)
        )
        let segB = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        var outcomeB = segB
        outcomeB.outcome = .failed(kept: true)
        let segC = try seedSegment(questionID: q2, in: fixture.segmentDirectory)
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [segA, outcomeB]),
            ClipManifestEntry(questionID: q2, segments: [segC]),
        ]
        await fixture.stitcher.setUnreadable([SegmentFiles.url(for: segB.id, in: fixture.segmentDirectory)])

        let result = try await fixture.exporter.export(
            entries: entries, deck: deck, sessionDate: Date(),
            unit: .perClip, destination: .files
        )

        XCTAssertEqual(result.files.count, 1, "clip 1 wrote nothing; clip 2 did")
        XCTAssertEqual(result.dropped, [
            DroppedSegment(segmentID: segA.id, questionID: q1, reason: .missingFile),
            DroppedSegment(segmentID: segB.id, questionID: q1, reason: .unreadable),
        ])
        XCTAssertEqual(
            result.flaggedSegmentIDs, [],
            "a flagged segment that wasn't stitched must not be reported as flagged"
        )
    }

    func testOutputWithNoReadableSourceIsSkippedOthersContinue() async throws {
        let fixture = try await makeFixture()
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id
        let bad = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let good = try seedSegment(questionID: q2, in: fixture.segmentDirectory)
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [bad]),
            ClipManifestEntry(questionID: q2, segments: [good]),
        ]
        await fixture.stitcher.setUnreadable([SegmentFiles.url(for: bad.id, in: fixture.segmentDirectory)])

        let result = try await fixture.exporter.export(
            entries: entries, deck: deck, sessionDate: Date(),
            unit: .perClip, destination: .files
        )

        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.dropped, [
            DroppedSegment(segmentID: bad.id, questionID: q1, reason: .unreadable)
        ])
        let calls = await fixture.stitcher.calls
        XCTAssertEqual(calls.count, 2, "the skipped output must not stop the others")
    }

    func testAllOutputsUnreadableThrowsNothingToExportAndLeavesNoDirectory() async throws {
        let fixture = try await makeFixture()
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let s2 = try seedSegment(questionID: q2, in: fixture.segmentDirectory)
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [s1]),
            ClipManifestEntry(questionID: q2, segments: [s2]),
        ]
        await fixture.stitcher.setUnreadable([
            SegmentFiles.url(for: s1.id, in: fixture.segmentDirectory),
            SegmentFiles.url(for: s2.id, in: fixture.segmentDirectory),
        ])

        let error = await exportError(fixture, entries: entries)

        XCTAssertEqual(error, .nothingToExport)
        XCTAssertTrue(exportDirectories(fixture).isEmpty, "a failed export leaves nothing behind")
    }

    func testWhollyUnreadableOutputSegmentsAppearInDropped() async throws {
        let fixture = try await makeFixture()
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id
        let bad1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let bad2 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let good = try seedSegment(questionID: q2, in: fixture.segmentDirectory)
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [bad1, bad2]),
            ClipManifestEntry(questionID: q2, segments: [good]),
        ]
        await fixture.stitcher.setUnreadable([
            SegmentFiles.url(for: bad1.id, in: fixture.segmentDirectory),
            SegmentFiles.url(for: bad2.id, in: fixture.segmentDirectory),
        ])

        // Decision 3's enforcing test: nothing is dropped silently, yet the export succeeds.
        let result = try await fixture.exporter.export(
            entries: entries, deck: deck, sessionDate: Date(),
            unit: .perClip, destination: .files
        )

        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.dropped, [
            DroppedSegment(segmentID: bad1.id, questionID: q1, reason: .unreadable),
            DroppedSegment(segmentID: bad2.id, questionID: q1, reason: .unreadable),
        ])
    }

    func testPhotosPartialFailureReportsSavedCountAndRemovesTempDirectory() async throws {
        let fixture = try await makeFixture()
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let s2 = try seedSegment(questionID: q2, in: fixture.segmentDirectory)
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [s1]),
            ClipManifestEntry(questionID: q2, segments: [s2]),
        ]
        await fixture.photos.setFailure(onSaveIndex: 1, error: PHPhotosError(.accessUserDenied))

        let error = await exportError(fixture, entries: entries, destination: .photos)

        XCTAssertEqual(error, .partiallySavedToPhotos(saved: 1, total: 2, cause: .photosDenied))
        let saved = await fixture.photos.savedURLs
        XCTAssertEqual(saved.count, 1)
        XCTAssertTrue(exportDirectories(fixture).isEmpty)
    }

    func testProgressCalledOncePerOutput() async throws {
        let fixture = try await makeFixture()
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id, q3 = deck.questions[2].id
        let segments = [
            try seedSegment(questionID: q1, in: fixture.segmentDirectory),
            try seedSegment(questionID: q2, in: fixture.segmentDirectory),
            try seedSegment(questionID: q3, in: fixture.segmentDirectory),
        ]
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [segments[0]]),
            ClipManifestEntry(questionID: q2, segments: [segments[1]]),
            ClipManifestEntry(questionID: q3, segments: [segments[2]]),
        ]
        let recorder = ProgressRecorder()

        _ = try await fixture.exporter.export(
            entries: entries, deck: deck, sessionDate: Date(),
            unit: .perClip, destination: .files,
            progress: { done, total in await recorder.record(done, total) }
        )

        let calls = await recorder.calls
        XCTAssertEqual(calls.count, 3)
        XCTAssertEqual(calls[0].done, 1)
        XCTAssertEqual(calls[0].total, 3)
        XCTAssertEqual(calls[1].done, 2)
        XCTAssertEqual(calls[1].total, 3)
        XCTAssertEqual(calls[2].done, 3)
        XCTAssertEqual(calls[2].total, 3)
    }

    func testStitchErrorMapsAndRemovesTempDirectory() async throws {
        let fixture = try await makeFixture()
        let q1 = deck.questions[0].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let entries = [ClipManifestEntry(questionID: q1, segments: [s1])]
        await fixture.stitcher.setThrowing(
            SegmentFiles.url(for: s1.id, in: fixture.segmentDirectory),
            error: CocoaError(.fileWriteOutOfSpace)
        )

        let error = await exportError(fixture, entries: entries)

        XCTAssertEqual(error, .outOfSpace)
        XCTAssertTrue(exportDirectories(fixture).isEmpty)
    }

    func testCancellationMidExportThrowsCancelledAndRemovesTempDirectory() async throws {
        let fixture = try await makeFixture()
        let q1 = deck.questions[0].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let entries = [ClipManifestEntry(questionID: q1, segments: [s1])]
        await fixture.stitcher.setStallNextCall()

        let task = Task {
            try await fixture.exporter.export(
                entries: entries, deck: deck, sessionDate: Date(),
                unit: .perClip, destination: .files
            )
        }
        await fixture.stitcher.waitForCalls(1)
        await fixture.stitcher.waitForStall()
        task.cancel()
        await fixture.stitcher.resolveStall()

        let result = await task.result
        guard case let .failure(error) = result, let failure = error as? ExportFailure else {
            return XCTFail("expected ExportFailure, got \(result)")
        }
        XCTAssertEqual(failure, .cancelled)
        XCTAssertTrue(exportDirectories(fixture).isEmpty)
    }

    func testPhotosExportSavesEachFileThenRemovesTempDirectory() async throws {
        let fixture = try await makeFixture()
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let s2 = try seedSegment(questionID: q2, in: fixture.segmentDirectory)
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [s1]),
            ClipManifestEntry(questionID: q2, segments: [s2]),
        ]

        let result = try await fixture.exporter.export(
            entries: entries, deck: deck, sessionDate: Date(),
            unit: .perClip, destination: .photos
        )

        XCTAssertEqual(result.savedToPhotosCount, 2)
        let saved = await fixture.photos.savedURLs
        XCTAssertEqual(saved, result.files, "saveVideo runs once per file, in plan order")
        XCTAssertTrue(exportDirectories(fixture).isEmpty)
    }

    func testDiscardIsIdempotent() async throws {
        let fixture = try await makeFixture()
        let q1 = deck.questions[0].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let entries = [ClipManifestEntry(questionID: q1, segments: [s1])]

        let result = try await fixture.exporter.export(
            entries: entries, deck: deck, sessionDate: Date(),
            unit: .perClip, destination: .files
        )

        await fixture.exporter.discard(result)
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.directory.path))
        await fixture.exporter.discard(result)   // must not throw
    }

    func testPurgeStaleExportsRemovesOldDirectories() async throws {
        let fixture = try await makeFixture()
        let exports = fixture.temporaryRoot.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        for name in ["stale-1", "stale-2"] {
            try FileManager.default.createDirectory(
                at: exports.appendingPathComponent(name, isDirectory: true)
            )
        }

        fixture.exporter.purgeStaleExports()

        XCTAssertTrue(exportDirectories(fixture).isEmpty)
    }

    func testExportNeverTouchesSegmentDirectory() async throws {
        let fixture = try await makeFixture(photosStatus: .denied)
        let q1 = deck.questions[0].id
        let s1 = try seedSegment(questionID: q1, in: fixture.segmentDirectory)
        let entries = [ClipManifestEntry(questionID: q1, segments: [s1])]
        // A decoy the export has no business touching.
        let decoy = fixture.segmentDirectory.appendingPathComponent("decoy.txt")
        try Data([0x02]).write(to: decoy)

        let before = try FileManager.default.contentsOfDirectory(atPath: fixture.segmentDirectory.path).sorted()

        // Success path (.files).
        let result = try await fixture.exporter.export(
            entries: entries, deck: deck, sessionDate: Date(),
            unit: .perClip, destination: .files
        )
        let afterSuccess = try FileManager.default.contentsOfDirectory(atPath: fixture.segmentDirectory.path).sorted()
        XCTAssertEqual(before, afterSuccess)

        // Failure path (photos denied — throws before step 4).
        _ = await exportError(fixture, entries: entries, destination: .photos)
        // Failure path (stitcher throws — throws inside step 4).
        await fixture.stitcher.setThrowing(
            SegmentFiles.url(for: s1.id, in: fixture.segmentDirectory),
            error: CocoaError(.fileWriteOutOfSpace)
        )
        _ = await exportError(fixture, entries: entries)
        // Cleanup path.
        await fixture.exporter.discard(result)

        let afterFailures = try FileManager.default.contentsOfDirectory(atPath: fixture.segmentDirectory.path).sorted()
        XCTAssertEqual(before, afterFailures, "no export path adds, removes or renames anything in the segment directory")
    }
}
