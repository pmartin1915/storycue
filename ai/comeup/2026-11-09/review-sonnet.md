QA REVIEW: Tellfolk (storycue), reviewer 1 of 3. Line numbers are the packet's own (the first number on each line). Source paths: AnswerPlayerView, ConsentView, DeckPickerView, ExportView, RecorderView, RecordButton, RootView, SessionDetailView, StorageBanner, RecorderPresentation, UICopy, ScreenshotTests, all under storycue/StoryCue/ (tests under storycue/StoryCueUITests/). Not in packet: AVCaptureService, SessionStore, Library, Info.plist, the StyleLintTests, and the Assets.xcassets colors. I did not judge anything that depends on those.

SCORE TABLE (0-4)
| # | Dimension | Score | One-line basis |
|---|---|---|---|
| 1 | Motion and fluidity | 3 | Short springs from tokens, Reduce Motion checked on record glyph and handle, haptics paired with visible twins. Costs: one off-token animation, a haptic during live mic, no hitch baseline (M7 = 0). |
| 2 | State clarity | 3 | Every failure path has text (M5 = 3) and buttons disable in flight. Costs: silent disabled controls, dead-end overlay, failure looks like success. |
| 3 | Input and recording robustness | 2 | Strong interruption handling and countdown single-flight. Costs: swipe-back desync risk, no mid-recording storage state, swallowed audio-session errors. |
| 4 | Accessibility | 2 | Labels and 44 pt frames are good. Costs: unreadable player text in light mode, three Dynamic Type caps, no announcements for live changes, AX5 test asserts nothing. |
| 5 | Visual system | 3 | Real tokens file and one accent. A few literals (Color.red, .orange, spacing 20, .default). |
| 6 | Performance | 2 | Nothing alarming in the packet. A model is rebuilt per render. No launch or hitch metric exists (M7 = 0) and no crash reporting (M4 = 0). |
| 7 | Copy | 3 | Plain and specific. Vocabulary drifts between clip, answer, part and recording. |
| 8 | Layout resilience | 3 | Portrait-locked (M11), ViewThatFits and ScrollView fallbacks, no UIScreen.main in the packet. Fixed bars use hard caps. |
| 9 | Android parity | N/A | iOS-only. |

FINDINGS (blocker to polish)

FINDING 1
- dimension: 4
- severity: blocker
- target: storycue/StoryCue/Views/AnswerPlayerView.swift:480  quote: ".foregroundStyle(.secondary)"
- veteran counterpart: storycue RecorderView.swift:1515 (same app, the right pattern) quote: ".foregroundStyle(.white)"; veteran app: wilderness/src/components/emergency/PanicOverlay.tsx:3057 quote: "text-brand-text-primary text-center text-xl font-bold tracking-wide"
- evidence: The player's background is hard black at line 460 ("Color.black.ignoresSafeArea()") and the cover inherits the system color scheme. In light mode `.secondary` is a translucent dark gray, so the "can't be played" message (line 478) is near-invisible on black. The same holds for the default dark `ProgressView()` at line 483 and the tinted "Done" at 469. Apple (accessibility, https://developer.apple.com/design/human-interface-guidelines/accessibility): "make sure there's enough contrast between foreground text and icons and background colors" and "check the minimum contrast in both light and dark appearances".
- fix: Force the cover dark (`.environment(\.colorScheme, .dark)` on the ZStack, as `captionCard` already does at line 500) and set the unavailable text to `.white`, the spinner to `.tint(.white)`, and "Done" to `.white`. Add a screenshot of the unavailable state to the dark/light runs.

