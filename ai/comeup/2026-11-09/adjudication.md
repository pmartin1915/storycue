# comeup adjudication: StoryCue (store name Tellfolk), 2026-11-09

Reviewers held: Sonnet [x]  Kimi [x]  Sol [x] (codex exec, account pmartin1913, exit 0).
Seat letters: S = Sonnet, K = Kimi, O = Sol. Sonnet cited packet line numbers; Kimi and Sol cited file line numbers. All quotes spot-checked against the repo; none fabricated.

Packet note: the packet was ASCII-folded, which turned the U+00B7 middle dot in `UICopy.sessionSubtitle`/`sessionSummary` into `?`. Sol's finding 9 is an artifact of that, not a defect (C17).

| ID | Dim | Finding (merged) | Said by | Verified in code? | Verdict | Reason | PR / Deferred |
|---|---|---|---|---|---|---|---|
| C1 | 4 | Player cover inherits light mode: `.secondary` unavailable text, default `ProgressView` and tinted Done sit on hard black | S1 | yes, AnswerPlayerView.swift:46,57,66,69 | accepted | Light-mode gray on black is unreadable; cover is always black, so force dark | PR-1 |
| C2 | 2 | `isReady = true` before the `AVPlayerItem` is ready; later item failure never shows "unavailable" | O5 | yes, AnswerPlayerView.swift:105-108 | accepted | Spinner vanishes before media is ready; failure is silent | PR-1 |
| C3 | 3 | Audio-session `try?` swallows failures, player shows ready with no sound | S10, O6 | yes, AnswerPlayerView.swift:95-96 | accepted | Two seats; show a specific unavailable line | PR-1 |
| C4 | 4/1 | Caption auto-collapses to one line after 3 s with no way back; uses `.default` animation, not a token | O8, S11, O11 | yes, AnswerPlayerView.swift:82,117-123 | accepted | Tap toggles, no auto-collapse at accessibility sizes, `Motion.fade` | PR-1 |
| C5 | 2 | Cancelling the share sheet reports "Exported N videos." | O1 | yes, ShareSheet.swift:31 discards `completed`; ExportModel.swift:89 always `.finished(summary)` | deferred | Real (lone seat, verified), but the fix depends on whether `completionWithItemsHandler` fires before or after the SwiftUI sheet binding flips when Save to Files completes; getting it wrong would show "not shared" after a real save. Needs a device check first | ai/IDEAS.md |
| C6 | 2 | Export finished and failed share one branch: same text style, no icon, no haptic, failure has no retry | S5, K5 | yes, ExportView.swift:75-83; `start` allows `.failed` (ExportModel.swift:42-43) | accepted | Icon + success/error haptic + "Try again" on failure | PR-1 |
| C7 | 5 | ExportView bypasses `primaryAction()` and uses `spacing: 20` | O10, S12 (part) | yes, ExportView.swift:76,80,88,101 | accepted | House rule: one filled primary action via the helper; spacing from tokens | PR-1 |
| C8 | 7 | One thing, two names: "clip" vs "answer" | S15 | yes, UICopy.swift:122,126,127 vs 98,157 | accepted (part) | Rename "clip" to "answer" in user copy; "part" stays (it means a segment, not an answer) | PR-1 |
| C9 | 4 | No VoiceOver announcement for countdown, recording start, or pause banners | S7, K(VF3), O(VF1) | yes, RecorderView.swift:52-54,259-270 | accepted | All three seats; the filmer is looking at the subject | PR-2 |
| C10 | 4 | Blocking overlay leaves the recorder underneath in the VoiceOver tree | O4 | yes, RecorderView.swift:38-50 (no accessibilityHidden) | accepted | Hide underlying content while blocked | PR-2 |
| C11 | 8 | Blocking overlay text is a non-scrolling VStack; at AX5 Open Settings can fall off screen | O3 | yes, RecorderView.swift:443-471 | accepted | Wrap in ScrollView | PR-2 |
| C12 | 2/4 | "Preparing" spinner is a default `ProgressView` on opaque black (dark gray in light mode); Open Settings is an unstyled text button | S6 (part), Opus | yes, RecorderView.swift:438,451-458 | accepted | `.tint(.white)`, `.primaryAction()` | PR-2 |
| C13 | 1 | Countdown digits snap while the rest of the recorder morphs | K7 | yes, RecorderView.swift:388-391,416-422 | accepted | `.contentTransition(.numericText())` under a token animation, nil under Reduce Motion | PR-2 |
| C14 | 2 | Consent "We're ready" and Recordings are silently disabled until the library loads | S9, O7, K(VF2) | yes, ConsentView.swift:58, DeckPickerView.swift:39 | accepted (minimal) | Show a spinner in the consent button while loading. Full skeleton is a Perry pick (V3) | PR-2 |
| C15 | 6 | No launch metric / hitch baseline (M7 = 0) | K2, S13 | yes, probe | accepted | Add `XCTApplicationLaunchMetric` UI test; baseline only, no threshold yet | PR-3 |
| C16 | 4 | No `performAccessibilityAudit`; AX5 run asserts nothing | K8, S14 | yes, ScreenshotTests.swift | accepted | Separate audit test + AX5 hittable assertions | PR-3 |
| C17 | 7 | Literal "?" separator in session subtitle | O9 | no: repo has U+00B7 (UICopy.swift:100,103) | rejected | Packet ASCII-fold artifact (Opus's packet, not Sol) | - |
| C18 | 3 | Edge-swipe can pop the recorder mid-recording | S2 | no | rejected | `.navigationBarBackButtonHidden(true)` also disables the interactive pop in a SwiftUI NavigationStack; device pass S5 used Done only. Re-check on device if ever seen | - |
| C19 | 1 | Haptics fire while the mic is live and land in the take | S4 | no | rejected | iOS silences haptics while the capture session records (HOUSE-STYLE rule 10); nothing reaches the take | - |
| C20 | 2 | Keep/Delete-clip buttons lack an in-flight guard | K4 | no | rejected | `Library.keep`/`discard` are idempotent: `canDecide` requires `outcome == nil`, and keep sets the outcome before its first await (Library.swift:461-480) | - |
| C21 | 4 | Three Dynamic Type caps in the recorder (pill AX1, banner AX2, controls AX2) | S8, O2, K3 | yes, RecorderView.swift:249,279,298 | deferred | All three seats agree it breaks rule 18, but each cap was added after an AX5 screenshot review to keep Record and the question on screen. Lifting them is a layout redesign that needs AX5 screenshots on a small phone and Perry's look | ai/IDEAS.md |
| C22 | 3 | Recorder has no low-storage banner; a full disk reads as "stopped unexpectedly" | S3 | partly (banner enum has no storage case) | deferred | Needs capture-layer error mapping (AVCaptureService not in packet) | ai/IDEAS.md |
| C23 | 2 | "Camera unavailable" overlay has no retry action | S6 | yes | deferred | A retry calls `prepareCapture()`, whose `configureSession` early-return guard is the open IDEAS 2026-09-22 Sol finding 2; fix together | ai/IDEAS.md |
| C24 | 3 | Recorder audio after playback relies on unverified capture re-config | K1 | yes (comment admits it) | deferred | Already on the device-check list; needs a physical iPhone | ai/IDEAS.md |
| C25 | 5 | Remaining literals: record dot `Color.red`, `.orange`, recorder spacing 16/24/32 | S12, K6 | yes | deferred | Record red is the camera convention, not the accent; token sweep + lint widening is its own small PR | ai/IDEAS.md |
| C26 | 6 | `canExportNow` builds an `ExportModel` per render | S13 | yes, SessionDetailView.swift:137-139 | deferred | Cheap at 5-clip decks; revisit if the hitch metric says so | ai/IDEAS.md |

Not from reviewers, from probes: M4 crash reporting = 0 (Organizer only) and main is not branch-protected. Both are Perry-level choices, noted in the scorecard.

## Veteran features to borrow (merged; Perry picks)

Already covered by accepted findings, so not on the pick list: VoiceOver announcements (S-VF1, K-VF3, O-VF1 -> C9), export success/error haptic (S-VF2 -> C6), minimal loading state (part of S-VF3/K-VF2 -> C14).

| # | Feature | Proposed by | Veteran source | Where in StoryCue | Opus note |
|---|---|---|---|---|---|
| V1 | Recording timer turns amber near the 10-minute answer cap, with text, not color alone | S-VF4 | BoardBound/boardbound/app/quiz/question.tsx `timerColorClass` | RecorderView recording pill | Recommended: small, fixes a real surprise (cap pause) |
| V2 | "Nothing was saved" note when Done ends a session with zero answers (today it lands back on the consent card silently) | O-VF3 | BoardBound question.tsx "All caught up" empty state | AppModel.endSession / ConsentView | Recommended: verified gap (AppModel.swift:270 opens nothing when the record is gone) |
| V3 | Skeleton rows while the library loads | S-VF3, K-VF2 | BoardBound question.tsx `<QuestionSkeleton />` | DeckPickerView, LibraryView | Optional: C14 already covers the dead button |
| V4 | Short confirmation toast after Keep / Delete answer | K-VF4 | BoardBound `EarnToast` | LibraryView, SessionDetailView | Optional |
| V5 | One named haptics catalog (record, pause, complete) | K-VF1 | wilderness/src/services/nativeHaptics.ts | new Haptics.swift | Optional, internal tidy only |
| V6 | Recovery screen ("Back to decks") when the recorder lands in a dead state | S-VF5 | BoardBound `<QuizErrorBoundary>` | RootView | Not recommended now: no observed dead state to recover from |
| V7 | Optional spoken 3-2-1 countdown | O-VF2 | wilderness BreathingExercise.tsx audio cues | RecorderView.startCountdown | Not recommended: speech next to a hot mic and an audio-session handoff that is still unverified |
