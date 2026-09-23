import Foundation
import XCTest
@testable import StoryCue

/// Real-AVFoundation stitcher tests (S3 spec §6). If SyntheticMovie.write itself throws
/// on the runner (no encoder there), the test skips; only the helper's own failure is
/// skippable — a stitch assertion that fails is a real failure.
final class AVStitcherTests: XCTestCase {
    private func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AVStitcherTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Wraps ONLY the synthetic-movie write in the pre-registered skip.
    private func makeSyntheticMovie(_ url: URL, seconds: Double, withAudio: Bool) async throws -> URL {
        do {
            try await SyntheticMovie.write(to: url, seconds: seconds, withAudio: withAudio)
            return url
        } catch {
            throw XCTSkip("synthetic movie unavailable: \(error)")
        }
    }

    private func makeCorruptMovie(_ url: URL) throws -> URL {
        var bytes = [UInt8]()
        bytes.reserveCapacity(2048)
        for index in 0..<2048 {
            bytes.append(UInt8(index % 251))
        }
        try Data(bytes).write(to: url)
        return url
    }

    func testStitchesTwoSegmentsDurationIsSum() async throws {
        let directory = try makeTempDirectory()
        let first = try await makeSyntheticMovie(
            directory.appendingPathComponent("first.mov"), seconds: 1.0, withAudio: true
        )
        let second = try await makeSyntheticMovie(
            directory.appendingPathComponent("second.mov"), seconds: 1.0, withAudio: true
        )
        let output = directory.appendingPathComponent("output.mov")

        let report = try await AVStitcher().stitch([first, second], to: output)

        XCTAssertTrue(report.outputWritten)
        XCTAssertTrue(report.unreadable.isEmpty)
        XCTAssertEqual(report.durationSeconds, 2.0, accuracy: 0.15)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    }

    func testStitchesSegmentWithoutAudio() async throws {
        let directory = try makeTempDirectory()
        let withAudio = try await makeSyntheticMovie(
            directory.appendingPathComponent("with-audio.mov"), seconds: 1.0, withAudio: true
        )
        let silent = try await makeSyntheticMovie(
            directory.appendingPathComponent("silent.mov"), seconds: 1.0, withAudio: false
        )
        let output = directory.appendingPathComponent("output.mov")

        let report = try await AVStitcher().stitch([withAudio, silent], to: output)

        XCTAssertTrue(report.outputWritten)
        XCTAssertEqual(report.unreadable, [])
        XCTAssertEqual(report.durationSeconds, 2.0, accuracy: 0.15)
    }

    func testCorruptSourceReportedUnreadableOthersStitched() async throws {
        let directory = try makeTempDirectory()
        let corrupt = try makeCorruptMovie(directory.appendingPathComponent("corrupt.mov"))
        let good = try await makeSyntheticMovie(
            directory.appendingPathComponent("good.mov"), seconds: 1.0, withAudio: true
        )
        let output = directory.appendingPathComponent("output.mov")

        let report = try await AVStitcher().stitch([corrupt, good], to: output)

        XCTAssertEqual(report.unreadable, [corrupt])
        XCTAssertTrue(report.outputWritten)
        XCTAssertEqual(report.durationSeconds, 1.0, accuracy: 0.15)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    }

    func testAllSourcesUnreadableReturnsOutputNotWritten() async throws {
        let directory = try makeTempDirectory()
        let corrupt1 = try makeCorruptMovie(directory.appendingPathComponent("corrupt-1.mov"))
        let corrupt2 = try makeCorruptMovie(directory.appendingPathComponent("corrupt-2.mov"))
        let output = directory.appendingPathComponent("output.mov")

        // Returns a report rather than throwing, so the unreadable list is never lost.
        let report = try await AVStitcher().stitch([corrupt1, corrupt2], to: output)

        XCTAssertFalse(report.outputWritten)
        XCTAssertEqual(report.durationSeconds, 0)
        XCTAssertEqual(report.unreadable, [corrupt1, corrupt2])
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }
}
