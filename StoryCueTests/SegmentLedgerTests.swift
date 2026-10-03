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

    func testRemoveDropsOnlyNamedEntries() async throws {
        let directory = try makeTempDirectory()
        let keep = makeEntry(directory: directory)
        let drop = makeEntry(directory: directory)
        let alsoDrop = makeEntry(directory: directory, status: .finished)

        let ledger = SegmentLedger(directory: directory)
        try await ledger.record(keep)
        try await ledger.record(drop)
        try await ledger.record(alsoDrop)
        try await ledger.remove(segmentIDs: [drop.segmentID, alsoDrop.segmentID, UUID()])

        let fresh = SegmentLedger(directory: directory)
        let all = try await fresh.allEntries()
        XCTAssertEqual(all, [keep])
    }

    func testAllEntriesReturnsEveryStatus() async throws {
        let directory = try makeTempDirectory()
        let writing = makeEntry(directory: directory, status: .writing)
        let finished = makeEntry(directory: directory, status: .finished)
        let orphaned = makeEntry(directory: directory, status: .orphaned)

        let ledger = SegmentLedger(directory: directory)
        try await ledger.record(writing)
        try await ledger.record(finished)
        try await ledger.record(orphaned)

        let all = try await ledger.allEntries()
        XCTAssertEqual(all, [writing, finished, orphaned])
    }
}
