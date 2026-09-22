import XCTest
@testable import StoryCue

/// The literal acceptance table from docs/WEEK1-SPEC.md. Baseline target — nothing here
/// is behind DUO_SDK, including `directionChanged`.
final class SessionMachineTests: XCTestCase {
    private let deck = Deck.v1Decks[0]

    // MARK: - Helpers

    private func makeState(
        questionIndex: Int = 0,
        phase: RecordingPhase = .idle,
        clips: [Clip] = [],
        backgroundTaskActive: Bool = false
    ) -> SessionState {
        SessionState(
            deck: deck,
            questionIndex: questionIndex,
            phase: phase,
            clips: clips,
            hinge: nil,
            backgroundTaskActive: backgroundTaskActive
        )
    }

    /// A `.recording` state whose current question's clip already holds one open segment.
    private func recordingState(questionIndex: Int = 0, segmentID: UUID = UUID()) -> (state: SessionState, segment: Segment) {
        let segment = Segment(
            id: segmentID,
            questionID: deck.questions[questionIndex].id,
            startedAt: Date(),
            endReason: nil,
            outcome: nil
        )
        let clip = Clip(questionID: segment.questionID, segments: [segment])
        return (makeState(questionIndex: questionIndex, phase: .recording(segmentID: segmentID), clips: [clip]), segment)
    }

    /// A `.finishing` state holding the given segment in its clip.
    private func finishingState(reason: SegmentEndReason, segment: Segment, questionIndex: Int = 0) -> SessionState {
        let clip = Clip(questionID: segment.questionID, segments: [segment])
        return makeState(questionIndex: questionIndex, phase: .finishing(segmentID: segment.id, reason: reason), clips: [clip])
    }

    /// The clip a `.persistLedger` effect is expected to carry: the open segment with
    /// endReason/outcome recorded.
    private func expectedPersistedClip(segment: Segment, reason: SegmentEndReason, outcome: SegmentOutcome) -> Clip {
        Clip(
            questionID: segment.questionID,
            segments: [Segment(
                id: segment.id,
                questionID: segment.questionID,
                startedAt: segment.startedAt,
                endReason: reason,
                outcome: outcome
            )]
        )
    }

    private func assertFinishing(
        _ result: (SessionState, [SessionEffect]),
        expectedID: UUID,
        expectedReason: SegmentEndReason,
        expectedEffects: [SessionEffect],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .finishing(id, reason) = result.0.phase else {
            XCTFail("expected .finishing, got \(result.0.phase)", file: file, line: line)
            return
        }
        XCTAssertEqual(id, expectedID, file: file, line: line)
        XCTAssertEqual(reason, expectedReason, file: file, line: line)
        XCTAssertEqual(result.1, expectedEffects, "effects mismatch", file: file, line: line)
    }

    // MARK: - Acceptance table

    func testTapRecordFromIdleStartsSegment() {
        let state = makeState()
        let (newState, effects) = SessionMachine.reduce(state, .tapRecord)

        guard case let .recording(segmentID) = newState.phase else {
            return XCTFail("expected .recording, got \(newState.phase)")
        }
        XCTAssertEqual(effects.count, 1)
        guard case let .startSegment(effectID, questionID) = effects[0] else {
            return XCTFail("expected .startSegment, got \(effects)")
        }
        XCTAssertEqual(effectID, segmentID)               // reducer is the sole ID authority
        XCTAssertEqual(questionID, deck.questions[0].id)

        XCTAssertEqual(newState.clips.count, 1)
        let clip = newState.clips[0]
        XCTAssertEqual(clip.questionID, questionID)
        XCTAssertEqual(clip.segments.count, 1)
        XCTAssertEqual(clip.segments[0].id, segmentID)
        XCTAssertEqual(clip.segments[0].endReason, nil)
        XCTAssertEqual(clip.segments[0].outcome, nil)
        XCTAssertLessThanOrEqual(clip.segments[0].startedAt, Date())
    }

    func testTapPauseRequestsFinish() {
        let (state, segment) = recordingState()
        assertFinishing(
            SessionMachine.reduce(state, .tapPause),
            expectedID: segment.id,
            expectedReason: .userPause,
            expectedEffects: [.stopSegment(segmentID: segment.id)]
        )
    }

