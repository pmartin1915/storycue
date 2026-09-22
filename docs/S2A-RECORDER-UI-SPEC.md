# S2a spec — recorder core UI

_Written 2026-09-22. Step S2a of `docs/STRATEGY-2026-09-22.md`. Builds on S1 (`SessionStore`,
`docs/S1-SESSIONSTORE-SPEC.md`). Product rules: `docs/PLAN.md` §2 and
`docs/research/SYNTHESIS-2026-09.md` Q7. Same contract as S1: every type, method, file and
test name is fixed so `/orchestrate` (Kimi executes; Kimi layout review; Sol audits) doesn't
invent shapes. **Single-screen 1.0** — no Duo code, no outer display._

## Scope

**In:** `AppModel` (session lifetime + lazy service construction), the preview layer, four
SwiftUI screens (deck picker → consent card → recorder, plus the blocking states),
`RecorderPresentation` (pure: everything the recorder shows is derived here and unit-tested),
scene-phase → event mapping, the 3-2-1 start countdown, one copy table, portrait lock.

**Out (S2b/S3/S4):** library, session index, orphan-recovery UI (the store already publishes
`recoveredSegments`; S2b shows it), export, deck copy (questions stay `// TODO copy`), any
screenshot/UI test, Duo/outer display.

## 1. Preview layer — `StoryCue/CameraPreview.swift`

Apple's AVCam pattern. The capture service owns one `AVCaptureSession` object for its whole
life and hands the UI a `Sendable` source that can connect a preview view to it.

```swift
import AVFoundation
import SwiftUI
import UIKit

protocol PreviewSource: Sendable {
    @MainActor func connect(to target: any PreviewTarget)
}
@MainActor protocol PreviewTarget: AnyObject {
    func setSession(_ session: AVCaptureSession)
}

/// The real source: holds the capture service's permanent session object.
struct SessionPreviewSource: PreviewSource {
    let session: AVCaptureSession
    @MainActor func connect(to target: any PreviewTarget) { target.setSession(session) }
}
/// Mock / simulator: connects nothing; the view shows its black placeholder.
struct NoPreviewSource: PreviewSource {
    @MainActor func connect(to target: any PreviewTarget) {}
}

final class PreviewUIView: UIView, PreviewTarget {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }  // see note
    func setSession(_ session: AVCaptureSession)   // previewLayer.session = session; videoGravity = .resizeAspectFill
}

struct CameraPreview: UIViewRepresentable {
    let source: any PreviewSource
    func makeUIView(context: Context) -> PreviewUIView      // backgroundColor .black; source.connect(to: view)
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}
```

- `as!` in `previewLayer`: forbidden like `try!`. Write it as
  `guard let l = layer as? AVCaptureVideoPreviewLayer else { preconditionFailure("layerClass") }`.
- **Sendable risk, pre-registered:** `SessionPreviewSource: Sendable` stores an
  `AVCaptureSession`. Apple's AVCam sample does exactly this, so the SDK is expected to accept it.
  If CI reports that `AVCaptureSession` isn't `Sendable`, the boss fix is
  `@preconcurrency import AVFoundation` in this one file — not `@unchecked`, not
  `nonisolated(unsafe)`. The executor does not improvise it.

**`CaptureService` gains two requirements:**

```swift
nonisolated var previewSource: any PreviewSource { get }
func shutdown() async      // stopRunning, cancel per-session notification tasks, finish the events stream; idempotent
```

**`AVCaptureService` changes (amends S1):**
- `private let session = AVCaptureSession()` created in `init` (constructing the object does no
  device lookup, so the nil-safety rule still holds). `nonisolated let previewSource: any
  PreviewSource` = `SessionPreviewSource(session: session)`, set in `init`.
- `configureSession()` configures **that** `session` (inside `beginConfiguration()` /
  `commitConfiguration()`) instead of creating a new one; the `captureSession` optional goes
  away. `startCaptureNotificationTasks(for: session)` is unchanged.
- `recreateSession()`: cancel the per-session notification tasks, `stopRunning()` if running,
  invalidate `pressureObservation`, then inside begin/commitConfiguration remove every input and
  output, reset `movieFileOutput`, `recordingDelegate`, `videoDevice`, `hasAudio`, `configured`,
  then `try await configureSession()`. The session *object* survives, so a connected preview
  keeps working.
