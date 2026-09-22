# Week 1 coverage-hardening spec — `SessionMachineTests`

_Written 2026-09-22. Scopes the optional, non-blocking coverage pass `ai/STATE.md` and
`ai/IDEAS.md` (2026-09-22 entry, Kimi transition-gap analysis) queued after PR #1 merged.
`SessionMachine.swift`'s reducer already handles every corner below correctly — this is
**test-only**, adding missing test methods, not changing production logic. Named here so
`/orchestrate` doesn't have to re-derive the gaps or invent test names/assertions._

## Scope

**In scope:** new test methods appended to `StoryCueTests/SessionMachineTests.swift` only.

**Out of scope — do not touch:**
- `StoryCue/SessionMachine.swift` or any other production file. If a new test fails, the
  test is wrong, not the reducer — re-derive the expected values from the reducer source
  (quoted inline below for each gap) rather than changing production code to make a test
  pass.
- Any existing test method. Don't rename, reorder, or "clean up" what's already there.
- Any file outside `StoryCueTests/SessionMachineTests.swift`.

**Reuse, don't reinvent** — these existing private helpers in the same file (lines 9–76)
cover everything the new tests need:
- `makeState(questionIndex:phase:clips:backgroundTaskActive:)` — all defaulted; pass only
  what a test needs to override.
- `recordingState(questionIndex:segmentID:)` — a `.recording` state with one open segment
  in the current question's clip; returns `(state, segment)`.
- `finishingState(reason:segment:questionIndex:)` — a `.finishing` state holding the given
  segment; `backgroundTaskActive` is NOT exposed by this helper (always `false`) — for the
  two gaps below that need `backgroundTaskActive: true` on a `.finishing` state, build it
  directly with `makeState(phase:clips:backgroundTaskActive:)` instead, exactly as
  `testFileOutputFinishedEndsBackgroundTaskWhenActive` (line 279) and
  `testBecomeActiveDoesNotEndTaskWhileFinishStillInFlight` (line 311) already do — do not
  add a `backgroundTaskActive` parameter to `finishingState`.
- `expectedPersistedClip(segment:reason:outcome:)` — the `Clip` a `.persistLedger` effect
  should carry.
- `assertFinishing(_:expectedID:expectedReason:expectedEffects:)` — only fits transitions
  *into* `.finishing`; the gaps below mostly assert other phases, so most will use plain
  `XCTAssertEqual` on `(newState, effects)` the way `testMediaServicesResetRecreatesSessionEvenWhenIdle`
  (line 377), `testInformationalEventsAreNoOps` (line 511), and `testTapsIgnoredWhileFinishing`
  (line 500) already do.

## The 10 test methods

Each corresponds to one or more of the 13 (phase × event) gaps `ai/IDEAS.md` logged. Some
are combined into one parameterized/looping test where the existing file already uses that
pattern for the same shape of gap (informational no-ops, phase-list loops) — follow that
precedent rather than writing 13 near-duplicate single-assertion tests.

### 1. `testHingeChangedFromNonRecordingPhasesUpdatesHingeOnly`
Covers: `(idle, hingeChanged)`, `(paused, hingeChanged)`.
Reducer (`hingeChanged` case): the `state.hinge = newValue` assignment is unconditional;
only `.recording` + `.closed` additionally finishes a segment. Loop `phase` over
`[.idle, .paused(reason: .userPause)]` and `newValue` over `[HingeStatus.closed, nil]`.
For each: `makeState(phase: phase)`, reduce `.hingeChanged(newValue)`. Assert
`newState.hinge == newValue`, `newState.phase == phase` (unchanged), `effects == []`.

### 2. `testAccessoryBecomingAvailableWhileRecordingIsNoOp`
Covers: `(recording, accessoryAvailabilityChanged(true))`.
Reducer: `guard !available, case .recording = state.phase else { return (state, []) }` —
`available: true` always fails the guard, regardless of phase. Use `recordingState()`,
reduce `.accessoryAvailabilityChanged(true)`. Assert `newState == state`, `effects == []`.

