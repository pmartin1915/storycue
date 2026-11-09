# Review: StoryCue / Tellfolk (target) vs BoardBound, burn-wizard, Wilderness Survival (veterans)

## Score table

| # | Dimension | Score (0-4) | One-line basis |
|---|---|---|---|
| 1 | Motion and fluidity | 3 | Tokenized short springs, Reduce Motion honored in code; zero measured validation (probe M7 = 0) and one unanimated state change (F7) |
| 2 | State clarity | 3 | Loading/saving/empty/error all exist with actions, but two button families lack in-flight guards (F4) and export failure has no retry (F5) |
| 3 | Input/recording robustness | 3 | Interruption taxonomy and recovery are excellent; the audio-session hand-back to the camera is self-admitted unverified (F1) |
| 4 | Accessibility | 3 | AX5 harness, labels, identifiers, contrast engineering; but three deliberate type-size caps and no automated VoiceOver audit (F3, F10) |
| 5 | Visual system | 3 | Real token file and one-accent discipline; raw literals outside tokens that the house grep check would flag (F6) |
| 6 | Performance | 2 | No launch/hitch metrics at all; playback wisely builds in memory, but nothing is measured |
| 7 | Copy | 4 | Single UICopy file, plain and specific, every failure says what happened and what to do |
| 8 | Layout resilience | 4 | Portrait-locked (probe M11), ViewThatFits + ScrollView fallback, AX5 screenshot runs |
| 9 | Android parity | N/A | iOS-only per packet |

No blockers found. Findings ordered should -> polish.

## FINDINGS

FINDING 1
- dimension: 3
- severity: should
- target: storycue/StoryCue/Views/AnswerPlayerView.swift:90-93  quote: "Nothing restores it: AVCaptureSession.automaticallyConfiguresApplicationAudioSession reconfigures the app audio session itself when the next recording starts (see the comment near AVCaptureService.swift:160 -- unverified, so it is on the S2c device-check list)."
- veteran counterpart: wilderness/src/components/breathing/BreathingExercise.tsx:88-89  quote: "Cancel any speech when the component unmounts."
- evidence: After playback, `release()` deactivates the audio session (`.setActive(false, options: .notifyOthersOnDeactivation)`) and the comment states the next recording depends on capture-session behavior that is explicitly "unverified". The recorder's core record flow rests on an assumption that is still on a check list, not proven.
- fix: Verify on device that recording after playback has working audio, then replace the comment with the confirmed behavior. Until verified, have `load()` restore the session category to `.playAndRecord` (or let the capture service set it explicitly in `prepareCapture`) instead of assuming the capture stack self-heals.

FINDING 2
- dimension: 6
- severity: should
- target: ScreenshotTests.swift (whole file) / probe M7  quote: "grep XCTApplicationLaunchMetric/XCTHitchMetric/measure( | none; no baseline | 0"
- veteran counterpart: burn-wizard/app/src/styles/design-system.css:20-22  quote: "it failed even the 3.0:1 large-text allowance, so the brand teal was non-compliant at any size (F-01). 27% clears 4.5:1 against all four light surfaces: card 5.265, background 5.070, secondary 4.776"
- evidence: The veteran treats polish as measured numbers with named findings (F-01, F-02); the target has a screenshot harness but never measures launch duration or scroll hitches, so regressions in the two most felt qualities (launch, list scroll over a camera app) are invisible.
- fix: Add one `XCTApplicationLaunchMetric` measure block and one `XCTHitchMetric` scroll measure to ScreenshotTests, store a baseline, and fail CI past a threshold. This is a test-only change.

FINDING 3
- dimension: 4
- severity: should
- target: storycue/StoryCue/Views/RecorderView.swift:248-249  quote: "The nav bar has a fixed height; past AX1 the pill would clip. .dynamicTypeSize(...DynamicTypeSize.accessibility1)"
- veteran counterpart: no veteran excerpt in the packet shows Dynamic Type handling; closest veteran AX behavior is wilderness/src/components/emergency/PanicOverlay.tsx:118-120  quote: "aria-live=\"assertive\" aria-atomic=\"true\""
- evidence: The recording indicator is capped at AX1, the paused/read-aloud banner at AX2 (RecorderView.swift:275-279), and control labels at AX2 (RecorderView.swift:288-298) — three caps where house rule 18's check is "Check at AX5" and the house style says never cap text to protect a layout. The comment concedes the layout loses: "past AX1 the pill would clip."
- fix: Move the recording indicator out of the nav bar into a view-owned overlay so it can scale, and let the banner and control labels wrap or scroll instead of capping. The AX5 screenshot test already exists to verify the result.

FINDING 4
- dimension: 2
- severity: should
- target: storycue/StoryCue/Views/LibraryView.swift:108-113  quote: "Button(UICopy.keep) { Task { await library.keep(clip) } } ... .frame(maxWidth: .infinity, minHeight: 44)"
- veteran counterpart: wilderness/src/components/breathing/BreathingExercise.tsx:79-86  quote: "return () => { if (timeoutRef.current !== null) { window.clearTimeout(timeoutRef.current); timeoutRef.current = null; } }"
- evidence: The veteran guards its async driver so a stale task can never double-fire; the target's Keep/Delete-clip buttons in LibraryView (lines 108-118) and SessionDetailView's undecidedControls (lines 192-201) start `Task { await ... }` with no disabled-while-in-flight state, so rapid taps can fire concurrent keep/discard calls on the same clip. The consent button shows the intended pattern: `.disabled(isBeginning || !model.library.isLoaded)` (ConsentView.swift:58).
- fix: Add a `@State pendingClipID: RecoveredClip?` (or an `isWorking` flag) and `.disabled(whileWorking)` on both button pairs, cleared in the task's defer, mirroring the consent button and ExportModel.start's single-flight guard.

