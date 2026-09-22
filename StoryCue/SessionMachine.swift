import Foundation
// Pure Swift, no AVFoundation — this file must stay platform-agnostic so
// MockCaptureService and AVCaptureService are interchangeable underneath it.

enum HingeStatus: Equatable, Sendable {
    case closed, partiallyOpen, fullyOpen
}
// HingeStatus itself has no "no hinge" case — that's `SessionState.hinge: HingeStatus?`
// being `nil` (non-Duo device, or accessory not attached), not a case of this enum.

enum SegmentEndReason: Equatable, Codable, Sendable {
    case userPause, userStop
    case hingeClosed, accessoryWithdrawn
    case audioInterruption, captureInterruption(CaptureInterruptionReason)
    case sceneResignedActive, sceneBackgrounded
    case thermalShutdown, runtimeError, mediaServicesReset, directionChanged
    // S1: the 10-minute cap and early file-output completion (S1 spec §3 / §3b).
    case segmentCapReached, outputEndedUnexpectedly
}

enum CaptureInterruptionReason: Equatable, Codable, Sendable {
    case audioDeviceInUseByAnotherClient, videoDeviceInUseByAnotherClient
    case videoDeviceNotAvailableInBackground, videoDeviceNotAvailableDueToSystemPressure
}

enum SegmentOutcome: Equatable, Codable, Sendable { case saved(url: URL), failed(kept: Bool) }

struct Segment: Equatable, Codable, Sendable {
    let id: UUID
    let questionID: String
    let startedAt: Date
    var endReason: SegmentEndReason?
    var outcome: SegmentOutcome?
}

struct Clip: Equatable, Codable, Sendable { let questionID: String; var segments: [Segment] }

// .paused covers BOTH a user tap and every involuntary interruption. Sol's rule is "any
// discontinuity finishes the segment; reopening is a new segment after a tap" — voluntary
// and involuntary collapse to the same state. The tap itself is the confirmation, for
// every reason; there is no separate needs-confirmation flag.
enum RecordingPhase: Equatable, Sendable {
    case idle                                              // between questions, no clip started yet
    case recording(segmentID: UUID)
    case finishing(segmentID: UUID, reason: SegmentEndReason)
    case paused(reason: SegmentEndReason)
}

struct SessionState: Equatable, Sendable {
    var deck: Deck
    var questionIndex: Int
    var phase: RecordingPhase
    var clips: [Clip]
    var hinge: HingeStatus?
    var backgroundTaskActive: Bool               // tracks a begun-but-not-yet-ended background task
}

enum SessionEvent: Equatable, Sendable {
    case tapRecord, tapPause, tapResume, tapNextQuestion, tapSkip
    case fileOutputFinished(segmentID: UUID, outcome: SegmentOutcome)
    case hingeChanged(HingeStatus?)
    case accessoryAvailabilityChanged(Bool)
    case audioInterruptionBegan, audioInterruptionEnded
    case captureInterruptionBegan(CaptureInterruptionReason), captureInterruptionEnded
    case sceneWillResignActive, sceneDidEnterBackground, sceneDidBecomeActive
    case thermalPressureCritical
    case runtimeError, mediaServicesReset, directionChanged
    // S1: sent by SessionStore.tick(now:) once per segment past the cap; and when the
    // background task expires (clears backgroundTaskActive so a later resign-active works).
    case segmentCapReached, backgroundTaskExpired
}

enum SessionEffect: Equatable, Sendable {
    case startSegment(segmentID: UUID, questionID: String)  // reducer generates the ID; it is the sole segment-ID authority
    case stopSegment(segmentID: UUID)           // real service: this only REQUESTS a stop; the
                                                // transition to `.paused` waits for fileOutputFinished
    case beginBackgroundTask, endBackgroundTask
    case reduceFrameRate
    case recreateCaptureSession                  // mediaServicesReset only
    case persistLedger(Clip)
}