### 3. `testMediaServicesResetFromFinishingRecreatesSessionButLeavesPhaseUnchanged`
Covers: `(finishing, mediaServicesReset)`.
Reducer: only `.recording` finishes a segment on this event; every other phase (including
`.finishing`) falls through to `return (state, [.recreateCaptureSession])` with the phase
untouched. `testMediaServicesResetRecreatesSessionEvenWhenIdle` (line 377) already proves
this for `.idle`/`.paused` — this test adds the `.finishing` case, which is a genuinely
different branch shape (a segment is already mid-finish). Use `finishingState(reason: .userPause, segment: segment)`
from `recordingState()`, reduce `.mediaServicesReset`. Assert `newState.phase == state.phase`
(still `.finishing`, unchanged), `effects == [.recreateCaptureSession]` (no `.stopSegment`
— that only fires from `.recording`).

### 4. `testRuntimeErrorFromNonRecordingPhasesIsNoOp`
Covers: `(idle, runtimeError)`, `(paused, runtimeError)`.
Reducer: `.runtimeError`'s `switch state.phase` has cases for `.recording` and `.finishing`
only; everything else hits `default: return (state, [])`. Loop `phase` over
`[.idle, .paused(reason: .userPause)]`, reduce `.runtimeError`. Assert `newState == state`,
`effects == []`.