FINDING 2
- dimension: 3
- severity: should
- target: storycue/StoryCue/Views/RootView.swift:1562  quote: "set: { _ in }"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:3320 quote: "\"End Session?\","
- evidence: The recorder is pushed through a binding whose setter ignores pops, and RecorderView only hides the back button (`.navigationBarBackButtonHidden(true)` at line 1137). Hiding the button does not disable the edge-swipe pop, so a swipe can pop the view while `model.active` stays set and a camera session stays open. The "Done" button is deliberately disabled while recording (`.disabled(!presentation.canLeave)`, line 1144), but a swipe is not gated by it. The screenshot test comment at line 2606 already notes the recorder "is a root-level destination", which suggests navigation oddities.
- fix: Disable the interactive pop for the recorder (a UIKit `interactivePopGestureRecognizer.isEnabled = false` via a small representable, or present the recorder as a `fullScreenCover`). In the setter, route a user pop to `endSession()` only when `canLeave` is true. Verify on device that the swipe is blocked mid-recording.

FINDING 3
- dimension: 3
- severity: should
- target: storycue/StoryCue/RecorderPresentation.swift:1880  quote: "case none, readAloud, noAudio, paused(SegmentEndReason)"
- veteran counterpart: none in packet (the veterans have no recording path)
- evidence: Low storage is handled on the picker (StorageBanner) and on the consent card (ConsentView.swift:~583 `model.library.storage.isLow`), but the recorder's banner enum has no storage case. The pause reasons in UICopy.swift:2068-2069 end in "case .runtimeError, .mediaServicesReset, .outputEndedUnexpectedly:" returning "Recording stopped unexpectedly. What was recorded is kept." A full disk mid-answer would surface as that vague message. Apple feedback: "Show people when a command can't be carried out and help them understand why."
- fix: Re-read `importantUsageCapacity` when a segment starts (and on each ticker minute) and add a `.lowSpace` banner and a specific `PausedBanner` reason ("Your iPhone is full. What was recorded is kept."). Copy can reuse `lowSpaceBanner`.

FINDING 4
- dimension: 1
- severity: should
- target: storycue/StoryCue/Views/RecorderView.swift:1130  quote: ".sensoryFeedback(.impact(weight: .medium), trigger: presentation.primary) { old, new in"
- veteran counterpart: wilderness/src/services/nativeHaptics.ts:2761 quote: "export async function haptic(style: HapticStyle = 'medium'): Promise<void> {"
- evidence: A medium impact fires on record start and on stop, and a selection tick fires on every question change (line 1133) and drag drop, all while the microphone is live. HIG playing-haptics: "Ensure that haptic vibrations don't disrupt experiences involving device features like the camera, gyroscope, or microphone." The packet's own rule 10 (line 88) notes haptics are "silent ... while Camera is active", so the stop tick is both audible in the take and unreliable.
- fix: Keep the start haptic (it fires before the mic is hot, since the glyph morph is its visible twin) but drop the stop impact and the question-change selection tick while `presentation.showsRecordingDot` is true. Gate the rest through one helper, as the veteran does with its single `haptic()` entry point.

FINDING 5
- dimension: 2
- severity: should
- target: storycue/StoryCue/Views/ExportView.swift:791  quote: "case let .finished(message), let .failed(message):"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:3287 quote: "name={isSrsMode ? \"checkmark-circle-outline\" : \"alert-circle-outline\"}"
- evidence: Success and failure share one branch: identical plain text plus an identical prominent "Done". Failure has no icon, no distinct styling and no haptic. Apple accessibility: "Convey information with more than color alone ... distinct shapes or icons". Apple feedback: "Make sure all feedback is accessible" (color, text, sound, haptics). The only visible difference is the sentence.
- fix: Split the case. Show a checkmark.circle symbol for success and exclamationmark.triangle for failure (hidden from VoiceOver, with the message as the label), and fire `.sensoryFeedback(.success/.error, trigger: model.phase)` for those two phases. On failure add a second bordered "Try again" button that calls the same `start(...)` the user chose.