enum SessionMachine {
    static func reduce(_ state: SessionState, _ event: SessionEvent) -> (SessionState, [SessionEffect]) {
        var state = state
        switch event {
        case .tapRecord:
            // Only from .idle. tapRecord while already .recording (or any other phase) is a no-op.
            guard state.phase == .idle else { return (state, []) }
            return startSegment(&state)

        case .tapResume:
            // Only from .paused. The tap is the confirmation, for every pause reason.
            guard case .paused = state.phase else { return (state, []) }
            return startSegment(&state)

        case .tapPause:
            guard case let .recording(id) = state.phase else { return (state, []) }
            state.phase = .finishing(segmentID: id, reason: .userPause)
            return (state, [.stopSegment(segmentID: id)])

        case .tapNextQuestion, .tapSkip:
            // Reducer-equivalent: identical phase transitions from every starting phase.
            return advance(&state)

        case let .fileOutputFinished(segmentID, outcome):
            // Early completion (S1 spec §3b): AVFoundation does not guarantee the finish
            // delegate arrives AFTER the interruption/runtime-error notification that caused
            // it. While .recording with a matching id, run the finish path now instead of
            // wedging in .finishing waiting for a callback that already came. A different
            // id while .recording is a stale callback and stays ignored (default rule).
            if case let .recording(id) = state.phase, id == segmentID {
                return finish(&state, segmentID: id, reason: .outputEndedUnexpectedly, outcome: outcome)
            }
            // Only meaningful while .finishing with a matching ID; anything else is a
            // stale/duplicate callback and is ignored.
            guard case let .finishing(id, reason) = state.phase, id == segmentID else { return (state, []) }
            return finish(&state, segmentID: id, reason: reason, outcome: outcome)

        case let .hingeChanged(newValue):
            // Unconditional status update in every phase, including .finishing.
            state.hinge = newValue
            // From .recording only, a closed hinge additionally finishes the segment.
            if case let .recording(id) = state.phase, newValue == .closed {
                state.phase = .finishing(segmentID: id, reason: .hingeClosed)
                return (state, [.stopSegment(segmentID: id)])
            }
            return (state, [])

        case let .accessoryAvailabilityChanged(available):
            // Becoming available is not a discontinuity; only withdrawal finishes a segment.
            guard !available, case let .recording(id) = state.phase else { return (state, []) }
            state.phase = .finishing(segmentID: id, reason: .accessoryWithdrawn)
            return (state, [.stopSegment(segmentID: id)])

        case .audioInterruptionBegan:
            guard case let .recording(id) = state.phase else { return (state, []) }
            state.phase = .finishing(segmentID: id, reason: .audioInterruption)
            return (state, [.stopSegment(segmentID: id)])

        case .audioInterruptionEnded:
            // Informational only — never auto-resumes.
            return (state, [])

        case let .captureInterruptionBegan(reason):
            guard case let .recording(id) = state.phase else { return (state, []) }
            state.phase = .finishing(segmentID: id, reason: .captureInterruption(reason))
            return (state, [.stopSegment(segmentID: id)])

        case .captureInterruptionEnded:
            // Informational only — never auto-resumes.
            return (state, [])

        case .sceneWillResignActive:
            // Begin at most one background task, and only to cover an in-flight recording.
            guard case .recording = state.phase, !state.backgroundTaskActive else { return (state, []) }
            state.backgroundTaskActive = true
            return (state, [.beginBackgroundTask])

        case .sceneDidEnterBackground:
            // Finish the in-flight segment, but do NOT end the background task here —
            // that waits for the write to actually complete (the .finishing-exit rule).
            guard state.backgroundTaskActive, case let .recording(id) = state.phase else { return (state, []) }
            state.phase = .finishing(segmentID: id, reason: .sceneBackgrounded)
            return (state, [.stopSegment(segmentID: id)])

        case .sceneDidBecomeActive:
            // Only path that ends a task without a finish: task begun on resign-active,
            // app returned to foreground still recording, nothing else will ever end it.
            guard state.backgroundTaskActive, case .recording = state.phase else { return (state, []) }
            state.backgroundTaskActive = false
            return (state, [.endBackgroundTask])

        case .thermalPressureCritical:
            guard case let .recording(id) = state.phase else { return (state, []) }
            state.phase = .finishing(segmentID: id, reason: .thermalShutdown)
            return (state, [.reduceFrameRate, .stopSegment(segmentID: id)])

        case .runtimeError:
            switch state.phase {
            case let .recording(id):
                state.phase = .finishing(segmentID: id, reason: .runtimeError)
                return (state, [.stopSegment(segmentID: id)])
            case let .finishing(id, reason):
                // Escape hatch for a wedged .finishing: treat exactly like a
                // fileOutputFinished with .failed(kept: true), keeping the ORIGINAL reason.
                return finish(&state, segmentID: id, reason: reason, outcome: .failed(kept: true))
            default:
                return (state, [])
            }

        case .mediaServicesReset:
            // The capture subsystem is torn down regardless of phase, so .recreateCaptureSession
            // fires from every phase. Only .recording additionally loses its in-flight segment;
            // unlike the background-task pairing, .stopSegment + .recreateCaptureSession together
            // here is intentional and does not wait for a callback.
            if case let .recording(id) = state.phase {
                state.phase = .finishing(segmentID: id, reason: .mediaServicesReset)
                return (state, [.stopSegment(segmentID: id), .recreateCaptureSession])
            }
            return (state, [.recreateCaptureSession])

        case .directionChanged:
            guard case let .recording(id) = state.phase else { return (state, []) }
            state.phase = .finishing(segmentID: id, reason: .directionChanged)
            return (state, [.stopSegment(segmentID: id)])

        case .segmentCapReached:
            // PLAN §2's 10-minute segment cap. The finish lands in .paused(.segmentCapReached)
            // via the existing finish path — nothing resumes recording without a tap.
            guard case let .recording(id) = state.phase else { return (state, []) }
            state.phase = .finishing(segmentID: id, reason: .segmentCapReached)
            return (state, [.stopSegment(segmentID: id)])

        case .backgroundTaskExpired:
            // Without this an expired task leaves the flag stuck true, blocking the next
            // sceneWillResignActive and producing a spurious .endBackgroundTask later.
            guard state.backgroundTaskActive else { return (state, []) }
            state.backgroundTaskActive = false
            return (state, [])
        }
    }

