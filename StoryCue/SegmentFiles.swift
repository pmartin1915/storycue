import Foundation

/// The one place segment URLs are made. Pure Foundation, no AVFoundation.
///
/// Segments live in Application Support, not Caches: iOS purges Caches under storage
/// pressure, and a silently-vanished recording is the opposite of this app's promise.
/// Files are left eligible for the user's own device backup (not `isExcludedFromBackup`).
enum SegmentFiles {
    /// Production directory: <Application Support>/Segments. Created if missing.
    static func defaultDirectory() throws -> URL {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Segments", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// "<id.uuidString>.mov" inside `directory`. The ONLY constructor of segment URLs, so
    /// the ledger's `fileURL` and the file actually written can never disagree.
    /// Never creates directories — the caller owns the directory's existence.
    static func url(for id: UUID, in directory: URL) -> URL {
        directory.appendingPathComponent("\(id.uuidString).mov")
    }

    /// Inverse of url(for:in:): nil for any filename that isn't "<UUID>.mov".
    static func segmentID(from url: URL) -> UUID? {
        guard url.pathExtension == "mov" else { return nil }
        return UUID(uuidString: url.deletingPathExtension().lastPathComponent)
    }
}
