import Foundation

/// Everything the recorder shows, derived from store state in one pure function so the
/// rules are unit-tested without SwiftUI. No SwiftUI/UIKit imports here.
struct RecorderPresentation: Equatable {
    enum Primary: Equatable {
        case record, pause, resume, saving, cancelCountdown, unavailable
    }

    enum Advance: Equatable {
        case skip, next, finish, disabled
    }

    enum Blocking: Equatable {
        case none, preparing, notAuthorized, unavailable
    }

    enum Banner: Equatable {
        case none, readAloud, noAudio, paused(SegmentEndReason)
    }

    var primary: Primary
    var advance: Advance
    var blocking: Blocking
    var banner: Banner
    var showsRecordingDot: Bool
    var timerText: String?          // TimerFormat.string(elapsed) while .recording, else nil
    var countdownText: String?      // "3" / "2" / "1" while counting down, else nil
    var canLeave: Bool

    static func make(
        state: SessionState,
        availability: CaptureAvailability,
        hasAudioInput: Bool,
        elapsed: TimeInterval,
        countdown: Int?
    ) -> RecorderPresentation {
        let blocking: Blocking
        switch availability {
        case .unknown: blocking = .preparing
        case .notAuthorized: blocking = .notAuthorized
        case .unavailable: blocking = .unavailable
        case .ready: blocking = .none
        }

        let primary: Primary
        if blocking != .none {
            primary = .unavailable
        } else if countdown != nil {
            primary = .cancelCountdown
        } else {
            switch state.phase {
            case .idle: primary = .record
            case .recording: primary = .pause
            case .finishing: primary = .saving
            case .paused: primary = .resume
            }
        }

        let isLastQuestion = state.questionIndex == state.deck.questions.count - 1
        let currentQuestionID = state.deck.questions[state.questionIndex].id
        let currentQuestionHasSegments = state.clips
            .first(where: { $0.questionID == currentQuestionID })
            .map { !$0.segments.isEmpty } ?? false

        let advance: Advance
        if blocking != .none || countdown != nil {
            advance = .disabled
        } else if case .finishing = state.phase {
            advance = .disabled
        } else if isLastQuestion, !isRecording(state.phase) {
            advance = .finish
        } else if currentQuestionHasSegments {
            advance = .next
        } else {
            advance = .skip
        }

        let banner: Banner
        if case let .paused(reason) = state.phase, reason != .userPause && reason != .userStop {
            banner = .paused(reason)
        } else if blocking == .none && !hasAudioInput {
            banner = .noAudio
        } else if state.phase == .idle && state.questionIndex == 0 && state.clips.isEmpty {
            banner = .readAloud
        } else {
            banner = .none
        }

        let showsRecordingDot = isRecording(state.phase)
        let timerText = isRecording(state.phase) ? TimerFormat.string(elapsed) : nil

        let canLeave: Bool
        switch blocking {
        case .preparing:
            canLeave = false   // a configure is in flight; endSession refuses too
        case .notAuthorized, .unavailable:
            canLeave = true
        case .none:
            switch state.phase {
            case .idle, .paused:
                canLeave = true
            case .recording, .finishing:
                canLeave = false
            }
        }

        return RecorderPresentation(
            primary: primary,
            advance: advance,
            blocking: blocking,
            banner: banner,
            showsRecordingDot: showsRecordingDot,
            timerText: timerText,
            countdownText: countdown.map(String.init),
            canLeave: canLeave
        )
    }

    private static func isRecording(_ phase: RecordingPhase) -> Bool {
        if case .recording = phase { return true }
        return false
    }
}

enum TimerFormat {
    /// Count-up. "0:00", "0:59", "1:00", "9:59", "10:00", "61:05". Never negative
    /// (clamps at 0), never hours. Floors fractional seconds.
    static func string(_ elapsed: TimeInterval) -> String {
        let totalSeconds = Int(max(0, elapsed).rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