### 5. `testFileOutputFinishedEndsBackgroundTaskOnUserStopExit`
Covers: `(finishing[.userStop], fileOutputFinished, backgroundTaskActive == true)`.
Reducer (`finish()`): background-task-ending is unconditional on `state.backgroundTaskActive`
regardless of `reason` — but the only existing task-active test
(`testFileOutputFinishedEndsBackgroundTaskWhenActive`, line 279) uses reason
`.sceneBackgrounded`. This test is the same shape with reason `.userStop`, which also
takes the `finish()` `reason == .userStop` branch (advance + clamp questionIndex) at the
same time — the one place both branches of `finish()` fire together. Build directly (not
via `finishingState`, which can't set `backgroundTaskActive`):
```swift
let (_, segment) = recordingState()
let state = makeState(
    phase: .finishing(segmentID: segment.id, reason: .userStop),
    clips: [Clip(questionID: segment.questionID, segments: [segment])],
    backgroundTaskActive: true
)
let url = URL(fileURLWithPath: "/tmp/segment.mov")
let (newState, effects) = SessionMachine.reduce(state, .fileOutputFinished(segmentID: segment.id, outcome: .saved(url: url)))
```
Assert `newState.phase == .idle`, `newState.questionIndex == 1`, `newState.backgroundTaskActive == false`,
`effects == [.persistLedger(expectedPersistedClip(segment: segment, reason: .userStop, outcome: .saved(url: url))), .endBackgroundTask]`.

### 6. `testRuntimeErrorEscapeEndsBackgroundTaskWhenActive`
Covers: `(finishing, runtimeError, backgroundTaskActive == true)`.
Reducer: the `.runtimeError` escape hatch from `.finishing` calls the same `finish()` as
`fileOutputFinished` does, so it must also end an active background task — but both
existing escape-hatch tests (`testRuntimeErrorEscapesWedgedFinishing` line 344,
`...DuringAdvance` line 355) use `backgroundTaskActive: false` (via `finishingState`, which
can't override it). Build directly with `backgroundTaskActive: true`, same pattern as test
5, reason `.userPause` (mirrors `testRuntimeErrorEscapesWedgedFinishing`'s reason so the
only variable is `backgroundTaskActive`). Reduce `.runtimeError`. Assert
`newState.phase == .paused(reason: .userPause)`, `newState.backgroundTaskActive == false`,
`newState.clips[0].segments[0].outcome == .failed(kept: true)`, effects contains both
`.persistLedger(...)` and `.endBackgroundTask` (persistLedger first, matching `finish()`'s
effect-append order).

### 7. `testFileOutputFinishedWithSegmentNotInClipsStillTransitionsPhaseButSkipsPersist`
Covers: `(finishing, fileOutputFinished, segment ID not present in clips)`.
Reducer (`finish()`): the `guard case let .finishing(id, reason) = state.phase, id ==
segmentID` only checks the **phase's** ID against the event's ID — it never checks that
`state.clips` actually contains a segment with that ID. `finish()`'s own `for clipIndex in
state.clips.indices { if let segmentIndex = ... }` then silently finds nothing, so the
mutation and the `if let clip = state.clips.first(where:...)` that builds the
`.persistLedger` payload both no-op — but the phase transition and (if applicable)
background-task-ending still happen unconditionally below that. Construct a state whose
phase names a segment ID that `clips` doesn't contain:
```swift
let phantomID = UUID()
let state = makeState(phase: .finishing(segmentID: phantomID, reason: .userPause), clips: [])
let (newState, effects) = SessionMachine.reduce(state, .fileOutputFinished(segmentID: phantomID, outcome: .saved(url: URL(fileURLWithPath: "/tmp/x.mov"))))
```
Assert `newState.phase == .paused(reason: .userPause)` (reason isn't `.userStop`, so this
branch, not the idle/advance one), `newState.clips == []` (nothing to mutate),
`effects == []` (no `.persistLedger` — the clip lookup found nothing — and no
`.endBackgroundTask` since `backgroundTaskActive` defaults to `false`).

### 8. `testBackgroundTaskEventsFromPausedWithTaskActiveAreNoOps`
Covers: `(paused, sceneDidEnterBackground, backgroundTaskActive == true)`,
`(paused, sceneDidBecomeActive, backgroundTaskActive == true)`.
Reducer: both cases guard on `case .recording = state.phase` (or `case let .recording(id)`)
— `backgroundTaskActive` alone is never sufficient; from `.paused` both are no-ops even
with a task active, which is a real (if surprising) coverage hole since it's the same
guard dimension `testBecomeActiveDoesNotEndTaskWhileFinishStillInFlight` already tests for
`.finishing`. Loop `event` over `[.sceneDidEnterBackground, .sceneDidBecomeActive]`, using
`let state = makeState(phase: .paused(reason: .userPause), backgroundTaskActive: true)` for
each. Assert `newState == state`, `effects == []`.

### 9. `testInterruptionBeginEventsFromNonRecordingPhasesAreNoOps`
Covers: `(idle/paused, audioInterruptionBegan | captureInterruptionBegan |
thermalPressureCritical | directionChanged | accessoryAvailabilityChanged(false))`.
Reducer: all five share the `guard case let .recording(id) = state.phase else { return
(state, []) }` shape (or equivalent) — none fire outside `.recording`. Nested loop, same
style as `testInformationalEventsAreNoOps` (line 511): `phase` over
`[.idle, .paused(reason: .userPause)]`, `event` over
`[.audioInterruptionBegan, .captureInterruptionBegan(.audioDeviceInUseByAnotherClient),
.thermalPressureCritical, .directionChanged, .accessoryAvailabilityChanged(false)]`. For
each pair: `makeState(phase: phase)`, reduce, assert `newState == state` and
`effects == []`.

### 10. `testTapGuardRejectionsOutsideFinishing`
Covers: `(paused, tapPause)`, `(recording, tapResume)`, `(recording, tapRecord)`,
`(paused, tapRecord)`. (`testTapsIgnoredWhileFinishing` already covers all five taps from
`.finishing`; this is the same guard-rejection shape from the other two non-matching
phases for `tapPause`/`tapResume`/`tapRecord` specifically — `tapNextQuestion`/`tapSkip`
have no rejecting guard, they always route through `advance()`, so they're not part of
this gap.)
Build four `(state, event)` pairs and assert each is a no-op (`newState == state`,
`effects == []`):
- `makeState(phase: .paused(reason: .userPause))` + `.tapPause`
- `recordingState().state` + `.tapResume`
- `recordingState().state` + `.tapRecord`
- `makeState(phase: .paused(reason: .userPause))` + `.tapRecord`

## Verification

- `xcodebuild test` (or however CI's `Build & test (baseline, flag off)` job runs it) —
  all existing 49 tests plus the ~10 new ones pass, zero regressions.
- `git diff --stat` shows exactly one file changed: `StoryCueTests/SessionMachineTests.swift`.
- No change to `StoryCue/SessionMachine.swift` or any other production file.
