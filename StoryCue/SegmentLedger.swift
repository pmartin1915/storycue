import Foundation

// Sendable is required because RecoveredSegment (SessionStore) carries an entry across the
// ledger's actor boundary.
enum LedgerStatus: String, Codable, Sendable { case writing, finished, orphaned }

struct SegmentLedgerEntry: Codable, Equatable, Sendable {
    let segmentID: UUID
    let questionID: String
    let fileURL: URL
    let startedAt: Date
    var status: LedgerStatus
}

/// Tracks files-on-disk for crash recovery (not full reducer state — Segment/Clip's own
/// Codable conformance serves snapshotting separately). `init(directory:)` takes an explicit
/// directory always; the production default (Application Support) is the not-yet-built
/// SessionStore's call-site convention, not something this initializer supplies.
///
/// Week 1 never writes `.orphaned` as a status value; that case is reserved for a future
/// explicit cleanup pass. `orphanedEntries()`'s name describes the crash-recovery concept
/// (entries orphaned by a crash), not the `.orphaned` status — it queries entries still
/// `.writing` (never reached `.finished` via `markFinished`).
actor SegmentLedger {
    private let directory: URL
    private let fileURL: URL

    init(directory: URL) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("segment-ledger.json")
    }

    /// Writes are atomic: temp file in the same directory, then a rename/replace — never an
    /// in-place overwrite. A crash mid-write must never leave a corrupt ledger file.
    private func save(_ entries: [SegmentLedgerEntry]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(entries)
        let temporaryURL = directory.appendingPathComponent("segment-ledger.\(UUID().uuidString).tmp")
        try data.write(to: temporaryURL)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }

    private func load() throws -> [SegmentLedgerEntry] {
        guard let data = FileManager.default.contents(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([SegmentLedgerEntry].self, from: data)
    }

    func record(_ entry: SegmentLedgerEntry) async throws {
        var entries = try load()
        entries.append(entry)
        try save(entries)
    }

    func markFinished(_ segmentID: UUID) async throws {
        var entries = try load()
        for index in entries.indices where entries[index].segmentID == segmentID {
            entries[index].status = .finished
        }
        try save(entries)
    }

    /// Entries still `.writing` at load — i.e. orphaned by a crash before `markFinished`.
    func orphanedEntries() async throws -> [SegmentLedgerEntry] {
        try load().filter { $0.status == .writing }
    }
}
