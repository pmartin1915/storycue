| Dimension | Score (0-4) | Packet-based assessment |
|---|---:|---|
| 1. Motion and fluidity | 3 | Short tokenized recorder motion, Reduce Motion handling, meaningful haptics; playback animation bypasses tokens. No measured fluidity baseline. |
| 2. State clarity | 2 | Explicit recorder/export states, but startup can silently disable actions and sharing can report success after cancellation. |
| 3. Input and recording robustness | 3 | Countdown single-flight, background cancellation, session shutdown coordination, and recovery UI are strong. Capture-service internals are not in packet. |
| 4. Accessibility | 2 | System text styles, labels, large targets, and adaptive rows; explicit text-size caps and incomplete modal isolation remain. |
| 5. Visual system | 3 | Shared palette, typography, radii, and native chrome; several views bypass shared spacing and action styling. |
| 6. Performance | 2 | Lists and cancellation-aware playback are sensible. No launch/hitch baseline; composition and capture implementation are not in packet. |
| 7. Copy | 3 | Mostly specific and calm; literal question-mark separators and misleading export completion need correction. |
| 8. Layout resilience | 2 | Scrolling and accessibility-size alternatives are present. Blocking overlays lack scrolling; measured probe reports portrait lock. Duo-prep document is not in packet. |

FINDING 1
- dimension: 2
- severity: should
- target: storycue/StoryCue/Views/ShareSheet.swift:31  quote: "controller.completionWithItemsHandler = { _, _, _, _ in"
- veteran counterpart: wilderness/src/components/breathing/BreathingExercise.tsx:67  quote: "if (nextCycle >= pattern.totalCycles) {"
- evidence: The share wrapper discards completion and error information. ExportModel.swift:89 then unconditionally sets "phase = .finished(summary(for: result, destination: .files))". Closing or cancelling the activity sheet therefore produces the same "Exported" summary as completing an activity. The veteran gates completion on its actual completion condition.
- fix: Pass the activity's completed flag and error into ExportModel. Clean up temporary files for every outcome, but show success only when completion is reported; preserve a neutral cancelled state and surface reported errors.

FINDING 2
- dimension: 4
- severity: should
- target: storycue/StoryCue/Views/RecorderView.swift:279  quote: ".dynamicTypeSize(...DynamicTypeSize.accessibility2)"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:231  quote: "<ScrollView className=\"flex-1 bg-white dark:bg-gray-900\" contentContainerClassName=\"p-5 pb-12\">"
- evidence: RecorderView also caps the recording indicator at accessibility1 on line 249 and controls at accessibility2 on line 298. An AX5 launch therefore does not exercise these elements at the user's requested size. This directly conflicts with HOUSE-STYLE rule 18's instruction to wrap or scroll instead of capping text.
- fix: Remove the three caps. Move the recording status into flexible content at large sizes and let banners and controls wrap or scroll while keeping Record reachable. Verify every recorder state at AX5 on a small iPhone.

FINDING 3
- dimension: 8
- severity: should
- target: storycue/StoryCue/Views/RecorderView.swift:444  quote: "VStack(spacing: 16) {"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:231  quote: "<ScrollView className=\"flex-1 bg-white dark:bg-gray-900\" contentContainerClassName=\"p-5 pb-12\">"
- evidence: The permission-denied overlay contains a title, body, and Settings button in a non-scrolling VStack; the unavailable overlay uses the same arrangement. Unlike the question area, these branches have no scrolling fallback when their natural height exceeds the available space.
- fix: Put blocking-state content in a safe-area-aware ScrollView with a flexible minimum height. Verify that the complete explanation and Open Settings remain reachable at AX5 on the smallest supported iPhone.

FINDING 4
- dimension: 4
- severity: should
- target: storycue/StoryCue/Views/RecorderView.swift:48  quote: "if presentation.blocking != .none {"
- veteran counterpart: wilderness/src/components/emergency/PanicOverlay.tsx:69  quote: "aria-modal=\"true\""
- evidence: The blocking overlay is drawn above the question and controls, but the underlying recorder VStack remains in the accessibility tree: no accessibilityHidden condition is applied to it. The veteran explicitly identifies its overlay as modal. Visual coverage alone does not establish that hidden recorder content is excluded from VoiceOver navigation.
- fix: Hide the underlying recorder content from accessibility while a blocking state is present, while retaining the permitted Done action. Move accessibility focus to the blocking title when the state changes and verify traversal through permission-denied and unavailable states.

FINDING 5
- dimension: 2
- severity: should
- target: storycue/StoryCue/Views/AnswerPlayerView.swift:107  quote: "isReady = true"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:191  quote: "if (!currentQuestion) {"
- evidence: Playback marks itself ready immediately after constructing an AVPlayerItem, without observing that item's readiness or failure. Consequently, the spinner disappears before media readiness is established, and a later player-item failure never sets isUnavailable. The veteran retains its loading presentation until its required content exists.
- fix: Observe AVPlayerItem.status and keep loading visible until readyToPlay. Map item failure to the existing unavailable state and release the observation when playback is dismissed.

FINDING 6
- dimension: 3
- severity: should
- target: storycue/StoryCue/Views/AnswerPlayerView.swift:96  quote: "try? audioSession.setActive(true)"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:178  quote: ": \"Questions may not have loaded yet. Try restarting the app.\"}"
- evidence: Both playback audio-session setup calls discard errors, and execution continues toward isReady and autoplay. A failed activation therefore has no corresponding failure state or explanation in this view. The veteran presents an explanation when its core task cannot proceed.
- fix: Handle category and activation failures explicitly. Either recover successfully before starting playback or show the existing unavailable presentation with an actionable explanation; do not transition to ready solely because composition construction succeeded.