    func testUserPauseFinishSavesAndPauses() {
        let (_, segment) = recordingState()
        let state = finishingState(reason: .userPause, segment: segment)
        let url = URL(fileURLWithPath: "/tmp/segment.mov")

        let (newState, effects) = SessionMachine.reduce(
            state, .fileOutputFinished(segmentID: segment.id, outcome: .saved(url: url))
        )

        XCTAssertEqual(newState.phase, .paused(reason: .userPause))
        XCTAssertEqual(effects, [.persistLedger(expectedPersistedClip(segment: segment, reason: .userPause, outcome: .saved(url: url)))])
        XCTAssertEqual(newState.clips[0].segments[0].outcome, .saved(url: url))
        XCTAssertEqual(newState.clips[0].segments[0].endReason, .userPause)
    }

    func testResumeStartsFreshSegmentOnSameClip() {
        let (recording, firstSegment) = recordingState()
        // Drive to .paused via the normal finish path so the first segment is closed.
        let finishing = SessionMachine.reduce(recording, .tapPause).0
        let paused = SessionMachine.reduce(
            finishing, .fileOutputFinished(segmentID: firstSegment.id, outcome: .saved(url: URL(fileURLWithPath: "/tmp/a.mov")))
        ).0
        guard case .paused = paused.phase else { return XCTFail("setup failed to reach .paused") }

        let (newState, effects) = SessionMachine.reduce(paused, .tapResume)

        guard case let .recording(segmentID) = newState.phase else {
            return XCTFail("expected .recording, got \(newState.phase)")
        }
        XCTAssertNotEqual(segmentID, firstSegment.id)     // fresh UUID, appended to same clip
        XCTAssertEqual(effects, [.startSegment(segmentID: segmentID, questionID: firstSegment.questionID)])
        XCTAssertEqual(newState.clips.count, 1)           // same clip, not a new one
        XCTAssertEqual(newState.clips[0].segments.count, 2)
        XCTAssertEqual(newState.clips[0].segments[0].id, firstSegment.id)
        XCTAssertEqual(newState.clips[0].segments[1].id, segmentID)
    }

    func testHingeCloseFinishesSegment() {
        let (state, segment) = recordingState()
        let result = SessionMachine.reduce(state, .hingeChanged(.closed))
        assertFinishing(
            result,
            expectedID: segment.id,
            expectedReason: .hingeClosed,
            expectedEffects: [.stopSegment(segmentID: segment.id)]
        )
        XCTAssertEqual(result.0.hinge, .closed)
    }

    func testHingeChangeOtherThanClosedDoesNotFinishSegment() {
        for newValue: HingeStatus? in [.partiallyOpen, .fullyOpen, nil] {
            let (state, segment) = recordingState()
            let (newState, effects) = SessionMachine.reduce(state, .hingeChanged(newValue))
            XCTAssertEqual(newState.phase, .recording(segmentID: segment.id))
            XCTAssertEqual(effects, [])
            XCTAssertEqual(newState.hinge, newValue)
        }
    }

    func testHingeChangeDuringFinishingUpdatesStateWithoutAffectingPhase() {
        let (_, segment) = recordingState()
        let state = finishingState(reason: .userPause, segment: segment)
        for newValue: HingeStatus? in [.closed, .partiallyOpen, .fullyOpen, nil] {
            let (newState, effects) = SessionMachine.reduce(state, .hingeChanged(newValue))
            XCTAssertEqual(newState.phase, state.phase)   // still .finishing, unchanged
            XCTAssertEqual(effects, [])
            XCTAssertEqual(newState.hinge, newValue)      // but the hinge field always updates
        }
    }

    func testAccessoryWithdrawnFinishesSegment() {
        let (state, segment) = recordingState()
        assertFinishing(
            SessionMachine.reduce(state, .accessoryAvailabilityChanged(false)),
            expectedID: segment.id,
            expectedReason: .accessoryWithdrawn,
            expectedEffects: [.stopSegment(segmentID: segment.id)]
        )
    }

    func testAudioInterruptionFinishesSegment() {
        let (state, segment) = recordingState()
        assertFinishing(
            SessionMachine.reduce(state, .audioInterruptionBegan),
            expectedID: segment.id,
            expectedReason: .audioInterruption,
            expectedEffects: [.stopSegment(segmentID: segment.id)]
        )
    }

