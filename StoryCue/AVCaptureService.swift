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
/// Week-1 boundaries: no `AVCaptureDeviceDirectionCoordinator` or any hinge-related API here
/// (week 2, `#if DUO_SDK`, `StoryCueDuoTests` only). No eager configuration: `configureSession()`
/// is lazy and throws `CaptureServiceError.deviceUnavailable` rather than force-unwrapping a
/// nil `AVCaptureDevice.default(...)` on the simulator/CI host.
actor AVCaptureService: CaptureService {
    nonisolated let events: AsyncStream<CaptureServiceEvent>
    private let continuation: AsyncStream<CaptureServiceEvent>.Continuation

    private var captureSession: AVCaptureSession?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var recordingDelegate: MovieRecordingDelegate?
    private var pressureObservation: NSKeyValueObservation?
    private var configured = false

    init() {
        var continuation: AsyncStream<CaptureServiceEvent>.Continuation!
        let events = AsyncStream(CaptureServiceEvent.self, bufferingPolicy: .unbounded) { continuation = $0 }
        self.continuation = continuation
        self.events = events

        // NotificationCenter notifications arrive off the actor; consume each as an
        // AsyncSequence from inside the actor instead of capturing self in an observer
        // closure. These tasks live as long as the service (app lifetime).
        //
        // `Notification` itself is not Sendable (its `userInfo` is `[AnyHashable: Any]?`),
        // so it cannot cross the `await` into the actor — pull the one Sendable value each
        // handler needs out of `userInfo` here, synchronously, before hopping onto the actor.
        Task {
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification
            ) {
                let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                await self.handleAudioSessionInterruption(rawType: rawType)
            }
        }
        Task {
            for await notification in NotificationCenter.default.notifications(
                named: AVCaptureSession.wasInterruptedNotification
            ) {
                let rawReason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
                await self.handleCaptureInterruptionBegan(rawReason: rawReason)
            }
        }
        Task {
            for await _ in NotificationCenter.default.notifications(
                named: AVCaptureSession.interruptionEndedNotification
            ) {
                await self.handleCaptureInterruptionEnded()
            }
        }
        Task {
            for await notification in NotificationCenter.default.notifications(
                named: AVCaptureSession.runtimeErrorNotification
            ) {
                let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
                await self.handleRuntimeError(error: error)
            }
        }
    }

    // MARK: - CaptureService

    func configureSession() async throws {
        if configured { return }

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
        if let audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        let output = AVCaptureMovieFileOutput()
        guard session.canAddOutput(output) else { throw CaptureServiceError.deviceUnavailable }
        session.addOutput(output)

        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoRecording)

        let delegate = MovieRecordingDelegate { [weak self] url, error in
            guard let self else { return }
            Task { await self.handleRecordingFinished(url: url, error: error) }
        }

        self.captureSession = session
        self.movieFileOutput = output
        self.recordingDelegate = delegate
        self.configured = true

        observeSystemPressure(on: videoDevice)

        session.startRunning()
    }

    func startSegment(id: UUID, for questionID: String) async throws {
        if !configured {
            try await configureSession()
        }
        guard let output = movieFileOutput, let delegate = recordingDelegate else {
            throw CaptureServiceError.deviceUnavailable
        }
        let url = try makeSegmentFileURL(id: id)
        output.startRecording(to: url, recordingDelegate: delegate)
    }

    func stopSegment(_ segmentID: UUID) async {
        movieFileOutput?.stopRecording()
    }

    // MARK: - Event sources

    /// `AVCaptureMovieFileOutput` finish delegate — arrives on the capture session's private
    /// queue, forwarded here via a Sendable closure hop back onto the actor.
    ///
    /// The segment ID is recovered from `url` (`makeSegmentFileURL` names the file
    /// `<id>.mov`), not from actor state: a single mutable "active segment" property can't
    /// tell two recordings apart when the reducer's `runtimeError` escape hatch (acceptance
    /// rows 20/21) moves on to a new segment before this delegate has fired for the old
    /// one — a stored ID would either mislabel the late callback as the new segment or, after
    /// being cleared by that mislabeled callback, silently drop the new segment's own.
    /// `mediaServicesReset` is reported only via `handleRuntimeError` (the notification is the
    /// documented source, per the header above) — this path always reports a segment outcome.
    private func handleRecordingFinished(url: URL, error: Error?) {
        guard let segmentID = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { return }

        guard error != nil else {
            continuation.yield(.segmentFinished(segmentID: segmentID, outcome: .saved(url: url)))
            return
        }

        // The concrete meaning of "the file is kept even when the callback reports an
        // error": kept is decided by whether the partial file actually exists on disk.
        let kept = FileManager.default.fileExists(atPath: url.path)
        continuation.yield(.segmentFinished(segmentID: segmentID, outcome: .failed(kept: kept)))
    }

    private func handleAudioSessionInterruption(rawType: UInt?) {
        // AVAudioSession.interruptionNotification carries no CaptureInterruptionReason —
        // that type models AVCaptureSession's interruption reasons, a different API.
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            continuation.yield(.audioInterruptionBegan)
        case .ended:
            continuation.yield(.audioInterruptionEnded)
        @unknown default:
            break
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
    /// surface an event — nominal/fair/serious are not modeled in week 1.
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

    // MARK: - Files

    private func makeSegmentFileURL(id: UUID) throws -> URL {
        let directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("segments", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(id.uuidString).mov")
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
