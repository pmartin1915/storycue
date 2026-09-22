import Foundation

protocol CaptureService: Actor {
    func startSegment(id: UUID, for questionID: String) async throws
    func stopSegment(_ segmentID: UUID) async
    func configureSession() async throws        // device lookup + session setup; lazy, not eager
    var events: AsyncStream<CaptureServiceEvent> { get }
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

enum CaptureServiceError: Error, Sendable { case deviceUnavailable }