    func testCaptureInterruptionFinishesSegment() {
        let (state, segment) = recordingState()
        let reason = CaptureInterruptionReason.videoDeviceInUseByAnotherClient
        assertFinishing(
            SessionMachine.reduce(state, .captureInterruptionBegan(reason)),
            expectedID: segment.id,
            expectedReason: .captureInterruption(reason),
            expectedEffects: [.stopSegment(segmentID: segment.id)]
        )
    }

    func testResignActiveBeginsBackgroundTaskWithoutStopping() {
        let (state, segment) = recordingState()
        let (newState, effects) = SessionMachine.reduce(state, .sceneWillResignActive)
        XCTAssertEqual(newState.phase, .recording(segmentID: segment.id))   // recording continues
        XCTAssertTrue(newState.backgroundTaskActive)
        XCTAssertEqual(effects, [.beginBackgroundTask])
    }

    func testResignActiveNoOpWhenNotRecordingOrAlreadyTracked() {
        let (_, idleSegment) = recordingState()
        let nonRecordingPhases: [RecordingPhase] = [
            .idle,
            .paused(reason: .userPause),
            .finishing(segmentID: idleSegment.id, reason: .userPause),
        ]
        for phase in nonRecordingPhases {
            let state = makeState(phase: phase)
            let (newState, effects) = SessionMachine.reduce(state, .sceneWillResignActive)
            XCTAssertEqual(newState, state)
            XCTAssertEqual(effects, [])
        }
        // Already tracked: recording with the task already begun.
        let (_, segment) = recordingState()
        let tracked = makeState(phase: .recording(segmentID: segment.id), backgroundTaskActive: true)
        let (newState, effects) = SessionMachine.reduce(tracked, .sceneWillResignActive)
        XCTAssertEqual(newState, tracked)
        XCTAssertEqual(effects, [])
    }

    func testBackgroundEntryFinishesSegmentWithoutEndingTaskYet() {
        let (state, segment) = recordingState()
        let tracked = makeState(
            phase: .recording(segmentID: segment.id),
            clips: state.clips,
            backgroundTaskActive: true
        )
        let result = SessionMachine.reduce(tracked, .sceneDidEnterBackground)
        assertFinishing(
            result,
            expectedID: segment.id,
            expectedReason: .sceneBackgrounded,
            expectedEffects: [.stopSegment(segmentID: segment.id)]
        )
        XCTAssertTrue(result.0.backgroundTaskActive)      // ended later by the finish exit, not here
    }

    func testBackgroundEntryNoOpWhenNoActiveTaskOrAlreadyFinishing() {
        // No active task: nothing protects an in-flight write, nothing to finish for.
        let (recording, segment) = recordingState()
        let (newState, effects) = SessionMachine.reduce(recording, .sceneDidEnterBackground)
        XCTAssertEqual(newState, recording)
        XCTAssertEqual(effects, [])

        // Task active but already finishing (user tapped pause between resign and backgrounding).
        let finishing = makeState(
            phase: .finishing(segmentID: segment.id, reason: .userPause),
            clips: recording.clips,
            backgroundTaskActive: true
        )
        let (newState2, effects2) = SessionMachine.reduce(finishing, .sceneDidEnterBackground)
        XCTAssertEqual(newState2, finishing)
        XCTAssertEqual(effects2, [])
    }

    func testFileOutputFinishedEndsBackgroundTaskWhenActive() {
        let (_, segment) = recordingState()
        let state = makeState(
            phase: .finishing(segmentID: segment.id, reason: .sceneBackgrounded),
            clips: [Clip(questionID: segment.questionID, segments: [segment])],
            backgroundTaskActive: true
        )
        let url = URL(fileURLWithPath: "/tmp/segment.mov")
        let (newState, effects) = SessionMachine.reduce(
            state, .fileOutputFinished(segmentID: segment.id, outcome: .saved(url: url))
        )
        XCTAssertEqual(newState.phase, .paused(reason: .sceneBackgrounded))
        XCTAssertFalse(newState.backgroundTaskActive)
        XCTAssertEqual(effects, [
            .persistLedger(expectedPersistedClip(segment: segment, reason: .sceneBackgrounded, outcome: .saved(url: url))),
            .endBackgroundTask,
        ])
    }

