import XCTest
@testable import StoryCue

final class SegmentFilesTests: XCTestCase {
    func testURLRoundTripsSegmentID() {
        let id = UUID()
        let directory = URL(fileURLWithPath: "/tmp/segments", isDirectory: true)
        let url = SegmentFiles.url(for: id, in: directory)
        XCTAssertEqual(url.deletingLastPathComponent(), directory)
        XCTAssertEqual(url.lastPathComponent, "\(id.uuidString).mov")
        XCTAssertEqual(SegmentFiles.segmentID(from: url), id)
    }

    func testSegmentIDNilForForeignFilename() {
        let directory = URL(fileURLWithPath: "/tmp/segments", isDirectory: true)
        // Not a UUID.
        XCTAssertNil(SegmentFiles.segmentID(from: directory.appendingPathComponent("not-a-uuid.mov")))
        // A UUID-shaped name, but not a .mov file.
        XCTAssertNil(SegmentFiles.segmentID(from: directory.appendingPathComponent("\(UUID().uuidString).txt")))
        // No extension at all.
        XCTAssertNil(SegmentFiles.segmentID(from: directory.appendingPathComponent("random")))
    }

    /// Segments must live in Application Support, not Caches — iOS purges Caches under
    /// storage pressure, and a silently-vanished recording is the opposite of the promise.
    func testDefaultDirectoryIsApplicationSupportNotCaches() throws {
        let directory = try SegmentFiles.defaultDirectory()
        XCTAssertTrue(directory.path.contains("Application Support"), "got \(directory.path)")
        XCTAssertFalse(directory.path.contains("Caches"), "got \(directory.path)")
        // defaultDirectory() creates the directory if missing.
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }
}