- `shutdown()`: cancel the per-session tasks, `stopRunning()` if running, `continuation.finish()`.
  Calling it twice, or before `configureSession()`, is a no-op beyond the first finish.

`MockCaptureService`: `previewSource` is `NoPreviewSource()`; `shutdown()` increments
`shutdownCount` (new, `private(set)`) and finishes its continuation.

## 2. `AppModel` — `StoryCue/AppModel.swift`

One camera, one session at a time. A new `SessionStore` **and a new capture service** per
recording session: `AsyncStream` is single-consumer, so a second store can't re-iterate the first
service's `events`. The ledger is one instance app-wide (one file, one actor).

```swift
@MainActor @Observable
final class AppModel {
    struct ActiveSession {
        let deck: Deck
        let store: SessionStore
        let capture: any CaptureService
    }
    private(set) var active: ActiveSession?
    let ledger: SegmentLedger
    let segmentDirectory: URL

    init(segmentDirectory: URL,
         makeCapture: @escaping @MainActor (URL) -> any CaptureService,
         makeBackground: @escaping @MainActor () -> any BackgroundTaskRunner)

    /// Production wiring. Constructs NO capture service (nil-safety rule): the factories run in beginSession.
    static func production() -> AppModel

    private(set) var isPreparing = false

    /// Creates capture + store for `deck`, sets `active`, calls store.start(), sets
    /// isPreparing = true, `await store.prepareCapture()`, isPreparing = false. If a session is
    /// already active, does nothing. prepareCapture never throws (S1 §5 rule 5): failures land in
    /// store.captureAvailability, which the recorder shows as a blocking state — so `active`
    /// stays set on failure, by design, and the user leaves with "Done".
    func beginSession(deck: Deck) async
    /// Refuses (returns false, changes nothing) while isPreparing, or while the active store's
    /// phase is .recording or .finishing. The check, store.stop() and `active = nil` all happen
    /// synchronously on the main actor BEFORE the first await, so no event can slip between
    /// them (AppModel and SessionStore are both @MainActor); then `await capture.shutdown()`
    /// on the captured local. Returns true. No active session → true.
    @discardableResult func endSession() async -> Bool
}
```

`init` builds `ledger = SegmentLedger(directory: segmentDirectory)` itself (the ledger's init
touches no disk; it creates its directory on first write). `production()`:
`segmentDirectory = (try? SegmentFiles.defaultDirectory()) ?? FileManager.default.urls(for:
.applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Segments",
isDirectory: true)` (the service creates it before the first write);
`makeCapture = { AVCaptureService(segmentDirectory: $0) }`; `makeBackground = { UIKitBackgroundTaskRunner() }`.
No S1 test references `captureSession` (checked: `AVCaptureServiceTests` constructs the service
and calls `configureSession()` only), so removing it keeps "all S1 tests pass" verifiable.

## 3. Screens — `StoryCue/Views/`

All text through `UICopy` (section 5). Text uses Dynamic Type text styles only (`.largeTitle`,
`.title2`, `.body`, `.callout`, `.footnote`, `.monospacedDigit()` for the timer); no fixed point
sizes. Every button has an accessibility label equal to its visible text. Minimum tap target 44 pt.

- **`StoryCueApp.swift`** (replaces the placeholder `ContentView`, which is deleted along with
  its `#Preview`): `@State private var model = AppModel.production()`; `WindowGroup {
  RootView(model: model) }`.
- **`RootView`**: `NavigationStack` over `DeckPickerView`. Navigation to the recorder is driven
  by `model.active != nil`: `.navigationDestination(isPresented: Binding(get: { model.active
  != nil }, set: { _ in }))` whose destination is `if let active = model.active {
  RecorderView(session: active, model: model).id(ObjectIdentifier(active.store)) }` — no
  force-unwrap, and the `.id` gives each session a fresh view so its preview connects to the new
  capture service instead of reusing the previous one's (black) representable.
- **`DeckPickerView`**: a `List` of `Deck.v1Decks` rows (title + "N questions"). Tapping a deck
  pushes `ConsentView(deck:)`.