    func testBecomeActiveEndsUnclosedBackgroundTaskWhenStillRecording() {
        let (recording, segment) = recordingState()
        let tracked = makeState(
            phase: .recording(segmentID: segment.id),
            clips: recording.clips,
            backgroundTaskActive: true
        )
        let (newState, effects) = SessionMachine.reduce(tracked, .sceneDidBecomeActive)
        XCTAssertEqual(newState.phase, .recording(segmentID: segment.id))
        XCTAssertFalse(newState.backgroundTaskActive)
        XCTAssertEqual(effects, [.endBackgroundTask])
    }

    func testBecomeActiveDoesNotEndTaskWhileFinishStillInFlight() {
        let (_, segment) = recordingState()
        let finishing = makeState(
            phase: .finishing(segmentID: segment.id, reason: .sceneBackgrounded),
            clips: [Clip(questionID: segment.questionID, segments: [segment])],
            backgroundTaskActive: true
        )
        let (newState, effects) = SessionMachine.reduce(finishing, .sceneDidBecomeActive)
        XCTAssertEqual(newState, finishing)
        XCTAssertEqual(effects, [])
        XCTAssertTrue(newState.backgroundTaskActive)
    }

    func testThermalCriticalFinishesSegment() {
        let (state, segment) = recordingState()
        assertFinishing(
            SessionMachine.reduce(state, .thermalPressureCritical),
            expectedID: segment.id,
            expectedReason: .thermalShutdown,
            expectedEffects: [.reduceFrameRate, .stopSegment(segmentID: segment.id)]
        )
    }

    func testRuntimeErrorFinishesSegment() {
        let (state, segment) = recordingState()
        assertFinishing(
            SessionMachine.reduce(state, .runtimeError),
            expectedID: segment.id,
            expectedReason: .runtimeError,
            expectedEffects: [.stopSegment(segmentID: segment.id)]
        )
    }

    func testRuntimeErrorEscapesWedgedFinishing() {
        let (_, segment) = recordingState()
        let state = finishingState(reason: .userPause, segment: segment)
        let (newState, effects) = SessionMachine.reduce(state, .runtimeError)

        XCTAssertEqual(newState.phase, .paused(reason: .userPause))          // original reason kept
        XCTAssertEqual(newState.clips[0].segments[0].endReason, .userPause)
        XCTAssertEqual(newState.clips[0].segments[0].outcome, .failed(kept: true))
        XCTAssertEqual(effects, [.persistLedger(expectedPersistedClip(segment: segment, reason: .userPause, outcome: .failed(kept: true)))])
    }

    func testRuntimeErrorEscapesWedgedFinishingDuringAdvance() {
        let (_, segment) = recordingState()
        let state = finishingState(reason: .userStop, segment: segment)
        let (newState, effects) = SessionMachine.reduce(state, .runtimeError)

        XCTAssertEqual(newState.phase, .idle)                                 // .paused(.userStop) is never reachable
        XCTAssertEqual(newState.questionIndex, 1)
        XCTAssertEqual(newState.clips[0].segments[0].endReason, .userStop)
        XCTAssertEqual(newState.clips[0].segments[0].outcome, .failed(kept: true))
        XCTAssertEqual(effects, [.persistLedger(expectedPersistedClip(segment: segment, reason: .userStop, outcome: .failed(kept: true)))])
    }

    func testMediaServicesResetFinishesAndRecreates() {
        let (state, segment) = recordingState()
        assertFinishing(
            SessionMachine.reduce(state, .mediaServicesReset),
            expectedID: segment.id,
            expectedReason: .mediaServicesReset,
            expectedEffects: [.stopSegment(segmentID: segment.id), .recreateCaptureSession]
        )
    }

    func testMediaServicesResetRecreatesSessionEvenWhenIdle() {
        for phase: RecordingPhase in [.idle, .paused(reason: .userPause)] {
            let state = makeState(phase: phase)
            let (newState, effects) = SessionMachine.reduce(state, .mediaServicesReset)
            XCTAssertEqual(newState.phase, phase)             // phase unchanged
            XCTAssertEqual(effects, [.recreateCaptureSession])
        }
    }