FINDING 7
- dimension: 2
- severity: should
- target: storycue/StoryCue/Views/DeckPickerView.swift:39  quote: ".disabled(!model.library.isLoaded)"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:192  quote: "return <QuestionSkeleton />;"
- evidence: RootView starts library.load(), while DeckPicker disables Recordings and ConsentView disables its primary action until isLoaded. Neither visible screen explains this prerequisite with a loading status. During a slow load, the user sees disabled actions without knowing why.
- fix: Show a concise loading status tied to library readiness on the deck picker and consent screen. Keep the existing disabled guards and remove the status when loading completes. Library.load() error handling is not in packet, so its failure behavior cannot be assessed.

FINDING 8
- dimension: 4
- severity: should
- target: storycue/StoryCue/Views/AnswerPlayerView.swift:82  quote: ".lineLimit(captionExpanded ? nil : 1)"
- veteran counterpart: wilderness/src/components/breathing/BreathingExercise.tsx:161  quote: "{currentStep.label}"
- evidence: shrinkCaption() unconditionally sets captionExpanded to false after three seconds. There is no control to expand it again. A long question becomes permanently truncated visually during playback, including at accessibility text sizes; Reduce Motion only changes whether that collapse animates.
- fix: Keep the full question available through an expand/collapse button with an explicit accessibility label and state. Avoid automatic collapse at accessibility sizes, and provide scrolling when the expanded question exceeds its available area.

FINDING 9
- dimension: 7
- severity: polish
- target: storycue/StoryCue/UICopy.swift:100  quote: "\"\(date.formatted(.dateTime.month(.abbreviated).day())) ? \(clipCount(count))\""
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:235  quote: "{questionNumber} / {sessionTarget} . {currentQuestion ? DOMAIN_LABELS[currentQuestion.domain] : \"\"}"
- evidence: sessionSubtitle and sessionSummary insert a literal question mark between the date and answer count. This renders uncertain-looking copy rather than a neutral separator. The veteran's compact metadata uses deliberate separators.
- fix: Replace the question mark in both functions with consistent punctuation, such as a comma. Verify the rendered list and detail header and their VoiceOver reading.

FINDING 10
- dimension: 5
- severity: polish
- target: storycue/StoryCue/Views/ExportView.swift:101  quote: ".buttonStyle(.borderedProminent)"
- veteran counterpart: burn-wizard/app/src/styles/design-system.css:28  quote: "--primary-foreground: 0 0% 100%;"
- evidence: The target defines primaryAction() specifically to apply its OnAccent foreground, but export's primary and Done buttons use borderedProminent directly. ExportView also repeatedly uses "spacing: 20" rather than a shared spacing token. These bypass the target's centralized visual contract; the packet does not establish an actual contrast failure.
- fix: Apply primaryAction() to export's filled primary buttons. Use the shared spacing scale, adding a justified token only if the existing values cannot express the intended layout.

FINDING 11
- dimension: 1
- severity: polish
- target: storycue/StoryCue/Views/AnswerPlayerView.swift:120  quote: "withAnimation(reduceMotion ? nil : .default) {"
- veteran counterpart: wilderness/src/components/breathing/BreathingExercise.tsx:150  quote: "transition: `transform ${transitionSeconds}s ease-in-out`,"
- evidence: Playback uses an unspecified default animation despite DesignTokens.Motion defining the app's short morph and fade animations. HOUSE-STYLE rule 8 requires motion values to come from the tokens file. The veteran explicitly controls transition timing.
- fix: Use the appropriate DesignTokens.Motion animation while retaining Reduce Motion handling. If caption collapse changes position without conveying useful information, use the shared fade instead.

VETERAN FEATURE 1
- what: Announce countdown and important recorder state changes to VoiceOver.
- veteran: wilderness/src/components/breathing/BreathingExercise.tsx:156  quote: "aria-live=\"polite\""
- where it would go in the target: RecorderView.swift countdownOverlay and bannerRow.
- why it fits this app: People can follow recording preparation and interruptions without keeping accessibility focus on changing text.

VETERAN FEATURE 2
- what: Offer an optional spoken countdown before capture begins.
- veteran: wilderness/src/components/breathing/BreathingExercise.tsx:40  quote: "if (!audioCues || !speechSupported) return;"
- where it would go in the target: RecorderView.swift startCountdown().
- why it fits this app: The interviewer and subject can prepare while looking toward the camera; speech should finish before recording starts.

VETERAN FEATURE 3
- what: Show a calm, explicit completion state when a session ends with no saved answers.
- veteran: BoardBound/boardbound/app/quiz/question.tsx:173  quote: "{isSrsMode ? \"All caught up\" : \"No questions available\"}"
- where it would go in the target: SessionDetailView.swift post-recording header.
- why it fits this app: The current completion header requires a positive manifest count, leaving zero-answer completion without an explanation.

Tellfolk already pairs native navigation and playback controls with clear consent, local-storage copy, and deliberate camera-overlay contrast.
Its countdown guards, interruption presentation, recovered-clip decisions, export cancellation, and adaptive question layout show strong attention to recording reliability.