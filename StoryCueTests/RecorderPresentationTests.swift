import XCTest
@testable import StoryCue

/// Pure presentation-rule tests (spec §4). `SessionState` values are built directly.
final class RecorderPresentationTests: XCTestCase {
    private let deck = Deck.v1Decks[0]

    private func makeState(
        phase: RecordingPhase,
        questionIndex: Int = 0,
        clips: [Clip] = []
    ) -> SessionState {
        SessionState(
            deck: deck,
            questionIndex: questionIndex,
            phase: phase,
            clips: clips,
            hinge: nil,
            backgroundTaskActive: false
        )
    }

    private func make(
        state: SessionState,
        availability: CaptureAvailability = .ready,
        hasAudioInput: Bool = true,
        elapsed: TimeInterval = 0,
        countdown: Int? = nil
    ) -> RecorderPresentation {
        RecorderPresentation.make(
            state: state,
            availability: availability,
            hasAudioInput: hasAudioInput,
            elapsed: elapsed,
            countdown: countdown
        )
    }

    private func clipForCurrentQuestion(_ state: SessionState) -> Clip {
        Clip(
            questionID: state.deck.questions[state.questionIndex].id,
            segments: [
                Segment(
                    id: UUID(),
                    questionID: state.deck.questions[state.questionIndex].id,
                    startedAt: Date(),
                    endReason: nil,
                    outcome: nil
                )
            ]
        )
    }

    func testBlockingMapsAvailability() {
        let ready = make(state: makeState(phase: .idle), availability: .ready)
        XCTAssertEqual(ready.blocking, .none)
        XCTAssertNotEqual(ready.primary, .unavailable)

        let unknown = make(state: makeState(phase: .idle), availability: .unknown)
        XCTAssertEqual(unknown.blocking, .preparing)
        XCTAssertEqual(unknown.primary, .unavailable)

        let notAuthorized = make(state: makeState(phase: .idle), availability: .notAuthorized)
        XCTAssertEqual(notAuthorized.blocking, .notAuthorized)
        XCTAssertEqual(notAuthorized.primary, .unavailable)

        let unavailable = make(state: makeState(phase: .idle), availability: .unavailable)
        XCTAssertEqual(unavailable.blocking, .unavailable)
        XCTAssertEqual(unavailable.primary, .unavailable)
    }

    func testPrimaryFollowsPhase() {
        XCTAssertEqual(make(state: makeState(phase: .idle)).primary, .record)
        XCTAssertEqual(make(state: makeState(phase: .recording(segmentID: UUID()))).primary, .pause)
        XCTAssertEqual(
            make(state: makeState(phase: .finishing(segmentID: UUID(), reason: .userPause))).primary,
            .saving
        )
        XCTAssertEqual(make(state: makeState(phase: .paused(reason: .userPause))).primary, .resume)
    }

    func testCountdownOverridesPrimaryAndDisablesAdvance() {
        let presentation = make(state: makeState(phase: .idle), countdown: 2)
        XCTAssertEqual(presentation.primary, .cancelCountdown)
        XCTAssertEqual(presentation.advance, .disabled)
        XCTAssertEqual(presentation.countdownText, "2")
    }

    func testAdvanceSkipWithoutSegmentsNextWithSegments() {
        let idleNoClip = make(state: makeState(phase: .idle))
        XCTAssertEqual(idleNoClip.advance, .skip)

        var state = makeState(phase: .idle)
        state.clips = [clipForCurrentQuestion(state)]
        XCTAssertEqual(make(state: state).advance, .next)
    }

    func testAdvanceFinishOnLastQuestion() {
        let lastIndex = deck.questions.count - 1

        let idleLast = make(state: makeState(phase: .idle, questionIndex: lastIndex))
        XCTAssertEqual(idleLast.advance, .finish)

        // Recording on the last question never shows .finish (the reducer clamps, so the
        // presentation offers next/skip per segments instead).
        var recordingWithClip = makeState(phase: .recording(segmentID: UUID()), questionIndex: lastIndex)
        recordingWithClip.clips = [clipForCurrentQuestion(recordingWithClip)]
        let presentationWithClip = make(state: recordingWithClip)
        XCTAssertNotEqual(presentationWithClip.advance, .finish)
        XCTAssertEqual(presentationWithClip.advance, .next)

        let recordingWithoutClip = make(state: makeState(phase: .recording(segmentID: UUID()), questionIndex: lastIndex))
        XCTAssertNotEqual(recordingWithoutClip.advance, .finish)
        XCTAssertEqual(recordingWithoutClip.advance, .skip)
    }

    func testAdvanceDisabledWhileFinishing() {
        let presentation = make(state: makeState(phase: .finishing(segmentID: UUID(), reason: .userPause)))
        XCTAssertEqual(presentation.advance, .disabled)
        XCTAssertEqual(presentation.canLeave, false)
    }

    func testBannerPausedReasonExceptUserPause() {
        let thermal = make(state: makeState(phase: .paused(reason: .thermalShutdown)))
        XCTAssertEqual(thermal.banner, .paused(.thermalShutdown))

        let userPause = make(state: makeState(phase: .paused(reason: .userPause)))
        if case .paused = userPause.banner {
            XCTFail("userPause must not produce a paused banner, got \(userPause.banner)")
        }
    }

    func testBannerNoAudioBeatsReadAloud() {
        let presentation = make(
            state: makeState(phase: .idle),
            hasAudioInput: false
        )
        XCTAssertEqual(presentation.banner, .noAudio)
    }

    func testBannerReadAloudOnlyBeforeFirstClip() {
        let before = make(state: makeState(phase: .idle))
        XCTAssertEqual(before.banner, .readAloud)

        var state = makeState(phase: .idle)
        state.clips = [clipForCurrentQuestion(state)]
        let after = make(state: state)
        XCTAssertEqual(after.banner, .none)
    }

    func testTimerOnlyWhileRecording() {
        let recording = make(
            state: makeState(phase: .recording(segmentID: UUID())),
            elapsed: 65
        )
        XCTAssertEqual(recording.timerText, "1:05")
        XCTAssertEqual(recording.showsRecordingDot, true)

        let paused = make(state: makeState(phase: .paused(reason: .userPause)), elapsed: 65)
        XCTAssertNil(paused.timerText)
        XCTAssertEqual(paused.showsRecordingDot, false)
    }

    func testCanLeaveRules() {
        XCTAssertEqual(make(state: makeState(phase: .idle)).canLeave, true)
        XCTAssertEqual(make(state: makeState(phase: .paused(reason: .userPause))).canLeave, true)
        XCTAssertEqual(make(state: makeState(phase: .recording(segmentID: UUID()))).canLeave, false)
        XCTAssertEqual(make(state: makeState(phase: .finishing(segmentID: UUID(), reason: .userPause))).canLeave, false)

        // A blocking state overrides the phase rule: .unavailable (or .notAuthorized) lets
        // the user leave with "Done" even mid-recording; .preparing refuses.
        let unavailableWhileRecording = make(
            state: makeState(phase: .recording(segmentID: UUID())),
            availability: .unavailable
        )
        XCTAssertEqual(unavailableWhileRecording.canLeave, true)

        let preparing = make(state: makeState(phase: .idle), availability: .unknown)
        XCTAssertEqual(preparing.canLeave, false)
    }
}