- **`ConsentView(deck:model:)`** — the consent card **and** the permission priming screen: title
  `UICopy.consentTitle`, body `UICopy.consentBody`, the read-aloud line `UICopy.readAloudLine`
  in a quoted callout, and `UICopy.privacyNote` ("recordings stay on this phone"). One primary
  button `UICopy.consentConfirm` → `Task { await model.beginSession(deck: deck) }`. The system
  camera/mic prompts appear after this tap, with the card's explanation already on screen.
  The button is disabled while `beginSession` is in flight.
- **`RecorderView(session: AppModel.ActiveSession, model:)`**:
  - Full-bleed `CameraPreview(source: session.capture.previewSource)` behind everything.
  - Top: `UICopy.questionCounter(index, count)`, the current question (`.largeTitle`, white on a
    translucent black backing, ≥7:1 contrast), and the next-question preview (`.callout`,
    secondary) when `nextQuestionPreview` is non-nil.
  - Recording dot + count-up timer when `presentation.showsRecordingDot`.
  - Banner row (`presentation.banner`) above the controls.
  - Controls: primary button (`presentation.primary`), the advance button
    (`presentation.advance`), and a leading "Done" toolbar button that calls
    `model.endSession()` and is disabled when `presentation.canLeave` is false.
  - Blocking overlay when `presentation.blocking != .none` (section 4 table).
  - Timer: `.task { store.startTicker() }` and `.onDisappear { }` does nothing extra —
    `endSession()` stops the store.
  - `.navigationBarBackButtonHidden(true)` — leaving is only through "Done", so a live
    recording can't be abandoned by a swipe.
  - **Button → action mapping** (the only wiring):

    | Presentation value | Action |
    |---|---|
    | primary `.record` / `.resume` | start the countdown (below) |
    | primary `.cancelCountdown` | cancel the countdown |
    | primary `.pause` | `store.send(.tapPause)` |
    | primary `.saving` / `.unavailable` | disabled |
    | advance `.skip` | `store.send(.tapSkip)` |
    | advance `.next` | `store.send(.tapNextQuestion)` |
    | advance `.finish` | `Task { await model.endSession() }` |
    | advance `.disabled` | disabled |

  - **Countdown:** `@State private var countdown: Int?` and `@State private var countdownTask:
    Task<Void, Never>?`. Starting sets `countdown = 3` and stores a task that loops 3→2→1 with
    `try await Task.sleep(for: .seconds(1))` (on throw: return without sending anything), then
    sets `countdown = nil` and sends `.tapRecord` if the phase is still `.idle` or `.tapResume` if
    still `.paused` — re-read at that moment, never the phase from when the countdown started.
    **Cancel** = `countdownTask?.cancel(); countdownTask = nil; countdown = nil`, triggered by:
    the cancel tap; any scene-phase change away from `.active`; `presentation.blocking`
    becoming non-`.none`; `.onDisappear`. No countdown for pause, next or skip.
  - **Scene phase:** `@Environment(\.scenePhase)`; `.onChange(of: scenePhase) { old, new in
    if new != .active { cancelCountdown() }; if let e = ScenePhaseMapping.event(from: old, to: new)
    { store.send(e) } }`. A home press delivers resign-active then did-enter-background; the
    reducer already handles that pair (S1 tests).
  - **Blocking overlay** (opaque black, covers preview and controls; "Done" stays usable when
    `canLeave`):

    | `blocking` | Shows |
    |---|---|
    | `.preparing` | `ProgressView` + `UICopy.preparing` |
    | `.notAuthorized` | `notAuthorizedTitle`, `notAuthorizedBody`, button `openSettings` |
    | `.unavailable` | `unavailableTitle`, `unavailableBody`; no button |
- **Portrait lock:** `project.yml` `UISupportedInterfaceOrientations` becomes portrait only (the
  whole app is portrait in 1.0). This is the only `project.yml` change.

## 4. `RecorderPresentation` — `StoryCue/RecorderPresentation.swift` (pure, no SwiftUI)

