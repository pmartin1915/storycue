import Foundation

enum ExportUnit: Equatable, Sendable { case perClip, wholeSession }

enum DropReason: Equatable, Sendable { case missingFile, emptyFile, unreadable }

struct DroppedSegment: Equatable, Sendable {
    let segmentID: UUID
    let questionID: String
    let reason: DropReason
}

struct PlannedOutput: Equatable, Sendable {
    let fileName: String            // e.g. "StoryCue - Grandparents - 2026-10-02 - Q03.mov"
    let questionIDs: [String]       // one for .perClip; manifest order for .wholeSession
    let sources: [URL]              // SegmentFiles-derived, in stitch order
    let flaggedSegmentIDs: [UUID]   // .failed(kept: true) segments among `sources`
}

struct ExportPlan: Equatable, Sendable {
    let outputs: [PlannedOutput]
    let dropped: [DroppedSegment]
    let totalSourceBytes: Int64
}

/// Pure planner: entries + deck + sizes in, plan out. No AVFoundation, no disk access of its
/// own (sizes come from the injected `fileSize`). S3 spec §1. Decision 2 is enforced here:
/// every source URL is re-derived from the segment ID via SegmentFiles — the URL stored
/// in the segment outcome is never read (S3 decision 2).
enum ExportPlanner {
    /// `fileSize` returns nil for a missing file. It's injected so tests need no disk.
    static func plan(
        entries: [ClipManifestEntry],
        deck: Deck,
        sessionDate: Date,
        unit: ExportUnit,
        segmentDirectory: URL,
        fileSize: (URL) -> Int64?,
        calendar: Calendar            // tests pass a fixed-timezone Gregorian calendar
    ) -> ExportPlan {
        var dropped: [DroppedSegment] = []
        var totalSourceBytes: Int64 = 0

        // Per entry, the segments that survive the file-size drops, in segment order.
        var surviving: [(questionID: String, sources: [URL], flagged: [UUID])] = []

        for entry in entries {
            var sources: [URL] = []
            var flagged: [UUID] = []
            for segment in entry.segments {
                let url = SegmentFiles.url(for: segment.id, in: segmentDirectory)
                guard let size = fileSize(url) else {
                    dropped.append(DroppedSegment(
                        segmentID: segment.id,
                        questionID: entry.questionID,
                        reason: .missingFile
                    ))
                    continue
                }
                guard size > 0 else {
                    dropped.append(DroppedSegment(
                        segmentID: segment.id,
                        questionID: entry.questionID,
                        reason: .emptyFile
                    ))
                    continue
                }
                sources.append(url)
                totalSourceBytes += size
                if segment.outcome == .failed(kept: true) {
                    flagged.append(segment.id)
                }
            }
            surviving.append((questionID: entry.questionID, sources: sources, flagged: flagged))
        }

        let outputs: [PlannedOutput]
        switch unit {
        case .perClip:
            // Two clips can share a name (e.g. two question IDs not in the deck both give
            // "Q00"); a later stitch would overwrite the earlier file, so suffix " (2)", ...
            var usedNames: Set<String> = []
            outputs = surviving.compactMap { item in
                guard !item.sources.isEmpty else { return nil }
                let base = fileName(
                    deck: deck,
                    questionID: item.questionID,
                    sessionDate: sessionDate,
                    calendar: calendar
                )
                var name = base
                var suffix = 2
                while usedNames.contains(name) {
                    name = String(base.dropLast(4)) + " (\(suffix)).mov"
                    suffix += 1
                }
                usedNames.insert(name)
                return PlannedOutput(
                    fileName: name,
                    questionIDs: [item.questionID],
                    sources: item.sources,
                    flaggedSegmentIDs: item.flagged
                )
            }
        case .wholeSession:
            let allSources = surviving.flatMap(\.sources)
            if allSources.isEmpty {
                outputs = []
            } else {
                outputs = [PlannedOutput(
                    fileName: fileName(
                        deck: deck,
                        questionID: nil,
                        sessionDate: sessionDate,
                        calendar: calendar
                    ),
                    // Questions actually represented in the output, in manifest order.
                    questionIDs: surviving.filter { !$0.sources.isEmpty }.map(\.questionID),
                    sources: allSources,
                    flaggedSegmentIDs: surviving.flatMap(\.flagged)
                )]
            }
        }

        return ExportPlan(outputs: outputs, dropped: dropped, totalSourceBytes: totalSourceBytes)
    }

    /// "StoryCue - <deck title> - <yyyy-MM-dd>" + (" - Q<nn>" for .perClip) + ".mov".
    /// nn = 1-based index of the question in `deck.questions`, zero-padded to 2 digits.
    /// A questionID not found in the deck gets "Q00". Characters in / \ : * ? " < > | and
    /// control characters are replaced with "-". The date is formatted with the injected
    /// calendar's time zone, not TimeZone.current.
    static func fileName(deck: Deck, questionID: String?, sessionDate: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        var name = "StoryCue - \(deck.title) - \(formatter.string(from: sessionDate))"
        if let questionID {
            let number: String
            if let index = deck.questions.firstIndex(where: { $0.id == questionID }) {
                number = String(format: "Q%02d", index + 1)
            } else {
                number = "Q00"
            }
            name += " - \(number)"
        }
        name += ".mov"
        return sanitized(name)
    }

    /// Replaces / \ : * ? " < > | and control characters with "-".
    private static func sanitized(_ name: String) -> String {
        let banned: Set<Character> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
        return String(name.map { character in
            if banned.contains(character)
                || character.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) {
                return "-"
            }
            return character
        })
    }
}
