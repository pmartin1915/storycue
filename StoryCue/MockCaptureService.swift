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
    /// Starts and stops in the order they happened ("start:<uuid>" / "stop:<uuid>"): the two
    /// arrays above can't show whether a stop ran before its start.
    private(set) var callLog: [String] = []
    private(set) var configured = false

    // Test-controlled stubs. Set through the setters below: actor state can't be assigned
    // from outside the actor, even with `await`.
    private(set) var stubAuthorization = CaptureAuthorization(camera: .authorized, microphone: .authorized)
    private(set) var stubHasAudioInput = true
    private(set) var stubStartError: CaptureServiceError?
    private(set) var stubRecreateError: CaptureServiceError?

    func setStubAuthorization(_ value: CaptureAuthorization) { stubAuthorization = value }
    func setStubHasAudioInput(_ value: Bool) { stubHasAudioInput = value }
    func setStubStartError(_ value: CaptureServiceError?) { stubStartError = value }
    func setStubRecreateError(_ value: CaptureServiceError?) { stubRecreateError = value }

    // Recorded calls.
    private(set) var requestAuthorizationCount = 0
    private(set) var reduceFrameRateCount = 0
    private(set) var recreateCount = 0

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
        if let stubStartError {
            throw stubStartError
        }
        startedSegments.append(RecordedStart(id: id, questionID: questionID))
        callLog.append("start:\(id)")
    }

    func stopSegment(_ segmentID: UUID) async {
        stoppedSegmentIDs.append(segmentID)
        callLog.append("stop:\(segmentID)")
    }

    func authorization() -> CaptureAuthorization {
        stubAuthorization
    }

    func requestAuthorization() -> CaptureAuthorization {
        requestAuthorizationCount += 1
        // Mimic a user granting access: each .notDetermined becomes .authorized. A
        // determined state is never re-prompted (mirrors AVCaptureService).
        if stubAuthorization.camera == .notDetermined {
            stubAuthorization.camera = .authorized
        }
        if stubAuthorization.microphone == .notDetermined {
            stubAuthorization.microphone = .authorized
        }
        return stubAuthorization
    }

    var hasAudioInput: Bool { stubHasAudioInput }

    func reduceFrameRate() {
        reduceFrameRateCount += 1
    }

    func recreateSession() async throws {
        recreateCount += 1
        if let stubRecreateError {
            throw stubRecreateError
        }
        configured = true
    }

    /// Test-only: pushes an event into this service's own events stream.
    func simulate(_ event: CaptureServiceEvent) {
        continuation.yield(event)
    }
}
#endif