```swift
struct RecorderPresentation: Equatable {
    enum Primary: Equatable { case record, pause, resume, saving, cancelCountdown, unavailable }
    enum Advance: Equatable { case skip, next, finish, disabled }
    enum Blocking: Equatable { case none, preparing, notAuthorized, unavailable }
    enum Banner: Equatable { case none, readAloud, noAudio, paused(SegmentEndReason) }

    var primary: Primary
    var advance: Advance
    var blocking: Blocking
    var banner: Banner
    var showsRecordingDot: Bool
    var timerText: String?          // TimerFormat.string(elapsed) while .recording, else nil
    var countdownText: String?      // "3" / "2" / "1" while counting down, else nil
    var canLeave: Bool

    static func make(state: SessionState,
                     availability: CaptureAvailability,
                     hasAudioInput: Bool,
                     elapsed: TimeInterval,
                     countdown: Int?) -> RecorderPresentation
}

enum TimerFormat {
    /// Count-up. "0:00", "0:59", "1:00", "9:59", "10:00", "61:05". Never negative (clamps at 0),
    /// never hours. Floors fractional seconds.
    static func string(_ elapsed: TimeInterval) -> String
}

enum ScenePhaseMapping {   // in its own file, imports SwiftUI
    /// .active→.inactive: .sceneWillResignActive; any→.background: .sceneDidEnterBackground;
    /// any→.active (from .inactive or .background): .sceneDidBecomeActive; anything else nil.
    static func event(from old: ScenePhase, to new: ScenePhase) -> SessionEvent?
}
```

Rules for `make`, in precedence order:

| Field | Rule |
|---|---|
| `blocking` | `.unknown` → `.preparing`; `.notAuthorized` → `.notAuthorized`; `.unavailable` → `.unavailable`; `.ready` → `.none` |
| `primary` | blocking ≠ `.none` → `.unavailable`; else `countdown != nil` → `.cancelCountdown`; else by phase: `.idle` → `.record`, `.recording` → `.pause`, `.finishing` → `.saving`, `.paused` → `.resume` |
| `advance` | blocking ≠ `.none`, or phase `.finishing`, or `countdown != nil` → `.disabled`; else at the last question and phase ≠ `.recording` → `.finish`; else the current question has any segment in `state.clips` → `.next`; else `.skip` |
| `banner` | phase `.paused(reason)` with reason ∉ {`.userPause`, `.userStop`} → `.paused(reason)` (`.userStop` never pauses — the reducer routes it to `.idle` — but the rule doesn't lean on that); else blocking `.none` and `!hasAudioInput` → `.noAudio`; else phase `.idle`, `questionIndex == 0` and `state.clips` empty → `.readAloud`; else `.none` |
| `showsRecordingDot` | phase `.recording` |
| `timerText` | phase `.recording` → `TimerFormat.string(elapsed)`; else nil |
| `countdownText` | `countdown.map(String.init)` |
| `canLeave` | blocking `.preparing` → false (a configure is in flight; `endSession` refuses too); else blocking `.notAuthorized`/`.unavailable` → true; else phase is `.idle` or `.paused` |

`.finish` sends nothing to the store: the view calls `model.endSession()` (the reducer clamps
at the last question, so "Next" there would do nothing visible).

## 5. `UICopy` — `StoryCue/UICopy.swift`

Every user-visible string in S2a lives here as a `static let` (or a `static func` for the two
parameterised ones), so the S4 copy review and the S6 privacy-policy check have one file to
read. Exact text:

| Key | Text |
|---|---|
| `appTitle` | "StoryCue" |
| `deckPickerTitle` | "Choose a deck" |
| `questionCount(_ n: Int)` | "\(n) questions" |
| `consentTitle` | "Before you start" |
| `consentBody` | "Everyone on camera needs to agree to be recorded. When you start, have the person you're interviewing read this line aloud:" |
| `readAloudLine` | "I understand this is being recorded, and I am ready to begin." |
| `privacyNote` | "Recordings stay on this phone. Nothing is uploaded." |
| `consentConfirm` | "We're ready" |
| `questionCounter(_ i: Int, _ n: Int)` | "Question \(i + 1) of \(n)" |
| `record` / `pause` / `resume` / `saving` / `cancel` | "Record" / "Pause" / "Resume" / "Saving…" / "Cancel" |
| `skip` / `next` / `finish` / `done` | "Skip" / "Next question" / "Finish" / "Done" |
| `readAloudBanner` | "Start by reading the consent line aloud." |
| `noAudioBanner` | "No microphone. Video will record without sound." |
| `preparing` | "Starting the camera…" |
| `notAuthorizedTitle` / `notAuthorizedBody` | "Camera or microphone is off" / "Turn on Camera and Microphone for StoryCue in Settings to record." |
| `openSettings` | "Open Settings" (button → `UIApplication.openSettingsURLString`) |
| `unavailableTitle` / `unavailableBody` | "Camera unavailable" / "StoryCue can't use the camera right now. Close other camera apps and try again." |
| `pausedBanner(_ reason: SegmentEndReason) -> String` | see below |

`pausedBanner`: `.segmentCapReached` → "Ten minutes on this answer. Keep going?";
`.audioInterruption` → "Paused for a call or other audio."; `.captureInterruption` → "The camera
was interrupted."; `.sceneResignedActive`, `.sceneBackgrounded` → "Paused when StoryCue left the
screen."; `.thermalShutdown` → "Paused so the phone can cool down."; `.runtimeError`,
`.mediaServicesReset`, `.outputEndedUnexpectedly` → "Recording stopped unexpectedly. What was
recorded is kept."; `.directionChanged`, `.hingeClosed`, `.accessoryWithdrawn` (Duo reasons,
unreachable in 1.0 but part of the enum) → "Paused when the camera changed."; `.userPause`,
`.userStop` → "" (never shown). Switch exhaustively — no `default`, so a new reason is a compile
error here.