    func testStaleFileOutputFinishedIgnored() {
        let staleID = UUID()
        let staleSegment = Segment(
            id: staleID,
            questionID: deck.questions[0].id,
            startedAt: Date(),
            endReason: .userPause,
            outcome: .saved(url: URL(fileURLWithPath: "/tmp/stale.mov"))
        )
        let (recording, _) = recordingState()
        var state = recording
        state.clips[0].segments.insert(staleSegment, at: 0)   // older, already-superseded segment

        let (newState, effects) = SessionMachine.reduce(
            state, .fileOutputFinished(segmentID: staleID, outcome: .saved(url: URL(fileURLWithPath: "/tmp/other.mov")))
        )
        XCTAssertEqual(newState, state)
        XCTAssertEqual(effects, [])
    }

    func testDirectionChangeFinishesSegment() {
        let (state, segment) = recordingState()
        assertFinishing(
            SessionMachine.reduce(state, .directionChanged),
            expectedID: segment.id,
            expectedReason: .directionChanged,
            expectedEffects: [.stopSegment(segmentID: segment.id)]
        )
    }

    func testFailedButKeptSegmentStillPersisted() {
        let (_, segment) = recordingState()
        let state = finishingState(reason: .audioInterruption, segment: segment)
        let (newState, effects) = SessionMachine.reduce(
            state, .fileOutputFinished(segmentID: segment.id, outcome: .failed(kept: true))
        )
        XCTAssertEqual(newState.phase, .paused(reason: .audioInterruption))
        XCTAssertEqual(newState.clips[0].segments[0].outcome, .failed(kept: true))
        XCTAssertEqual(effects, [.persistLedger(expectedPersistedClip(segment: segment, reason: .audioInterruption, outcome: .failed(kept: true)))])
    }

    func testDroppedSegmentExcludedFromManifest() {
        let (_, segment) = recordingState()
        let state = finishingState(reason: .userPause, segment: segment)
        let (newState, _) = SessionMachine.reduce(
            state, .fileOutputFinished(segmentID: segment.id, outcome: .failed(kept: false))
        )
        XCTAssertEqual(newState.phase, .paused(reason: .userPause))
        XCTAssertEqual(newState.clips[0].segments[0].outcome, .failed(kept: false))

        let manifest = exportManifest(for: newState)
        XCTAssertTrue(manifest.isEmpty)   // the clip's only segment was dropped → no entry at all
    }

    func testNextQuestionWhileRecordingFinishesFirst() {
        let (state, segment) = recordingState()
        let finishing = SessionMachine.reduce(state, .tapNextQuestion)
        assertFinishing(finishing, expectedID: segment.id, expectedReason: .userStop, expectedEffects: [.stopSegment(segmentID: segment.id)])

        let url = URL(fileURLWithPath: "/tmp/segment.mov")
        let (newState, effects) = SessionMachine.reduce(
            finishing.0, .fileOutputFinished(segmentID: segment.id, outcome: .saved(url: url))
        )
        XCTAssertEqual(newState.phase, .idle)                  // not .paused — nothing in progress for the new question
        XCTAssertEqual(newState.questionIndex, 1)
        XCTAssertEqual(effects, [.persistLedger(expectedPersistedClip(segment: segment, reason: .userStop, outcome: .saved(url: url)))])
    }

    func testNextQuestionAtLastQuestionFinishesThenClamps() {
        let lastIndex = deck.questions.count - 1
        let (state, segment) = recordingState(questionIndex: lastIndex)
        let finishing = SessionMachine.reduce(state, .tapNextQuestion)
        assertFinishing(finishing, expectedID: segment.id, expectedReason: .userStop, expectedEffects: [.stopSegment(segmentID: segment.id)])

        let (newState, _) = SessionMachine.reduce(
            finishing.0, .fileOutputFinished(segmentID: segment.id, outcome: .saved(url: URL(fileURLWithPath: "/tmp/segment.mov")))
        )
        XCTAssertEqual(newState.phase, .idle)
        XCTAssertEqual(newState.questionIndex, lastIndex)      // clamped, never advances past the last question
    }

