import XCTest
@testable import StoryCue

final class SessionIndexTests: XCTestCase {
    private func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionIndexTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func makeRecord() -> SessionRecord {
        let deck = Deck.v1Decks[0]
        let segment = Segment(
            id: UUID(),
            questionID: deck.questions[0].id,
            startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            endReason: .userPause,
            outcome: .failed(kept: true)
        )
        return SessionRecord(
            id: UUID(),
            deckID: deck.id,
            deckTitle: deck.title,
            startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            clips: [Clip(questionID: deck.questions[0].id, segments: [segment])],
            isFinished: true
        )
    }

    func testLoadMissingFileIsEmpty() async throws {
        let directory = try makeTempDirectory()
        let index = SessionIndex(directory: directory)
        let records = try await index.load()
        XCTAssertEqual(records, [])
    }

    func testSaveLoadRoundTrip() async throws {
        let directory = try makeTempDirectory()
        let index = SessionIndex(directory: directory)
        let records = [makeRecord(), makeRecord()]
        try await index.save(records)

        let fresh = SessionIndex(directory: directory)
        let loaded = try await fresh.load()
        XCTAssertEqual(loaded, records)
    }

    func testSaveLeavesNoTempFile() async throws {
        let directory = try makeTempDirectory()
        let index = SessionIndex(directory: directory)
        try await index.save([makeRecord()])
        try await index.save([makeRecord()])   // second save takes the replace path

        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(names, ["session-index.json"])
    }

    func testUndecodableFileThrows() async throws {
        let directory = try makeTempDirectory()
        try Data("not json".utf8).write(to: directory.appendingPathComponent("session-index.json"))
        let index = SessionIndex(directory: directory)
        do {
            _ = try await index.load()
            XCTFail("expected a DecodingError")
        } catch {
            XCTAssertTrue(error is DecodingError, "got \(error)")
        }
    }

    func testQuarantineMovesFileAside() async throws {
        let directory = try makeTempDirectory()
        let original = directory.appendingPathComponent("session-index.json")
        let garbage = Data("not json".utf8)
        try garbage.write(to: original)
        let index = SessionIndex(directory: directory)

        let moved = try await index.quarantineUnreadable(now: Date())

        guard let moved else { return XCTFail("expected a new URL") }
        XCTAssertTrue(moved.lastPathComponent.hasPrefix("session-index.unreadable-"))
        XCTAssertTrue(moved.lastPathComponent.hasSuffix(".json"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
        let movedData = try Data(contentsOf: moved)
        XCTAssertEqual(movedData, garbage)

        let again = try await index.quarantineUnreadable(now: Date())
        XCTAssertNil(again)
    }
}