FINDING 5
- dimension: 2
- severity: polish
- target: storycue/StoryCue/Views/ExportView.swift:75-83  quote: "case let .finished(message), let .failed(message): VStack(alignment: .leading, spacing: 20) { Text(message) ... Button(UICopy.done) { dismiss() }"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:180-186  quote: "Pressable accessibilityRole=\"button\" ... onPress={() => router.back()} ... Back to Study"
- evidence: House rule 12 wants each error state to have one action; the failed export's only action is Done (dismiss), so a user whose export failed must re-open the sheet and re-tap through. The veteran's error/empty state pairs the explanation with a real action.
- fix: In the `.failed` branch, add a "Try again" button that calls `model.start(lastDestination)` (store the destination on the model when starting); keep Done secondary.

FINDING 6
- dimension: 5
- severity: polish
- target: storycue/StoryCue/Views/RecordButton.swift:27  quote: ".fill(Color.red)"
- veteran counterpart: burn-wizard/app/src/styles/design-system.css:70  quote: "--radius: 0.75rem; /* Consistent border radius */"
- evidence: House rule 5's check is "Grep for padding and radius literals outside the tokens file," and rule 2 wants everything neutral except the one accent. The record dot uses a raw `Color.red` literal rather than `DesignTokens.recordingFill` (which exists precisely to tune that red), and RecorderView carries spacing/padding literals (`spacing: 16` line 38, `.padding(32)` line 420, the 36x5 handle lines 187-189) outside `DesignTokens.Spacing`.
- fix: Point the dot at `DesignTokens.recordingFill` and promote the repeated literals (16, 32, the handle size) into `DesignTokens.Spacing`/`RecordButton` so the lint grep stays clean.

FINDING 7
- dimension: 1
- severity: polish
- target: storycue/StoryCue/Views/RecorderView.swift:388-391  quote: "while let value = countdown, value > 1 { try await Task.sleep(for: .seconds(1)) countdown = value - 1 }"
- veteran counterpart: wilderness/src/components/breathing/BreathingExercise.tsx:149-151  quote: "transform: `scale(${currentStep.scale})`, transition: `transform ${transitionSeconds}s ease-in-out`"
- evidence: The veteran animates every phase change of its timed driver; the target's countdown digits mutate `countdown` with no `withAnimation`, so 3-2-1 snaps hard while everything else in the recorder morphs with `DesignTokens.Motion.morph`.
- fix: Wrap each countdown decrement in `withAnimation(reduceMotion ? nil : DesignTokens.Motion.fade)`; skip any tick haptic since the camera is active and iOS mutes haptics there anyway.

FINDING 8
- dimension: 4
- severity: polish
- target: probe M6  quote: "contrast test in CI; no automated VoiceOver audit (performAccessibilityAudit)"
- veteran counterpart: wilderness/src/components/breathing/BreathingExercise.tsx:155-157  quote: "aria-live=\"polite\" aria-atomic=\"true\" data-testid=\"breathing-label\""
- evidence: The veteran programmatically announces its changing state to assistive tech; the target has contrast lint and AX5 screenshots but never runs an accessibility audit, so label regressions on controls like the question handle (RecorderView.swift:196) pass CI silently.
- fix: Add one `try await app.performAccessibilityAudit()` pass in the AX5 screenshot test run for the deck picker and recorder screens.

## VETERAN FEATURES WORTH BORROWING

VETERAN FEATURE 1
- what: A tiny typed haptics catalog whose calls can never throw or fail
- veteran: wilderness/src/services/nativeHaptics.ts:8  quote: "Both paths are best-effort and never throw - haptics are an enhancement, not a dependency."
- where it would go in the target: a `Haptics.swift` next to DesignTokens.swift, used by RecorderView's `.sensoryFeedback` call sites
- why it fits this app: the target already follows "every haptic has a visible twin"; a named catalog (record, pause, complete) keeps that vocabulary consistent as the app grows

VETERAN FEATURE 2
- what: A skeleton/placeholder while content loads instead of silently disabled chrome
- veteran: BoardBound/boardbound/app/quiz/question.tsx:191-192  quote: "if (!currentQuestion) { return <QuestionSkeleton />; }"
- where it would go in the target: DeckPickerView while `model.library.load()` runs
- why it fits this app: Apple loading guidance says show something as soon as possible; today the deck list area is blank with disabled buttons until load lands

VETERAN FEATURE 3
- what: Programmatic announcement when an important state changes off-focus
- veteran: wilderness/src/components/emergency/PanicOverlay.tsx:118-120  quote: "aria-live=\"assertive\" aria-atomic=\"true\""
- where it would go in the target: RecorderView when the paused banner appears (call/thermal/background reasons)
- why it fits this app: a recording that pauses itself while the user looks away is exactly the kind of event VoiceOver users must be told about, not just shown

VETERAN FEATURE 4
- what: A small transient confirmation toast after recoverable list actions
- veteran: BoardBound/boardbound/app/quiz/question.tsx:25  quote: "import { EarnToast } from \"../../components/game/EarnToast\";"
- where it would go in the target: LibraryView / SessionDetailView after Keep or Delete clip
- why it fits this app: rows currently mutate silently; a one-line toast ("Clip kept") closes the "no silent failure" loop for success paths too

## What the target already does well

Failure-state design is genuinely ahead of the bar: every degraded state (notAuthorized with Open Settings, camera unavailable, playback unavailable, sessionGone, per-reason pause banners) has specific copy and an action, all centralized in one UICopy file. And the accessibility engineering is first-class in intent — an AX5 launch mode, accessibilityIdentifier on every core control, and a draggable question card with clamped travel plus a ViewThatFits ScrollView fallback so the Record button can never be pushed off screen.