FINDING 6
- dimension: 2
- severity: should
- target: storycue/StoryCue/Views/RecorderView.swift:1540  quote: "Text(UICopy.unavailableBody)"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:3304 quote: "<Text className=\"font-bold text-white\">Back to Study</Text>"; and LibraryView.swift:906-907 quote: "Button(UICopy.libraryEmptyAction) { dismiss() }" then ".primaryAction()"
- evidence: Rule 12 (packet line 90) requires each error state "with one action". The "Camera unavailable" overlay (1535-1544) has no button at all, only a toolbar Done, and the body says "try again" (UICopy 2054) with nothing to retry. The "notAuthorized" overlay's lone button (1525) is unstyled title2 text in the accent color on opaque black, with no prominent style or contrast check.
- fix: Add a "Try again" button on `.unavailable` that re-runs `store.prepareCapture()`. Style the Open Settings and Try again buttons with `.primaryAction()`, tinting to keep the contrast over black.

FINDING 7
- dimension: 4
- severity: should
- target: storycue/StoryCue/Views/RecorderView.swift:1346  quote: "private func bannerText(_ text: String) -> some View {"
- veteran counterpart: wilderness/src/components/breathing/BreathingExercise.tsx:2942 quote: "aria-live=\"polite\""
- evidence: Countdown digits (line 1490, `countdownOverlay`), the pause banners (a call or a thermal pause) and the recording indicator appear and change with no VoiceOver announcement. `.accessibilityLabel` on the indicator (1325) only helps if the user navigates to it. Rule 17 (packet line 95): "Do the core task with your eyes closed." A VoiceOver user filming does not learn that a call paused the take.
- fix: On `presentation.banner` and `countdown` changes, post `AccessibilityNotification.Announcement(...)` with the banner text or "3, 2, 1, recording". Keep `Task` cancelation paired so a cancelled countdown does not announce.

FINDING 8
- dimension: 4
- severity: should
- target: storycue/StoryCue/Views/RecorderView.swift:1353  quote: ".dynamicTypeSize(...DynamicTypeSize.accessibility2)"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:3350 quote: "<ScrollView className=\"flex-1 bg-white dark:bg-gray-900\" contentContainerClassName=\"p-5 pb-12\">"
- evidence: Three caps (banner at 1353, controls at 1372, recording pill at 1323 with `accessibility1`). Rule 18 (packet line 96) says "scroll or wrap instead" and "do not cap". Rule 18's own check is AX5. Apple accessibility: "give people the option to enlarge text by at least 200 percent". The code comments admit the banner "was cut to 'First, have them...'" and was fixed by capping.
- fix: For the banner and controls, let text scale and move the banner inside the scrolling `questionArea` (or give it its own ScrollView with a max height). For the pill, move the timer to a fixed-size overlay that can wrap to two lines instead of clipping the nav bar.

FINDING 9
- dimension: 2
- severity: should
- target: storycue/StoryCue/Views/ConsentView.swift:604  quote: ".disabled(isBeginning || !model.library.isLoaded)"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:3311 quote: "return <QuestionSkeleton />;"
- evidence: "We're ready" and the Recordings button (DeckPickerView.swift:654 `.disabled(!model.library.isLoaded)`) are dead until the library loads. The load is fire-and-forget (`.task { await model.library.load() }`, StoryCueApp 327), so if it stalls or fails there is no spinner, message or retry: a gray button that never wakes. Apple loading: "Show something as soon as possible" and "Clearly communicate that content is loading".
- fix: While `!isLoaded` show a small `ProgressView` in the button label (or "Loading..." text). If load throws, show a `ContentUnavailableView` with "Try again". Disable only the Recordings link, not the rest of the picker.

FINDING 10
- dimension: 3
- severity: should
- target: storycue/StoryCue/Views/AnswerPlayerView.swift:509  quote: "try? audioSession.setCategory(.playback, mode: .moviePlayback)"
- veteran counterpart: wilderness/src/services/nativeHaptics.ts:2766 quote: "// Native unavailable (e.g. plugin not built) - fall through to web." (the veteran fails soft with a fallback)
- evidence: Both audio-session calls swallow errors (`try?`, 509-510). If another app holds the session, playback still shows a ready player with no sound and no message. The comment at 507 admits the recorder re-acquire is "unverified" and "on the S2c device-check list". `release()` (line 542) also deactivates with `try?`.
- fix: Catch the failure and set `isUnavailable` with a specific line ("Another app is using the audio. Close it and try again."). Make the unverified re-acquire a real, automated check in the device list rather than a comment.

