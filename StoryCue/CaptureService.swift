import Foundation

enum AuthState: Equatable, Sendable {
    case notDetermined, authorized, denied, restricted
}

struct CaptureAuthorization: Equatable, Sendable {
    var camera: AuthState
    var microphone: AuthState
}

protocol CaptureService: Actor {
    func startSegment(id: UUID, for questionID: String) async throws
    func stopSegment(_ segmentID: UUID) async
    func configureSession() async throws        // device lookup + session setup; lazy, not eager
    var events: AsyncStream<CaptureServiceEvent> { get }
    /// Current authorization for both media types; never prompts.
    func authorization() async -> CaptureAuthorization
    /// Camera first, then microphone; never re-prompts a determined state.
    func requestAuthorization() async -> CaptureAuthorization
    /// False until configured, or when the mic input couldn't be added — the UI must show
    /// a "no audio" state instead of silently recording video-only.
    var hasAudioInput: Bool { get async }
    /// Best effort; never throws.
    func reduceFrameRate() async
    /// Tear down everything, then configureSession() again (media-services reset).
    func recreateSession() async throws
    /// Sendable source the UI connects a preview view to. The service owns ONE
    /// `AVCaptureSession` object for its whole life, so a connected preview survives
    /// `recreateSession()` — only the session's contents are rebuilt.
    nonisolated var previewSource: any PreviewSource { get }
    /// Stop running, cancel the per-session notification tasks, finish the events stream.
    /// Idempotent: calling twice, or before configureSession(), is a no-op beyond the
    /// first finish.
    func shutdown() async
}

/// Five different real APIs feed this one stream, and each gets its own case — audio-session
/// and capture-session interruptions are deliberately not collapsed into one.
enum CaptureServiceEvent: Sendable, Equatable {
    case segmentFinished(segmentID: UUID, outcome: SegmentOutcome)
    case audioInterruptionBegan, audioInterruptionEnded
    case captureInterruptionBegan(CaptureInterruptionReason), captureInterruptionEnded
    case thermalPressureCritical
    case runtimeError, mediaServicesReset
}

enum CaptureServiceError: Error, Sendable {
    case deviceUnavailable
    /// Camera authorization is not `.authorized` — distinct from deviceUnavailable so the
    /// UI can tell "denied" from "no camera".
    case notAuthorized
}
