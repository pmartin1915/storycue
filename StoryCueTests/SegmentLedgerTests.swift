import XCTest
@testable import StoryCue

final class SegmentLedgerTests: XCTestCase {
    private func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SegmentLedgerTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeEntry(directory: URL, status: LedgerStatus = .writing) -> SegmentLedgerEntry {
        SegmentLedgerEntry(
            segmentID: UUID(),
            questionID: "grandparents.001",
            fileURL: directory.appendingPathComponent("\(UUID().uuidString).mov"),
            startedAt: Date(),
            status: status
        )
    }

    func testOrphanedEntryDetectedAfterSimulatedCrash() async throws {
        let directory = try makeTempDirectory()
        let entry = makeEntry(directory: directory)

        let ledger = SegmentLedger(directory: directory)
        try await ledger.record(entry)

        // "Simulated crash": a fresh ledger pointed at the same directory, loading from disk.
        let recovered = SegmentLedger(directory: directory)
        let orphans = try await recovered.orphanedEntries()
        XCTAssertEqual(orphans, [entry])
    }

    func testMarkFinishedRemovesFromOrphans() async throws {
        let directory = try makeTempDirectory()
        let entry = makeEntry(directory: directory)
        let other = makeEntry(directory: directory)

        let ledger = SegmentLedger(directory: directory)
        try await ledger.record(entry)
        try await ledger.record(other)
        try await ledger.markFinished(entry.segmentID)

        let orphans = try await ledger.orphanedEntries()
        XCTAssertEqual(orphans, [other])

        let fresh = SegmentLedger(directory: directory)
        let all = try await fresh.orphanedEntries()
        XCTAssertEqual(all, [other])
        XCTAssertTrue(all.allSatisfy { $0.status == .writing })
    }
}
