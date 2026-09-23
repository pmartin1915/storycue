import AVFoundation
import Foundation

/// Real capture service. Wires, per Sol's event table:
/// - `AVCaptureMovieFileOutput`'s finish delegate → `.segmentFinished`
/// - `AVAudioSession.interruptionNotification` → `.audioInterruptionBegan`/`.audioInterruptionEnded`
/// - `AVCaptureSession.wasInterruptedNotification` / `.interruptionEndedNotification` →
///   `.captureInterruptionBegan(_)` / `.captureInterruptionEnded`
/// - `AVCaptureSession.runtimeErrorNotification` → `.runtimeError` (with `AVError.mediaServicesWereReset`
///   surfaced as `.mediaServicesReset`)
/// - KVO on `systemPressureState` (critical/shutdown only) → `.thermalPressureCritical`
///
/// Boundaries: no `AVCaptureDeviceDirectionCoordinator` or any hinge-related API here
/// (`#if DUO_SDK`, `StoryCueDuoTests` only). No eager configuration: `configureSession()`
/// is lazy and throws rather than force-unwrapping a nil `AVCaptureDevice.default(...)` on
/// the simulator/CI host.
actor AVCaptureService: CaptureService {
    nonisolated let events: AsyncStream<CaptureServiceEvent>
    private let continuation: AsyncStream<CaptureServiceEvent>.Continuation

    /// Segment files are written here; `SegmentFiles` constructs the URLs. No default
    /// parameter — the call site decides the directory so the ledger agrees with the files.
    private let segmentDirectory: URL

    private var captureSession: AVCaptureSession?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var recordingDelegate: MovieRecordingDelegate?
    private var pressureObservation: NSKeyValueObservation?
    private var videoDevice: AVCaptureDevice?
    private var hasAudio = false
    private var configured = false

    // Notification streams, consumed as AsyncSequences from inside the actor instead of
    // capturing self in an observer closure. Each loop captures self weakly and exits when
    // self is gone. The AVAudioSession interruption stream is app-wide and starts in init;
    // the AVCaptureSession streams are per-session — started in configureSession() with
    // `object:` set to THAT session and cancelled by recreateSession().
    private var audioInterruptionTask: Task<Void, Never>?
    private var captureInterruptionBeganTask: Task<Void, Never>?
    private var captureInterruptionEndedTask: Task<Void, Never>?
    private var runtimeErrorTask: Task<Void, Never>?

    init(segmentDirectory: URL) {
        self.segmentDirectory = segmentDirectory

        var continuation: AsyncStream<CaptureServiceEvent>.Continuation!
        let events = AsyncStream(CaptureServiceEvent.self, bufferingPolicy: .unbounded) { continuation = $0 }
        self.continuation = continuation
        self.events = events

        // `Notification` itself is not Sendable (its `userInfo` is `[AnyHashable: Any]?`),
        // so it cannot cross the `await` into the actor — pull the one Sendable value each
        // handler needs out of `userInfo` here, synchronously, before hopping onto the actor.
        //
        // This closure captures only the Sendable continuation, never self: in a nonisolated
        // actor init, self escaping into a closure would forbid the assignment to
        // audioInterruptionTask below. deinit cancels it, so it doesn't outlive the service.
        let eventContinuation = self.continuation   // a let copy: the local `var` above can't be captured
        audioInterruptionTask = Task {
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification
            ) {
                let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                if let event = AVCaptureService.audioInterruptionEvent(rawType: rawType) {
                    eventContinuation.yield(event)
                }
            }
        }
    }

    deinit {
        audioInterruptionTask?.cancel()
        captureInterruptionBeganTask?.cancel()
        captureInterruptionEndedTask?.cancel()
        runtimeErrorTask?.cancel()
    }

    // MARK: - CaptureService

    func authorization() -> CaptureAuthorization {
        CaptureAuthorization(
            camera: Self.mapAuthStatus(AVCaptureDevice.authorizationStatus(for: .video)),
            microphone: Self.mapAuthStatus(AVCaptureDevice.authorizationStatus(for: .audio))
        )
    }

    func requestAuthorization() async -> CaptureAuthorization {
        // Camera first, then microphone; only .notDetermined is prompted — a determined
        // state is never re-prompted.
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        return authorization()
    }

    var hasAudioInput: Bool { hasAudio }

    func configureSession() async throws {
        if configured { return }

        // Authorization is checked before any device lookup so callers can tell "denied"
        // from "no camera" (on the simulator camera auth is never .authorized).
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CaptureServiceError.notAuthorized
        }

        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .unspecified
        ) else {
            throw CaptureServiceError.deviceUnavailable
        }

        let session = AVCaptureSession()

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            guard session.canAddInput(videoInput) else { throw CaptureServiceError.deviceUnavailable }
            session.addInput(videoInput)
        } catch let error as CaptureServiceError {
            throw error
        } catch {
            throw CaptureServiceError.deviceUnavailable
        }

        // Microphone is best-effort: record video-only rather than fail if it's absent.
        // The fact is exposed via hasAudioInput so the UI can show a "no audio" state.
        hasAudio = false
        if let audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
            hasAudio = true
        }

        let output = AVCaptureMovieFileOutput()
        // Crash-recovery contract: a file cut off mid-write is normally playable up to its
        // last movie fragment, so recovery (SessionStore.recoverOrphans) doesn't rest on a
        // default it never set.
        output.movieFragmentInterval = CMTime(seconds: 10, preferredTimescale: 600)
        guard session.canAddOutput(output) else { throw CaptureServiceError.deviceUnavailable }
        session.addOutput(output)

        // AVCaptureSession.automaticallyConfiguresApplicationAudioSession defaults to true
        // and owns category + activation for capture; leave the automatic default explicit
        // rather than setting AVAudioSession's category by hand beside it (a
        // half-configuration that fights the capture session over activation).
        session.automaticallyConfiguresApplicationAudioSession = true

        let delegate = MovieRecordingDelegate { [weak self] url, error in
            guard let self else { return }
            Task { await self.handleRecordingFinished(url: url, error: error) }
        }

        self.captureSession = session
        self.movieFileOutput = output
        self.recordingDelegate = delegate
        self.videoDevice = videoDevice
        self.configured = true

        observeSystemPressure(on: videoDevice)
        startCaptureNotificationTasks(for: session)

        session.startRunning()
    }

    func startSegment(id: UUID, for questionID: String) async throws {
        if !configured {
            try await configureSession()
        }
        guard let output = movieFileOutput, let delegate = recordingDelegate else {
            throw CaptureServiceError.deviceUnavailable
        }
        // SegmentFiles never creates directories; the injected directory is created here
        // if missing.
        try FileManager.default.createDirectory(at: segmentDirectory, withIntermediateDirectories: true)
        output.startRecording(to: SegmentFiles.url(for: id, in: segmentDirectory), recordingDelegate: delegate)
    }

    func stopSegment(_ segmentID: UUID) async {
        movieFileOutput?.stopRecording()
    }

    func reduceFrameRate() async {
        // Best effort: lock the active video device and pin frame duration to 1/24 s when
        // the active format supports it; every error is swallowed.
        guard let device = videoDevice else { return }
        let duration = CMTime(value: 1, timescale: 24)
        let supported = device.activeFormat.videoSupportedFrameRateRanges.contains { range in
            range.minFrameDuration <= duration && duration <= range.maxFrameDuration
        }
        guard supported else { return }
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {
            // Never throws — thermal throttling is opportunistic.
        }
    }

    func recreateSession() async throws {
        // Tear everything down, then re-run configureSession() from scratch.
        cancelCaptureNotificationTasks()
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }
        pressureObservation?.invalidate()
        pressureObservation = nil
        captureSession = nil
        movieFileOutput = nil
        recordingDelegate = nil
        videoDevice = nil
        hasAudio = false
        configured = false
        try await configureSession()
    }

    // MARK: - Event sources

    /// `AVCaptureMovieFileOutput` finish delegate — arrives on the capture session's private
    /// queue, forwarded here via a Sendable closure hop back onto the actor.
    ///
    /// The segment ID is recovered from `url` (SegmentFiles names the file "<id>.mov"), not
    /// from actor state: a single mutable "active segment" property can't tell two recordings
    /// apart when the reducer's `runtimeError` escape hatch moves on to a new segment before
    /// this delegate has fired for the old one — a stored ID would either mislabel the late
    /// callback as the new segment or, after being cleared by that mislabeled callback,
    /// silently drop the new segment's own.
    private func handleRecordingFinished(url: URL, error: Error?) {
        guard let segmentID = SegmentFiles.segmentID(from: url) else { return }

        guard error != nil else {
            continuation.yield(.segmentFinished(segmentID: segmentID, outcome: .saved(url: url)))
            return
        }

        // The concrete meaning of "the file is kept even when the callback reports an
        // error": kept is decided by whether the partial file actually exists on disk.
        let kept = FileManager.default.fileExists(atPath: url.path)
        continuation.yield(.segmentFinished(segmentID: segmentID, outcome: .failed(kept: kept)))
    }

    private static func audioInterruptionEvent(rawType: UInt?) -> CaptureServiceEvent? {
        // AVAudioSession.interruptionNotification carries no CaptureInterruptionReason —
        // that type models AVCaptureSession's interruption reasons, a different API.
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return nil }
        switch type {
        case .began:
            return .audioInterruptionBegan
        case .ended:
            return .audioInterruptionEnded
        @unknown default:
            return nil
        }
    }

    private func handleCaptureInterruptionBegan(rawReason: Int?) {
        guard let rawReason, let reason = AVCaptureSession.InterruptionReason(rawValue: rawReason) else { return }
        let mapped: CaptureInterruptionReason
        switch reason {
        case .audioDeviceInUseByAnotherClient:
            mapped = .audioDeviceInUseByAnotherClient
        case .videoDeviceInUseByAnotherClient:
            mapped = .videoDeviceInUseByAnotherClient
        case .videoDeviceNotAvailableInBackground:
            mapped = .videoDeviceNotAvailableInBackground
        case .videoDeviceNotAvailableDueToSystemPressure:
            mapped = .videoDeviceNotAvailableDueToSystemPressure
        @unknown default:
            return
        }
        continuation.yield(.captureInterruptionBegan(mapped))
    }

    private func handleCaptureInterruptionEnded() {
        continuation.yield(.captureInterruptionEnded)
    }

    private func handleRuntimeError(error: AVError?) {
        guard let error else { return }
        if error.code == .mediaServicesWereReset {
            continuation.yield(.mediaServicesReset)
        } else {
            continuation.yield(.runtimeError)
        }
    }

    /// KVO on `systemPressureState` fires off the actor; only the critical/shutdown levels
    /// surface an event — nominal/fair/serious are not modeled.
    private func observeSystemPressure(on device: AVCaptureDevice) {
        pressureObservation = device.observe(\.systemPressureState, options: [.new]) { [weak self] device, _ in
            let level = device.systemPressureState.level
            guard level == .critical || level == .shutdown, let self else { return }
            Task { await self.handleCriticalThermalPressure() }
        }
    }

    private func handleCriticalThermalPressure() {
        continuation.yield(.thermalPressureCritical)
    }

    // MARK: - Per-session notification streams

    /// The AVCaptureSession notification streams belong to ONE session: started in
    /// configureSession() with `object:` pinned to that session, cancelled by
    /// recreateSession() so a replaced session never receives (or misses) notifications
    /// meant for its predecessor.
    private func startCaptureNotificationTasks(for session: AVCaptureSession) {
        cancelCaptureNotificationTasks()
        // Match by identity rather than passing `object: session`: AVCaptureSession isn't
        // Sendable, and these [weak self] task closures aren't actor-isolated, so the session
        // itself can't be captured. ObjectIdentifier is Sendable and scopes each stream to
        // this one session just the same.
        let sessionID = ObjectIdentifier(session)
        @Sendable func isFromSession(_ notification: Notification) -> Bool {
            guard let object = notification.object as AnyObject? else { return false }
            return ObjectIdentifier(object) == sessionID
        }
        captureInterruptionBeganTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVCaptureSession.wasInterruptedNotification
            ) where isFromSession(notification) {
                let rawReason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
                await self?.handleCaptureInterruptionBegan(rawReason: rawReason)
            }
        }
        captureInterruptionEndedTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVCaptureSession.interruptionEndedNotification
            ) where isFromSession(notification) {
                await self?.handleCaptureInterruptionEnded()
            }
        }
        runtimeErrorTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVCaptureSession.runtimeErrorNotification
            ) where isFromSession(notification) {
                let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
                await self?.handleRuntimeError(error: error)
            }
        }
    }

    private func cancelCaptureNotificationTasks() {
        captureInterruptionBeganTask?.cancel()
        captureInterruptionEndedTask?.cancel()
        runtimeErrorTask?.cancel()
        captureInterruptionBeganTask = nil
        captureInterruptionEndedTask = nil
        runtimeErrorTask = nil
    }

    // MARK: - Authorization mapping

    private static func mapAuthStatus(_ status: AVAuthorizationStatus) -> AuthState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .denied
        }
    }
}

/// Minimal recording-delegate: bounces the didFinish callback into a Sendable closure so no
/// non-Sendable reference to the actor crosses the capture session's private queue.
private final class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    let onFinish: @Sendable (URL, Error?) -> Void

    init(onFinish: @escaping @Sendable (URL, Error?) -> Void) {
        self.onFinish = onFinish
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        onFinish(outputFileURL, error)
    }
}