## 6. Tests — `StoryCueTests/`

`RecorderPresentationTests.swift` (build `SessionState` values directly; `Deck.v1Decks[0]`):

| Test | Asserts |
|---|---|
| `testBlockingMapsAvailability` | the four availability values → the four blocking values, and primary `.unavailable` for the three non-ready ones |
| `testPrimaryFollowsPhase` | idle/recording/finishing/paused → record/pause/saving/resume |
| `testCountdownOverridesPrimaryAndDisablesAdvance` | countdown 2 on idle → `.cancelCountdown`, `.disabled`, countdownText "2" |
| `testAdvanceSkipWithoutSegmentsNextWithSegments` | idle, no clip for the question → `.skip`; a clip with a segment for it → `.next` |
| `testAdvanceFinishOnLastQuestion` | last index, idle → `.finish`; last index, recording → `.next` or `.skip` per segments (not `.finish`) |
| `testAdvanceDisabledWhileFinishing` | `.finishing` → `.disabled`, `canLeave == false` |
| `testBannerPausedReasonExceptUserPause` | `.paused(.thermalShutdown)` → `.paused(.thermalShutdown)`; `.paused(.userPause)` → not a paused banner |
| `testBannerNoAudioBeatsReadAloud` | idle, first question, no clips, `hasAudioInput == false` → `.noAudio` |
| `testBannerReadAloudOnlyBeforeFirstClip` | idle, index 0, no clips → `.readAloud`; with a clip → `.none` |
| `testTimerOnlyWhileRecording` | recording, elapsed 65 → "1:05" and dot shown; paused → nil and no dot |
| `testCanLeaveRules` | idle/paused true; recording/finishing false; blocking `.unavailable` while recording → true; blocking `.preparing` → false |

`TimerFormatTests.swift`: `testFormatsCountUp` (the six examples in section 4),
`testNegativeClampsToZero`, `testFloorsFractions` (59.9 → "0:59").

`ScenePhaseMappingTests.swift`: `testActiveToInactiveResigns`, `testToBackgroundEntersBackground`
(from `.active` and from `.inactive`), `testToActiveBecomesActive` (from `.inactive` and
`.background`), `testOtherTransitionsNil` (`.inactive`→`.inactive`, `.background`→`.inactive`).

`UICopyTests.swift`: `testPausedBannerNonEmptyForEveryShownReason` (every `SegmentEndReason` except
`.userPause`/`.userStop` → non-empty; use a literal array of all 14 cases incl.
`.captureInterruption(.videoDeviceInUseByAnotherClient)`), `testReadAloudLineIsExact` (equals
the SYNTHESIS Q7 line byte for byte), `testNoCopyContainsTODO`.

