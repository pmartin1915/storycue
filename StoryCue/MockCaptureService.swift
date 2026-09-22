#if DEBUG
import Foundation

/// Test/outer-preview stand-in for `AVCaptureService` (the simulator has no camera).
/// The whole file is gated `#if DEBUG` so it never ships in the Release/App Store build.
actor MockCaptureService: CaptureService {
    struct RecordedStart: Equatable, Sendable {
        let id: UUID
        let questionID: String
    }

    private(set) var startedSegments: [RecordedStart] = []
    private(set) var stoppedSegmentIDs: [UUID] = []
    private var configured = false

    // Unbounded buffering with the continuation created in init (not lazily on first
    // access), so simulate() calls made before a subscriber starts iterating are
    // buffered, never dropped — testSimulatedEventsDeliveredInOrder depends on this.
    nonisolated let events: AsyncStream<CaptureServiceEvent>
    private let continuation: AsyncStream<CaptureServiceEvent>.Continuation

    init() {
        var continuation: AsyncStream<CaptureServiceEvent>.Continuation!
        let events = AsyncStream(CaptureServiceEvent.self, bufferingPolicy: .unbounded) { continuation = $0 }
        self.continuation = continuation
        self.events = events
    }

    func configureSession() async throws {
        configured = true
    }

    func startSegment(id: UUID, for questionID: String) async throws {
        if !configured {
            try await configureSession()
        }
        startedSegments.append(RecordedStart(id: id, questionID: questionID))
    }

    func stopSegment(_ segmentID: UUID) async {
        stoppedSegmentIDs.append(segmentID)
    }

    /// Test-only: pushes an event into this service's own events stream.
    func simulate(_ event: CaptureServiceEvent) {
        continuation.yield(event)
    }
}
#endif