FINDING 11
- dimension: 1
- severity: polish
- target: storycue/StoryCue/Views/AnswerPlayerView.swift:534  quote: "withAnimation(reduceMotion ? nil : .default) {"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:3126 quote: "import { useReduceMotion } from \"../../lib/hooks/useReduceMotion\";"
- evidence: Rule 8 (packet line 86): "Motion values come only from the tokens file." DesignTokens.Motion defines `morph` and `fade` (lines 367-368), but the caption shrink uses the system default. The 3 s auto-shrink is also a timer-driven change the user cannot cancel (HIG motion: "Let people cancel motion"). The StyleLint test is said to cover "literal animations", yet `.default` slips through.
- fix: Use `DesignTokens.Motion.fade` and extend the lint rule to ban `.default` animation. Consider letting a tap on the caption toggle it, so the shrink is reversible.

FINDING 12
- dimension: 5
- severity: polish
- target: storycue/StoryCue/Views/RecordButton.swift:1025  quote: ".fill(Color.red)"
- veteran counterpart: burn-wizard/app/src/styles/design-system.css:3396 quote: "--primary: 174 76% 27%; /* Professional medical teal */"; and 3441 quote: "--radius: 0.75rem; /* Consistent border radius */"
- evidence: Off-token one-offs: `Color.red` here against the dedicated `recordingFill` token (DesignTokens 396); `.foregroundStyle(.orange)` (StorageBanner.swift:1837); `spacing: 20` (ExportView.swift:792 and 804, not in the 4/8/12/16/24 scale); `VStack(spacing: 16)` and `.padding(.bottom, 24)` literals in RecorderView (1112, 1118); `.black.opacity(0.5)` at AnswerPlayerView:472. Rule 5 (line 83): "Grep for padding and radius literals outside the tokens file."
- fix: Add `RecordButton.dotFill`, `Warning.tint` and `Spacing.l2`/reuse `xl` tokens, and replace the literals. Widen the StyleLint grep to cover `spacing:` and `Color.red/.orange`.

FINDING 13
- dimension: 6
- severity: polish
- target: storycue/StoryCue/Views/SessionDetailView.swift:1718  quote: "ExportModel(sessionID: sessionID, library: library, exporter: model.exporter).canExport"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:3191 quote: "const todayTotal = useMemo(() => getTodayAnsweredCount(), [isAnswered]);"
- evidence: A full `ExportModel` is allocated every time `canExportNow` is read, which happens on every body evaluation of a list that also re-runs `library.record(id:)` (lines 1603, 1611) and `shownClips` filtering. Fine at 5 clips; the cost grows with sessions, and nothing measures it (M7: no XCTHitchMetric or baseline).
- fix: Expose `canExport(for:)` on `Library` (or `Exporter`), cache `record` once per render, and add one `XCTHitchMetric` scroll test on a seeded 100-session demo.

FINDING 14
- dimension: 4
- severity: polish
- target: storycue/StoryCueUITests/ScreenshotTests.swift:2703  quote: "if handle.waitForExistence(timeout: 2) {"
- veteran counterpart: none in packet
- evidence: The AX5 run asserts nothing: if the handle never appears, the test passes with fewer screenshots, and on failure the review steps are continue-on-error (M8). The dark run does assert card movement (2664, 2670), so the pattern exists. Rule 18: "Check at AX5."
- fix: At AX5 assert that `recordButton.isHittable`, that `doneButton.isHittable`, and that the question panel and the record button frames do not intersect. Add `try app.performAccessibilityAudit()` to the AX5 and dark runs (M6 lists it as missing).