`AppModelTests.swift` (`@MainActor`; factories return `MockCaptureService` /
`FakeBackgroundTaskRunner` and count their calls):

| Test | Asserts |
|---|---|
| `testInitConstructsNoCapture` | after `init`, the capture factory call count is 0 |
| `testBeginSessionPreparesCapture` | `beginSession` → `active` non-nil, mock `requestAuthorizationCount == 1`, store availability `.ready` |
| `testBeginSessionTwiceIsNoOp` | second call → factory count still 1 |
| `testEndSessionRefusedWhileRecording` | `store.send(.tapRecord)`, drain → `endSession()` false, `active` non-nil, `shutdownCount == 0` |
| `testEndSessionShutsDownCapture` | idle → true, `active == nil`, `shutdownCount == 1` |
| `testNewSessionGetsFreshCapture` | begin, end, begin → factory count 2, the second `active.capture` is not the first (`!==` via `ObjectIdentifier`) |
| `testEndSessionRefusedWhilePreparing` | a mock whose `requestAuthorization` suspends (add `setStubAuthorizationDelay(_ seconds: Double)` to the mock; it `Task.sleep`s before returning) → `endSession()` called during `beginSession` returns false; after `beginSession` returns, `endSession()` returns true |
| `testInfoPlistPortraitOnly` | `Bundle(for: AppModel.self).infoDictionary?["UISupportedInterfaceOrientations"]` as `[String]` equals `["UIInterfaceOrientationPortrait"]` |

(`testBeginSessionPreparesCapture` relies on S1 behavior as shipped: the mock's default
`stubAuthorization` is authorized for both, and `prepareCapture()` sets `captureAvailability`
before it returns.)

`MockCaptureServiceTests.swift`: add `testShutdownFinishesEvents` (after `shutdown()`, a
`for await` over `events` ends).

`AVCaptureServiceTests.swift`: add `testPreviewSourceAvailableBeforeConfigure` (the source is a
`SessionPreviewSource`; no configure call, no crash) and `testShutdownBeforeConfigureIsNoOp`
(twice; no throw, no crash).

## Kimi layout review (after the implement run, before Sol)

A separate `--implement` review in a throwaway worktree over the four views, against this
checklist only: Dynamic Type at the largest accessibility size doesn't clip the question or push
controls off screen (reason from the layout code — no simulator); controls ≥44 pt; question
contrast ≥7:1; nothing depends on a fixed screen height; back-swipe can't leave a live
recording. Findings, not edits.

## Do not

- No Duo code, no outer-display view, no `#if DUO_SDK` additions.
- No library, export, or orphan-recovery UI; no change to `SessionMachine` or `SegmentLedger`.
- No `@unchecked Sendable`, `nonisolated(unsafe)`, `try!`, `as!`, `Task.detached`.
- `SessionStore` still never imports AVFoundation/UIKit/SwiftUI.
- No string literal shown to the user outside `UICopy`.
- No AI attribution trailers.

## Done when

CI green (Build & Test + Release compile); all S1 tests still pass; the new tests (11 + 3 + 4 +
3 + 8 + 1 + 2 = 32) run and pass; and these greps are empty:
`grep -rn "ContentView" StoryCue/`,
`grep -rnE "try!|as!|Task\.detached|unchecked Sendable|nonisolated\(unsafe\)" StoryCue/ StoryCueTests/`,
`grep -rn "\.system(size:" StoryCue/`,
`grep -rnE "import (AVFoundation|UIKit|SwiftUI)" StoryCue/SessionStore.swift`.
Kimi layout review findings and Sol's audit are adjudicated by the boss; any edit they call for
is a boss follow-up commit, not a second executor run. Device verification — the preview shows,
the prompts appear in order, back-swipe can't leave a live recording, 44 pt targets at the
largest text size — is S5's checklist, not this step's.

If `@preconcurrency import AVFoundation` becomes necessary (section 1), note that it relaxes
Sendable checking for every AVFoundation type used in `CameraPreview.swift`, not just the one
struct — keep that file to the preview types only.