    /// tapRecord (from .idle) and tapResume (from .paused) share this path: a fresh segment
    /// (fresh UUID, minted here — the reducer is the sole segment-ID authority) appended to
    /// the current question's Clip, and a .startSegment effect carrying that ID.
    private static func startSegment(_ state: inout SessionState) -> (SessionState, [SessionEffect]) {
        let id = UUID()
        let questionID = state.deck.questions[state.questionIndex].id
        let segment = Segment(id: id, questionID: questionID, startedAt: Date(), endReason: nil, outcome: nil)
        if let index = state.clips.lastIndex(where: { $0.questionID == questionID }) {
            state.clips[index].segments.append(segment)
        } else {
            state.clips.append(Clip(questionID: questionID, segments: [segment]))
        }
        state.phase = .recording(segmentID: id)
        return (state, [.startSegment(segmentID: id, questionID: questionID)])
    }

    /// tapNextQuestion / tapSkip. While .recording this only synthesizes the finish-then-wait
    /// step (reason .userStop); the actual advance happens on the matching fileOutputFinished
    /// (or the runtimeError escape hatch). From .idle/.paused there is no clip in flight, so
    /// the advance is immediate. questionIndex never advances past the deck's last question.
    private static func advance(_ state: inout SessionState) -> (SessionState, [SessionEffect]) {
        switch state.phase {
        case let .recording(id):
            state.phase = .finishing(segmentID: id, reason: .userStop)
            return (state, [.stopSegment(segmentID: id)])
        case .idle, .paused:
            state.questionIndex = min(state.questionIndex + 1, state.deck.questions.count - 1)
            state.phase = .idle
            return (state, [])
        case .finishing:
            // Silently swallowed — there is no deferred-retry queue in week 1.
            return (state, [])
        }
    }

    /// A .finishing exit (via matching fileOutputFinished, or via runtimeError as the escape
    /// hatch). Records outcome/endReason on the segment first, so the .persistLedger effect
    /// carries the Clip built from post-mutation state. Destination depends on the reason:
    /// .userStop → .idle with questionIndex advanced (clamped); every other reason → .paused(reason).
    /// If a background task is active it is ended here — and only here or at the
    /// still-recording sceneDidBecomeActive path — never at .stopSegment-request time.
    private static func finish(
        _ state: inout SessionState,
        segmentID: UUID,
        reason: SegmentEndReason,
        outcome: SegmentOutcome
    ) -> (SessionState, [SessionEffect]) {
        for clipIndex in state.clips.indices {
            if let segmentIndex = state.clips[clipIndex].segments.lastIndex(where: { $0.id == segmentID }) {
                state.clips[clipIndex].segments[segmentIndex].endReason = reason
                state.clips[clipIndex].segments[segmentIndex].outcome = outcome
                break
            }
        }

        if reason == .userStop {
            state.questionIndex = min(state.questionIndex + 1, state.deck.questions.count - 1)
            state.phase = .idle
        } else {
            state.phase = .paused(reason: reason)
        }

        var effects: [SessionEffect] = []
        if let clip = state.clips.first(where: { $0.segments.contains(where: { $0.id == segmentID }) }) {
            effects.append(.persistLedger(clip))
        }
        if state.backgroundTaskActive {
            state.backgroundTaskActive = false
            effects.append(.endBackgroundTask)
        }
        return (state, effects)
    }
}