    func testAdvanceFromPausedHasNoFinishStep() {
        let (_, segment) = recordingState()
        let clip = Clip(questionID: segment.questionID, segments: [segment])
        let paused = makeState(phase: .paused(reason: .userPause), clips: [clip])

        for event: SessionEvent in [.tapNextQuestion, .tapSkip] {
            let (newState, effects) = SessionMachine.reduce(paused, event)
            XCTAssertEqual(newState.phase, .idle)
            XCTAssertEqual(newState.questionIndex, 1)
            XCTAssertEqual(effects, [])
        }
    }

    func testSkipFromIdleAdvancesWithNoClip() {
        let state = makeState()
        let (newState, effects) = SessionMachine.reduce(state, .tapSkip)
        XCTAssertEqual(newState.phase, .idle)
        XCTAssertEqual(newState.questionIndex, 1)
        XCTAssertTrue(newState.clips.isEmpty)   // a question merely visited never creates a Clip
        XCTAssertEqual(effects, [])
    }

    func testAdvanceAtLastQuestionClamps() {
        let lastIndex = deck.questions.count - 1
        let state = makeState(questionIndex: lastIndex)
        for event: SessionEvent in [.tapSkip, .tapNextQuestion] {
            let (newState, effects) = SessionMachine.reduce(state, event)
            XCTAssertEqual(newState.phase, .idle)
            XCTAssertEqual(newState.questionIndex, lastIndex)
            XCTAssertEqual(effects, [])
        }
    }

    func testTapsIgnoredWhileFinishing() {
        let (_, segment) = recordingState()
        let state = finishingState(reason: .userPause, segment: segment)
        let taps: [SessionEvent] = [.tapRecord, .tapPause, .tapResume, .tapNextQuestion, .tapSkip]
        for tap in taps {
            let (newState, effects) = SessionMachine.reduce(state, tap)
            XCTAssertEqual(newState, state, "\(tap) must be ignored while .finishing")
            XCTAssertEqual(effects, [])
        }
    }

    func testInformationalEventsAreNoOps() {
        let (_, segment) = recordingState()
        let phases: [RecordingPhase] = [
            .idle,
            .recording(segmentID: segment.id),
            .paused(reason: .userPause),
            .finishing(segmentID: segment.id, reason: .userPause),
        ]
        let informational: [SessionEvent] = [
            .audioInterruptionEnded,
            .captureInterruptionEnded,
            .sceneDidBecomeActive,   // with !backgroundTaskActive there is nothing to end
        ]
        for phase in phases {
            for event in informational {
                let state = makeState(phase: phase)
                let (newState, effects) = SessionMachine.reduce(state, event)
                XCTAssertEqual(newState, state, "\(event) from \(phase) must be a no-op")
                XCTAssertEqual(effects, [])
            }
        }
    }

    func testExportManifestExcludesOnlyDroppedSegments() {
        func segment(_ id: UUID, outcome: SegmentOutcome?) -> Segment {
            Segment(id: id, questionID: "parents.001", startedAt: Date(), endReason: .userPause, outcome: outcome)
        }
        let saved1 = segment(UUID(), outcome: .saved(url: URL(fileURLWithPath: "/tmp/1.mov")))
        let saved2 = segment(UUID(), outcome: .saved(url: URL(fileURLWithPath: "/tmp/2.mov")))
        let dropped = segment(UUID(), outcome: .failed(kept: false))
        let keptFailed = segment(UUID(), outcome: .failed(kept: true))
        let neverFinished = segment(UUID(), outcome: nil)   // nil-outcome: same as dropped

        // Array order deliberately does not match questionID sort order, so a manifest
        // implementation that (incorrectly) sorted by questionID instead of preserving
        // state.clips order would fail this assertion.
        let clips = [
            Clip(questionID: "parents.003", segments: [saved2]),
            Clip(questionID: "parents.001", segments: [saved1, dropped]),
            Clip(questionID: "parents.002", segments: [keptFailed, neverFinished]),
        ]
        let state = makeState(clips: clips)

        let manifest = exportManifest(for: state)
        XCTAssertEqual(manifest, [
            ClipManifestEntry(questionID: "parents.003", segments: [saved2]),
            ClipManifestEntry(questionID: "parents.001", segments: [saved1]),
            ClipManifestEntry(questionID: "parents.002", segments: [keptFailed]),
        ])
    }
}
