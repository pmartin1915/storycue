import Foundation

struct ClipManifestEntry: Equatable, Sendable {
    let questionID: String
    let segments: [Segment]
}

/// Pure function, not a SessionEvent — step 5's Files/Photos export consumes this typed
/// input without the reducer knowing about export destinations.
///
/// Exclusion rules (PLAN §2): `.failed(kept: false)` segments are excluded;
/// `.failed(kept: true)` are included but flagged (kept is on the outcome itself); a segment
/// whose outcome is still `nil` (recording/finishing never completed, e.g. the app was killed
/// mid-question) is treated like `.failed(kept: false)`. A Clip left with zero non-excluded
/// segments produces no entry at all — omitted, not an empty entry. Entries are in
/// `state.clips` array order (order of each question's first segment start).
func exportManifest(for state: SessionState) -> [ClipManifestEntry] {
    exportManifest(for: state.clips)
}

/// The segment files in-app playback of one answer reads: the same keep rules as export
/// (S2c spec §2). Built from `SegmentFiles`, never from `SegmentOutcome.saved(url:)` —
/// the manifest entry's segment IDs are the canonical file identity. `[]` when the
/// question has no manifest entry.
func playbackSources(for record: SessionRecord, questionID: String, in directory: URL) -> [URL] {
    guard let entry = exportManifest(for: record.clips).first(where: { $0.questionID == questionID }) else {
        return []
    }
    return entry.segments.map { SegmentFiles.url(for: $0.id, in: directory) }
}

/// Same rules over a bare clip list (the session library stores clips, not a SessionState).
func exportManifest(for clips: [Clip]) -> [ClipManifestEntry] {
    clips.compactMap { clip in
        let segments = clip.segments.filter { segment in
            switch segment.outcome {
            case .saved:
                return true
            case let .failed(kept):
                return kept
            case nil:
                return false
            }
        }
        guard !segments.isEmpty else { return nil }
        return ClipManifestEntry(questionID: clip.questionID, segments: segments)
    }
}
