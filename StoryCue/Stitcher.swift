@preconcurrency import AVFoundation
import Foundation

struct StitchReport: Equatable, Sendable {
    let unreadable: [URL]           // sources skipped: asset/video track failed to load, or duration <= 0
    let durationSeconds: Double     // sum of the inserted video time ranges; 0 when nothing written
    let outputWritten: Bool         // false iff every source was unreadable (no file at `output`)
}

protocol Stitcher: Sendable {
    /// Writes one .mov at `output` from `sources`, in order. Skips a source whose asset or
    /// video track fails to load, and reports it in `unreadable`. If NO source is readable
    /// it writes nothing and RETURNS a report with `outputWritten == false` (it does not
    /// throw, so the unreadable list is never lost). Throws only for write/export errors
    /// and cancellation. Honors Task cancellation.
    func stitch(_ sources: [URL], to output: URL) async throws -> StitchReport
}

/// AVFoundation stitcher (S3 spec §2): one AVMutableComposition, video + audio tracks,
/// passthrough preset when compatible with the composition, `.mov` out. Decision 4: never
/// re-encodes when passthrough works. No source's audio problems are ever fatal — a source
/// with no audio leaves a silent gap (S2a has a "no audio" state).
struct AVStitcher: Stitcher {
    init() {}

    /// Builds the composition half of `stitch`: one video + one audio track, sources
    /// inserted in order, unreadable ones skipped and reported. Also shared by in-app
    /// playback (S2c), which wraps the returned composition in an `AVPlayerItem` in memory
    /// and never writes a file. `durationSeconds` is the sum of the inserted video time
    /// ranges, 0 when every source was unreadable. Honors Task cancellation.
    static func makeComposition(_ sources: [URL]) async throws -> (
        composition: AVMutableComposition,
        durationSeconds: Double,
        unreadable: [URL]
    ) {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportFailure.failed(domain: "StoryCue.AVStitcher", code: 1)
        }
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportFailure.failed(domain: "StoryCue.AVStitcher", code: 2)
        }

        var unreadable: [URL] = []
        var cursor = CMTime.zero
        var firstReadableTransform: CGAffineTransform?

        for url in sources {
            try Task.checkCancellation()
            let asset = AVURLAsset(url: url)
            let duration: CMTime
            let videoTracks: [AVAssetTrack]
            do {
                duration = try await asset.load(.duration)
                videoTracks = try await asset.loadTracks(withMediaType: .video)
            } catch {
                // A cancelled load is a cancellation, not an unreadable source.
                if Task.isCancelled { throw CancellationError() }
                unreadable.append(url)
                continue
            }
            guard duration > .zero, let sourceVideo = videoTracks.first else {
                unreadable.append(url)
                continue
            }

            let timeRange = CMTimeRange(start: .zero, duration: duration)
            try videoTrack.insertTimeRange(timeRange, of: sourceVideo, at: cursor)

            // Audio is never a reason to drop a source: a throw or empty result means
            // "no audio". A short audio track is clamped so the insert can't fail on it.
            if let sourceAudio = (try? await asset.loadTracks(withMediaType: .audio))?.first,
               let audioRange = try? await sourceAudio.load(.timeRange) {
                let audioDuration = min(audioRange.duration, duration)
                if audioDuration > .zero {
                    try? audioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: audioDuration),
                        of: sourceAudio,
                        at: cursor
                    )
                }
            }

            if firstReadableTransform == nil {
                firstReadableTransform = try? await sourceVideo.load(.preferredTransform)
            }
            cursor = cursor + duration
        }

        if let firstReadableTransform {
            videoTrack.preferredTransform = firstReadableTransform
        }
        // No source had audio: drop the empty track rather than export a zero-length one.
        if audioTrack.segments.isEmpty {
            composition.removeTrack(audioTrack)
        }

        return (composition, cursor.seconds, unreadable)
    }

    func stitch(_ sources: [URL], to output: URL) async throws -> StitchReport {
        // Remove any file already at `output` first, so `outputWritten == false` really
        // means no file is there (never a stale one from an earlier export).
        try? FileManager.default.removeItem(at: output)

        let built = try await Self.makeComposition(sources)

        guard built.durationSeconds > 0 else {
            // Every source was unreadable: no file at `output`, nothing thrown, and the
            // unreadable list still reaches the caller (S3 spec review, point 1).
            return StitchReport(unreadable: built.unreadable, durationSeconds: 0, outputWritten: false)
        }

        // Decision 4: passthrough when compatible with this composition, else re-encode.
        let passthroughCompatible = await AVAssetExportSession.compatibility(
            ofExportPreset: AVAssetExportPresetPassthrough,
            with: built.composition,
            outputFileType: .mov
        )
        let preset = passthroughCompatible
            ? AVAssetExportPresetPassthrough
            : AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: built.composition, presetName: preset) else {
            throw ExportFailure.failed(domain: "StoryCue.AVStitcher", code: 3)
        }
        session.outputFileType = .mov
        // The async export(to:as:) cancels the underlying export when its Task is
        // cancelled — no second cancel path (confirmed on device at S5).
        try await session.export(to: output, as: .mov)

        return StitchReport(
            unreadable: built.unreadable,
            durationSeconds: built.durationSeconds,
            outputWritten: true
        )
    }
}
