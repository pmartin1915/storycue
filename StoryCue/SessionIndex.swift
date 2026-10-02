import Foundation

struct SessionRecord: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let deckID: String
    let deckTitle: String           // snapshot, so a renamed/removed deck still lists
    let startedAt: Date
    var clips: [Clip]
    var isFinished: Bool

    var deck: Deck? { Deck.v1Decks.first { $0.id == deckID } }
    /// What an export would contain (exportManifest(for: clips)).
    var manifest: [ClipManifestEntry] { exportManifest(for: clips) }

    /// Position of a question in this record's deck: its zero-based index, the deck's
    /// question count and the question text. nil when the deck or the question is unknown.
    func questionPosition(for questionID: String) -> (index: Int, count: Int, text: String)? {
        guard let deck, let index = deck.questions.firstIndex(where: { $0.id == questionID }) else {
            return nil
        }
        return (index, deck.questions.count, deck.questions[index].text)
    }
}

/// The library's source of truth: one JSON file in the segment directory, written atomically.
/// Touches no disk until asked.
actor SessionIndex {
    private let directory: URL
    private let fileURL: URL

    init(directory: URL) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("session-index.json")
    }

    /// Missing file -> []. A file that exists but can't be read throws an I/O error; one that
    /// can't be decoded throws a `DecodingError`.
    func load() throws -> [SessionRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([SessionRecord].self, from: data)
    }

    /// Atomic: temp file in the same directory, then a rename/replace.
    func save(_ records: [SessionRecord]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(records)
        let temporaryURL = directory.appendingPathComponent("session-index.\(UUID().uuidString).tmp")
        try data.write(to: temporaryURL)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }

    /// Moves an undecodable index aside to
    /// `session-index.unreadable-<yyyyMMdd-HHmmss>-<first 8 of a UUID>.json` in the same
    /// directory. Never overwrites or deletes. Returns the new URL, nil if there is no file.
    func quarantineUnreadable(now: Date) throws -> URL? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: now)
        let suffix = String(UUID().uuidString.prefix(8))
        let destination = directory.appendingPathComponent("session-index.unreadable-\(stamp)-\(suffix).json")
        try FileManager.default.moveItem(at: fileURL, to: destination)
        return destination
    }
}