FINDING 15
- dimension: 7
- severity: polish
- target: storycue/StoryCue/UICopy.swift:2124  quote: "static let deleteClip = \"Delete clip\""
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:3321 quote: "`You've answered ${questionsAnswered} question${questionsAnswered === 1 ? \"\" : \"s\"}. End now and see your results?`,"
- evidence: One thing has four names: "clip" (2124), "answer" (2096), "part" (`"1 part couldn't be read and was left out."`, 2149) and "recording" (2126, `deleteSession`), while "Recording" is also the live-indicator word (2046). Users see "Delete clip" beside "Part of this answer may be incomplete."
- fix: Pick answer (one question) and recording (one session) and use only those. Rename "Delete clip" to "Delete answer", "1 part" to "1 answer", and "Recovered clips" to "Recovered answers".

VETERAN FEATURES WORTH BORROWING (Perry picks)

VETERAN FEATURE 1
- what: Announce phase changes to screen readers with a polite live region.
- veteran: wilderness/src/components/breathing/BreathingExercise.tsx:2942  quote: "aria-live=\"polite\""
- where it would go in the target: RecorderView, countdown overlay and banner row (see FINDING 7)
- why it fits this app: The filmer is looking at the subject, not the phone; spoken "3, 2, 1" and "Paused for a call" are the only status they get.

VETERAN FEATURE 2
- what: A success or error notification haptic paired with a visible reveal.
- veteran: BoardBound/boardbound/app/quiz/question.tsx:3253  quote: "Haptics.notificationAsync("
- where it would go in the target: ExportView finished and failed phases (`.sensoryFeedback(.success/.error, trigger: model.phase)`)
- why it fits this app: Export can run a long time with the phone in a pocket or hand; a distinct tap tells them it ended and how, and the SessionDetailView success haptic (1615) already sets the pattern.

VETERAN FEATURE 3
- what: A loading skeleton instead of a dead screen while data loads.
- veteran: BoardBound/boardbound/app/quiz/question.tsx:3311  quote: "return <QuestionSkeleton />;"
- where it would go in the target: DeckPickerView and LibraryView while `!model.library.isLoaded`
- why it fits this app: The Recordings button and "We're ready" are disabled until load finishes (FINDING 9); a skeleton row removes the "is it broken?" moment on a cold launch.

VETERAN FEATURE 4
- what: A timer that changes color as it nears a limit (amber at 90 s, red at 120 s).
- veteran: BoardBound/boardbound/app/quiz/question.tsx:3341  quote: "const timerColorClass ="
- where it would go in the target: RecorderView recording pill (`recordingIndicator`), approaching the ten-minute segment cap
- why it fits this app: The app pauses with "Ten minutes on this answer. Keep going?" (UICopy 2061); a warning tint at 9 minutes avoids the surprise, and it must be paired with text so it is not color alone.

VETERAN FEATURE 5
- what: An error boundary that turns a crashed screen into a recovery screen with a way out.
- veteran: BoardBound/boardbound/app/quiz/question.tsx:3148  quote: "<QuizErrorBoundary>"
- where it would go in the target: RootView, as a SwiftUI-side recovery state (for example when `active` references a dead capture service), with a "Back to decks" action
- why it fits this app: There is no crash reporting (M4 = 0) and the recorder's failure paths all end at Done; one recovery screen keeps a bad state from stranding a family mid-interview.

WHAT THE APP DOES WELL
1. Failure and state handling is thorough and unit-testable: `RecorderPresentation.make` derives every control, banner, and the `canLeave` rule from one pure function, and every failure path (not authorized, unavailable, playback, export) has plain text.
2. The accessibility thought is visible in the code: a token file with a contrast rationale for text over a live camera feed (70% black backing), 44 pt frames with `contentShape`, ViewThatFits and ScrollView fallbacks at AX sizes, single-flight guards on the countdown and export, and an in-app consent/priming screen before any system prompt.
