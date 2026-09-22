# Week 1 spec — `SessionMachine` / `CaptureService` / decks

_Written 2026-09-22. This is the spec-authoring pass `docs/HANDOFF-2026-09-22.md` scoped
out of the CI-fix session and `docs/HANDOFF-2026-09-21.md` Task 2 first described. It
exists so `/orchestrate` (Kimi executor, Sol audits the diff) can implement week 1
without inventing type shapes, concurrency model, or test coverage — this repo's own
lesson is that an under-specified brief lets Kimi's tests re-implement whatever logic the
brief doesn't pin down by name._

Inputs: `docs/PLAN.md` §1 (hinge row), §2 (loop, segment rule), §4 items 2 and 5, §9;
`docs/reviews/SOL-PLAN-REVIEW-2026-09-21.md` findings 2 and 3;
`docs/research/SYNTHESIS-2026-09.md` Q7; the existing scaffold (`project.yml`,
`StoryCue/DuoSupport.swift`, `StoryCueTests/`, `StoryCueDuoTests/`).

**Corrected pre-dispatch (2026-09-22):** `SegmentEndReason`, `CaptureInterruptionReason`,
`SegmentOutcome` are now `Codable` (were `Equatable`-only). `Segment` declares `Codable`
and stores `endReason`/`outcome` of these types — synthesis needs every stored property
Codable, so the original declarations would not compile.

## Scope

**In scope** (bulk implementation → `/orchestrate`, Kimi executor, Sol audits the diff):
`SessionMachine`, `CaptureService`/`MockCaptureService`/`AVCaptureService`,
`SegmentLedger`, deck data (`Deck`/`Question`/`Decks`), `ExportManifest`, and every test
file named below.

**Out of scope** (stays on Sonnet or a later `/orchestrate` pass — do not implement here):
inner UI (preview, timer, pause/resume/next/skip controls, consent card), the
outer-preview debug panel and its `simctl` screenshot UI test, session library screen,
actual export-to-Files/Photos, final deck copy. The `SessionStore` surface is named below
so step 1's types aren't reshaped when that work starts.

## Types

### `StoryCue/Deck.swift` — pure data

```swift
enum DeckMode: String, Codable, Sendable { case sequential, roundRobin }

struct Question: Identifiable, Codable, Equatable, Sendable {
    let id: String          // "grandparents.001" etc — stable, referenced by tests
    let text: String         // v1: "// TODO copy" placeholder acceptable, see "Deck copy" below
    let isVHPSourced: Bool    // true only on the optional veterans deck (public-domain VHP text)
}

struct Deck: Identifiable, Codable, Equatable, Sendable {
    let id: String            // "grandparents" | "parents" | "kids" | "couples" | "holiday-table"
    let title: String
    let mode: DeckMode          // .roundRobin only for "holiday-table"; .sequential otherwise
    let questions: [Question]
    let isIncluded: Bool         // true for all five v1 decks (SYNTHESIS Q7: free, all decks included)
}
```

`StoryCue/Decks.swift` defines `Deck.v1Decks: [Deck]` — the five decks from PLAN §2:
Grandparents, Parents, Kids ask the grownups, Couples, Holiday table (round-robin). 8–12
questions per deck, `// TODO copy` placeholder text (see "Deck copy" section).

### `StoryCue/SessionMachine.swift` — pure Swift, **no `import AVFoundation`**

This has zero platform dependency, which is what makes `MockCaptureService` and
`AVCaptureService` interchangeable underneath it and the reducer's tests un-fakeable.

```swift
enum HingeStatus: Equatable, Sendable { case closed, partiallyOpen, fullyOpen }
// HingeStatus itself has no "no hinge" case — that's `SessionState.hinge: HingeStatus?`
// being `nil` (non-Duo device, or accessory not attached), not a case of this enum.

enum SegmentEndReason: Equatable, Codable, Sendable {
    case userPause, userStop
    case hingeClosed, accessoryWithdrawn
    case audioInterruption, captureInterruption(CaptureInterruptionReason)
    case sceneResignedActive, sceneBackgrounded
    case thermalShutdown, runtimeError, mediaServicesReset, directionChanged
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
}

enum SessionEffect: Equatable, Sendable {
    case startSegment(segmentID: UUID, questionID: String)  // reducer generates the ID; see rules below
    case stopSegment(segmentID: UUID)           // real service: this only REQUESTS a stop; the
                                                  // transition to `.paused` waits for fileOutputFinished
    case beginBackgroundTask, endBackgroundTask
    case reduceFrameRate
    case recreateCaptureSession                  // mediaServicesReset only
    case persistLedger(Clip)
}

enum SessionMachine {
    static func reduce(_ state: SessionState, _ event: SessionEvent) -> (SessionState, [SessionEffect])
}
```

`DeckMode` does not affect `SessionMachine.reduce` in week 1 — `.roundRobin` vs.
`.sequential` question-ordering logic is `SessionStore` (step 4) territory. The reducer
only ever moves `questionIndex` forward by 1, clamped at the deck's last question — there
is no previous-question event or backward navigation in week 1, regardless of `mode`.

**Rules the implementation must follow (state these, don't leave them to inference):**

- **Default rule — read this first.** Any `(phase, event)` pair not covered by a more
  specific rule below returns `(state, [])` — phase and all other fields unchanged, no
  effects. This is the explicit fallback for events that don't apply to the current phase:
  `tapPause` while already `.paused`/`.idle`, `tapRecord` while already `.recording`,
  `tapResume` from `.idle`, `accessoryAvailabilityChanged(true)` (the accessory becoming
  available is not a discontinuity). Specific rules below override this default only where
  the transition is *not* a no-op.
- **The reducer is the sole segment-ID authority.** `SessionMachine` generates the fresh
  `UUID` when it transitions into `.recording(segmentID:)` and emits it via
  `.startSegment(segmentID:questionID:)`. `CaptureService.startSegment(id:for:)` takes that
  ID as an input, not a return value — the service correlates its own internal state
  (e.g., output file naming) to the reducer's `Segment.id`; it never mints a competing ID.
- **Discontinuities only apply from `.recording`.** Every discontinuity event, while
  `phase == .recording(id)`, drives `.recording(id) → .finishing(id, reason) →
  .paused(reason)` and nothing else — no direct `.recording → .idle`, no silent
  `.recording → .recording`. (Not "any phase except `.idle`" — that wording is imprecise;
  `.paused` and `.finishing` have their own rules below and the default rule covers
  everything else.)
- **`.finishing` has exactly two exits.** (1) `fileOutputFinished(segmentID: id, outcome:)`
  where `id` matches the currently-finishing segment's ID — the normal exit, records
  `outcome`/`endReason` on the segment and moves to `.paused(reason)`. (2) `runtimeError` —
  the escape hatch: if the real callback never arrives (lost delegate call, wedged
  session), treat it exactly like `fileOutputFinished(segmentID: id, outcome:
  .failed(kept: true))` — segment recorded with the *original* finishing `reason`
  (unchanged) and `outcome = .failed(kept: true)`, transition to `.paused(reason)`.
  `SessionStore` (step 4, out of scope) owns the wall-clock timeout policy that decides
  when to synthesize `runtimeError` into a wedged `.finishing`; the reducer only defines
  what happens when it arrives. Every other event while `.finishing` is ignored (default
  rule) — including a `fileOutputFinished` whose `segmentID` does **not** match (a
  stale/duplicate callback from an already-superseded segment) and including
  `tapNextQuestion`/`tapSkip` (an advance tap during finishing is silently swallowed;
  there is no deferred-retry queue in week 1).
- **`fileOutputFinished` outside `.finishing`, or with a non-matching ID, is always
  ignored** (default rule) — covers races like: recording finishes on question A,
  `tapNextQuestion` starts question B's segment before A's `fileOutputFinished` callback
  arrives, and the stale callback for A shows up while `phase` is already
  `.recording(B)`/`.idle`/`.paused`.
- **Informational events never resume a paused segment**, but `sceneDidBecomeActive` is
  *not* a pure no-op — see the background-task rules below. `audioInterruptionEnded` and
  `captureInterruptionEnded` are unconditional no-ops (default rule) in every phase.
  Resuming is always via the user's own `tapResume` (per the `.paused` doc comment above:
  the tap is the confirmation, for every reason) — an interruption clearing on its own
  never auto-resumes recording.
- `hingeChanged` only matters as a transition **into** `.closed`. From `.recording`,
  `hingeChanged(.closed)` finishes the segment (existing acceptance row). From any phase,
  `hingeChanged(.partiallyOpen)`, `hingeChanged(.fullyOpen)`, or `hingeChanged(nil)`
  (hinge/accessory removed) update `SessionState.hinge` only — no phase change, no effect.
- **Background-task pairing is tracked by `SessionState.backgroundTaskActive`, not by
  phase alone** (phase alone can't distinguish "task begun, then user tapped pause before
  backgrounding" from "no task was ever begun"):
  - `sceneWillResignActive`: if `phase == .recording` **and** `!backgroundTaskActive`,
    emit `.beginBackgroundTask` and set `backgroundTaskActive = true`. Otherwise (already
    active — a duplicate notification — or not recording) it's a no-op: at most one
    background task is ever active.
  - `sceneDidEnterBackground`: if `backgroundTaskActive`, emit `.endBackgroundTask`, clear
    the flag, **and** if `phase == .recording` also finish the segment (`.finishing(id,
    .sceneBackgrounded)` + `.stopSegment`) — the in-flight segment may have already been
    finished by something else (e.g. the user tapped pause between resigning and
    backgrounding) while the task was still active, in which case only
    `.endBackgroundTask` fires. If `!backgroundTaskActive`, no-op (default rule) — nothing
    to end, nothing to finish.
  - `sceneDidBecomeActive`: if `backgroundTaskActive`, emit `.endBackgroundTask` and clear
    the flag — this is the "resigned active, began a task, but returned to the foreground
    without ever fully backgrounding" path; the begun task must still be closed here or it
    leaks. If `!backgroundTaskActive`, no-op (default rule).
- `mediaServicesReset` emits `.recreateCaptureSession` **regardless of phase** — the
  capture session itself is broken independent of what the reducer's phase says — but only
  finishes a segment (existing `.recording` row) when one is in flight; from `.idle` or
  `.paused` it recreates the session with phase unchanged.
- `thermalPressureCritical` only applies from `.recording` (existing row) — from any other
  phase it is a no-op (default rule): nothing is being captured to throttle.
- **`tapNextQuestion` and `tapSkip` are reducer-equivalent** — identical phase transitions
  from every starting phase. (Any future product distinction between "skip without
  recording" and "finish and advance" is a UI-layer concern, out of scope this week.)
  - While `.recording`: first synthesize the finish-then-wait sequence (reason
    `.userStop`), then on `fileOutputFinished` advance `questionIndex` and set `phase` to
    `.idle` (not `.paused` — there is no in-progress clip to resume for the new question).
    The `.persistLedger` effect this emits carries the **old** question's `Clip` (the one
    whose segment just finished), built from `state` *after* the finished segment's
    `outcome`/`endReason` are recorded — never a pre-mutation snapshot.
  - While `.idle` or `.paused`: no clip is in flight, so this advances `questionIndex`
    immediately (no finish-then-wait) and phase is/stays `.idle`.
  - At the **last** `questionIndex` (deck exhausted), from any phase: clamp —
    `questionIndex` never advances past `deck.questions.count - 1`. From `.recording` this
    still finishes the in-flight segment first (per the `.recording` case above), then
    clamps instead of advancing. A session-complete phase is step-4/5 UI territory, out of
    scope here; week 1 only needs the reducer to never go out of bounds.
- `tapRecord` from `.idle` or `tapResume` from `.paused` both start a **new** `Segment`
  (fresh UUID, minted by the reducer per the ID-authority rule above) appended to the
  current question's `Clip`. Nothing ever appends to an already-finished segment.
- If `SessionStore`'s execution of a `.startSegment` effect throws
  (`CaptureServiceError.deviceUnavailable`), that is handled by feeding a `runtimeError`
  event back into `reduce` — the reducer itself defines no separate "start failed" event or
  case; the existing `runtimeError` case covers it.
- **`[SessionEffect]` order is significant** and must be preserved exactly as written in
  each row/rule above — `SessionStore` executes effects in array order (e.g. `.stopSegment`
  always before `.recreateCaptureSession` on `mediaServicesReset`; `.stopSegment` always
  before `.endBackgroundTask` on backgrounding).
- `SegmentOutcome.failed(kept: false)` segments are excluded from the export manifest;
  `.failed(kept: true)` are included but flagged. This is the concrete meaning of "the
  file is kept even when the callback reports an error" (PLAN §2). A segment whose
  `outcome` is still `nil` (recording/finishing never completed — e.g. the app was killed
  mid-question) is treated the same as `.failed(kept: false)`: excluded, not a crash and
  not silently included as if saved. A `Clip` left with zero non-excluded segments (every
  segment dropped or nil-outcome) produces **no** `ClipManifestEntry` at all — omitted
  entirely, not an entry with an empty `segments` array.
- Export manifest is **not** a `SessionEvent`. Expose it as a pure function in
  `StoryCue/ExportManifest.swift`:
  ```swift
  struct ClipManifestEntry: Equatable, Sendable { let questionID: String; let segments: [Segment] }
  func exportManifest(for state: SessionState) -> [ClipManifestEntry]
  ```
  so step 5 (actual Files/Photos export, out of scope here) has a typed input without the
  reducer knowing about Files/Photos. Entries are in `state.clips` array order — the order
  in which each question's *first* segment was started, not the order questions were
  merely visited (a question skipped without ever recording never creates a `Clip` at all).
- `Segment`/`Clip`/`SegmentOutcome`/`SegmentEndReason` are `Codable` for possible direct
  state snapshotting later — that is a separate concern from `SegmentLedger`'s own
  `SegmentLedgerEntry` (below), which tracks files-on-disk for crash recovery, not full
  reducer state. `SessionStore` (step 4, out of scope) is what will translate a
  `.persistLedger(Clip)` effect into `SegmentLedger.record`/`.markFinished` calls; the two
  types are not required to share a wire format this week.
- There is no separate acceptance test for Sendable/strict-concurrency compliance: under
  `SWIFT_VERSION: "6.0"`, a Sendable violation is a **compile error**, so the CI build
  itself (already the Week-0 gate) is the enforcement mechanism — no additional criterion
  needed beyond "the project builds."

### Concurrency — `CaptureService` / `MockCaptureService` / `AVCaptureService`

`project.yml` pins `SWIFT_VERSION: "6.0"` (strict concurrency). Pin the shape now or the
first CI run fails on Sendable errors instead of logic errors.

```swift
protocol CaptureService: Actor {
    func startSegment(id: UUID, for questionID: String) async throws
    func stopSegment(_ segmentID: UUID) async
    func configureSession() async throws        // device lookup + session setup; lazy, not eager
    var events: AsyncStream<CaptureServiceEvent> { get }
}

enum CaptureServiceEvent: Sendable, Equatable {
    case segmentFinished(segmentID: UUID, outcome: SegmentOutcome)
    case interruptionBegan(CaptureInterruptionReason), interruptionEnded
    case runtimeError, mediaServicesReset
}

enum CaptureServiceError: Error, Sendable { case deviceUnavailable }
```

`CaptureServiceEvent.segmentFinished`'s `segmentID` is always the same ID `SessionStore`
passed into `startSegment(id:for:)` — the service echoes it back, never generates its own.
`SessionStore` maps this event to `SessionEvent.fileOutputFinished(segmentID:outcome:)`
1:1.

- **`StoryCue/AVCaptureService.swift`** — `actor AVCaptureService: CaptureService`. Wires
  `AVCaptureMovieFileOutput`'s finish delegate, `AVAudioSession.interruptionNotification`,
  `AVCaptureSession.wasInterruptedNotification` / `runtimeErrorNotification`,
  `AVError.mediaServicesWereReset`, and KVO on `systemPressureState`, per Sol's event
  table (`docs/reviews/SOL-PLAN-REVIEW-2026-09-21.md` finding 2). **Must not** wire
  `AVCaptureDeviceDirectionCoordinator` or any hinge-related API — that is week 2, lives
  under `#if DUO_SDK`, and belongs only in `StoryCueDuoTests`. Direction-coordinator
  wiring inside this week's `AVCaptureService` is a **spec violation**, not an omission to
  fix later — it would break the flag-scoping invariant `DuoGateTests`/`DuoSupportTests`
  already protect.
- **Nil-safety at init is a named requirement.** On the simulator/CI host,
  `AVCaptureDevice.default(...)` returns nil. `configureSession()` (now on the
  `CaptureService` protocol) throws `CaptureServiceError.deviceUnavailable` rather than
  force-unwrapping. `startSegment(id:for:)` calls `configureSession()` internally on first
  use if the session isn't configured yet — configuration is lazy, never at init.
  **`StoryCueApp` must not construct or configure `AVCaptureService` eagerly at launch** —
  `StoryCueTests`' `TEST_HOST` launches the real app binary to host the test bundle, so an
  eager force-unwrap at launch would crash every unit test, not just camera tests, for a
  reason that looks unrelated to whatever test actually failed.
- **Concurrency guidance (not a literal API pin):** `AVCaptureMovieFileOutput`'s delegate
  callbacks, `NotificationCenter` observers (`AVAudioSession.interruptionNotification`,
  `AVCaptureSession.wasInterruptedNotification`/`runtimeErrorNotification`), and KVO on
  `systemPressureState` all arrive off the actor. Hop back in with
  `Task { await self.handle(...) }` or by consuming `NotificationCenter.default
  .notifications(named:)` (an `AsyncSequence`) from inside the actor — don't capture `self`
  in a non-Sendable closure passed to `addObserver`/KVO. Sol's diff audit should flag
  `@unchecked Sendable` or `nonisolated(unsafe)` as a sign this was worked around instead
  of solved.
- **`StoryCue/MockCaptureService.swift`**, gated `#if DEBUG` (never ships in the
  Release/App Store build): implements the same protocol; `startSegment`/`stopSegment`
  record calls, and a test-only `func simulate(_ event: CaptureServiceEvent)` pushes into
  its own `events` stream. This is also what the later outer-preview UI test uses, since
  the simulator has no camera (Sol finding 3). Its `events` stream is
  `AsyncStream<CaptureServiceEvent>(bufferingPolicy: .unbounded)` with the continuation
  created in `init` (not lazily on first access to `events`), so `simulate()` calls made
  before a subscriber starts iterating are buffered, never dropped —
  `testSimulatedEventsDeliveredInOrder` depends on this.
- **`StoryCue/SegmentLedger.swift`** — `actor SegmentLedger`, Codable JSON under an
  injected directory (production default: Application Support; tests pass a temp
  directory):
  ```swift
  enum LedgerStatus: String, Codable { case writing, finished, orphaned }
  struct SegmentLedgerEntry: Codable, Equatable {
      let segmentID: UUID; let questionID: String; let fileURL: URL
      let startedAt: Date; var status: LedgerStatus
  }
  actor SegmentLedger {
      init(directory: URL)
      func record(_ entry: SegmentLedgerEntry) async throws
      func markFinished(_ segmentID: UUID) async throws
      func orphanedEntries() async throws -> [SegmentLedgerEntry]  // still .writing at load = crash recovery
  }
  ```
  `init(directory:)` takes an explicit directory always — it has no default parameter.
  "Production default: Application Support" describes the call site's convention (the
  not-yet-built `SessionStore`, step 4, resolves that URL itself and passes it in); it is
  not something this initializer supplies.

  Week 1 never writes `.orphaned` as a status value; that case is reserved for a future
  explicit cleanup pass. `orphanedEntries()`'s name describes the crash-recovery *concept*
  (these entries were orphaned by a crash), not the `.orphaned` status — it queries for
  entries still `.writing` (never reached `.finished` via `markFinished`). This is
  intentional, not a naming bug.

  **Writes must be atomic.** `record`/`markFinished` write via a temp file in the same
  directory followed by a rename/replace — never an in-place overwrite. A crash mid-write
  must never leave a corrupt or partially-written ledger file; that would defeat the
  entire crash-recovery purpose this type exists for.

### Step-4 surface — named now, not built this pass

`SessionStore` (`@Observable`, not implemented in this spec's scope): owns one
`SessionState`, subscribes to `CaptureService.events`, maps
`CaptureServiceEvent → SessionEvent`, calls `SessionMachine.reduce`, executes the
returned `[SessionEffect]` against its `CaptureService`. Exposes `currentQuestion`,
`nextQuestionPreview: Question?`, `elapsedInSegment: TimeInterval`, `canResume: Bool` for
the inner/outer UI to bind to when that work starts.

## Acceptance table — the literal test list

All in `StoryCueTests/SessionMachineTests.swift` (baseline target — **not**
`StoryCueDuoTests`; nothing here is behind `DUO_SDK`, including `directionChanged`, which
is a platform-agnostic event even though only a Duo build ever sends it):

| Starting phase | Event | Expected phase | Expected effect(s) | Test method |
|---|---|---|---|---|
| `.idle` | `tapRecord` | `.recording(new)` | `.startSegment` | `testTapRecordFromIdleStartsSegment` |
| `.recording` | `tapPause` | `.finishing(id, .userPause)` | `.stopSegment` | `testTapPauseRequestsFinish` |
| `.finishing(.userPause)` | `fileOutputFinished(.saved)` | `.paused(.userPause)` | `.persistLedger` | `testUserPauseFinishSavesAndPauses` |
| `.paused` (any reason) | `tapResume` | `.recording(new)`, new segment appended to same clip | `.startSegment` | `testResumeStartsFreshSegmentOnSameClip` |
| `.recording` | `hingeChanged(.closed)` | `.finishing(id, .hingeClosed)` | `.stopSegment` | `testHingeCloseFinishesSegment` |
| `.recording` | `hingeChanged(.partiallyOpen)` (or `.fullyOpen`/`nil`) | unchanged phase | none — `state.hinge` updated only | `testHingeChangeOtherThanClosedDoesNotFinishSegment` |
| `.recording` | `accessoryAvailabilityChanged(false)` | `.finishing(id, .accessoryWithdrawn)` | `.stopSegment` | `testAccessoryWithdrawnFinishesSegment` |
| `.recording` | `audioInterruptionBegan` | `.finishing(id, .audioInterruption)` | `.stopSegment` | `testAudioInterruptionFinishesSegment` |
| `.recording` | `captureInterruptionBegan(.videoDeviceInUseByAnotherClient)` | `.finishing(id, .captureInterruption(...))` | `.stopSegment` | `testCaptureInterruptionFinishesSegment` |
| `.recording`, `!backgroundTaskActive` | `sceneWillResignActive` | unchanged phase; `backgroundTaskActive = true` | `.beginBackgroundTask` | `testResignActiveBeginsBackgroundTaskWithoutStopping` |
| `.paused`/`.idle`/`.finishing`, or `.recording` with `backgroundTaskActive` already true | `sceneWillResignActive` | unchanged | none | `testResignActiveNoOpWhenNotRecordingOrAlreadyTracked` |
| `.recording`, `backgroundTaskActive` | `sceneDidEnterBackground` | `.finishing(id, .sceneBackgrounded)`; `backgroundTaskActive = false` | `.stopSegment`, `.endBackgroundTask` | `testBackgroundEntryFinishesSegment` |
| `!backgroundTaskActive` (any phase) | `sceneDidEnterBackground` | unchanged | none | `testBackgroundEntryNoOpWhenNoActiveTask` |
| `backgroundTaskActive` (any phase, task begun but never entered background) | `sceneDidBecomeActive` | unchanged phase; `backgroundTaskActive = false` | `.endBackgroundTask` | `testBecomeActiveEndsUnclosedBackgroundTask` |
| `.recording` | `thermalPressureCritical` | `.finishing(id, .thermalShutdown)` | `[.reduceFrameRate, .stopSegment]` (both, in that order, on the one event — see note below) | `testThermalCriticalFinishesSegment` |
| `.recording` | `runtimeError` | `.finishing(id, .runtimeError)` | `.stopSegment` | `testRuntimeErrorFinishesSegment` |
| `.finishing(id, reason)` (any reason) | `runtimeError` | `.paused(reason)`, segment recorded with **original** `reason` and `outcome = .failed(kept: true)` | `.persistLedger` | `testRuntimeErrorEscapesWedgedFinishing` |
| `.recording` | `mediaServicesReset` | `.finishing(id, .mediaServicesReset)` | `.stopSegment`, `.recreateCaptureSession` | `testMediaServicesResetFinishesAndRecreates` |
| `.idle` / `.paused` | `mediaServicesReset` | unchanged phase | `.recreateCaptureSession` | `testMediaServicesResetRecreatesSessionEvenWhenIdle` |
| `.recording(new)` (after an older segment was superseded) | `fileOutputFinished(segmentID: staleID, ...)` where `staleID` ≠ current segment | unchanged | none | `testStaleFileOutputFinishedIgnored` |
| `.recording` | `directionChanged` | `.finishing(id, .directionChanged)` | `.stopSegment` | `testDirectionChangeFinishesSegment` |
| `.finishing` | `fileOutputFinished(.failed(kept: true))` | `.paused(reason)`, segment recorded with `.failed(kept:true)` | `.persistLedger` | `testFailedButKeptSegmentStillPersisted` |
| `.finishing` | `fileOutputFinished(.failed(kept: false))` | `.paused(reason)`, segment recorded but excluded from export manifest | — | `testDroppedSegmentExcludedFromManifest` |
| `.recording` | `tapNextQuestion` | finish-then-advance: ends at `.idle`, `questionIndex + 1` | `.stopSegment` | `testNextQuestionWhileRecordingFinishesFirst` |
| `.recording` (at last `questionIndex`) | `tapNextQuestion` | finish-then-clamp: ends at `.idle`, `questionIndex` unchanged | `.stopSegment` | `testNextQuestionAtLastQuestionFinishesThenClamps` |
| `.paused` | `tapNextQuestion` / `tapSkip` | `.idle`, `questionIndex + 1` immediately (no clip in flight to finish) | none | `testAdvanceFromPausedHasNoFinishStep` |
| `.idle` | `tapSkip` | `.idle`, `questionIndex + 1`, no clip created | — | `testSkipFromIdleAdvancesWithNoClip` |
| `.idle` (at last `questionIndex`) | `tapSkip` | `.idle`, `questionIndex` unchanged (clamped) | none | `testAdvanceAtLastQuestionClamps` |
| `.finishing` | any tap event (`tapRecord`/`tapPause`/`tapResume`/`tapNextQuestion`/`tapSkip`) | unchanged — ignored until `fileOutputFinished`/`runtimeError` | none | `testTapsIgnoredWhileFinishing` |
| any phase, `!backgroundTaskActive` | `audioInterruptionEnded` / `captureInterruptionEnded` / `sceneDidBecomeActive` | unchanged | none | `testInformationalEventsAreNoOps` |
| n/a | `exportManifest(for:)` over a state with 2 saved + 1 dropped + 1 kept-but-failed + 1 nil-outcome segment | manifest has exactly the saved + kept-but-failed entries, in question order (nil-outcome excluded same as dropped) | — | `testExportManifestExcludesOnlyDroppedSegments` |

**Thermal note:** `AVCaptureSession.systemPressureState` has multiple levels (nominal,
fair, serious, critical, shutdown); week 1 does not model intermediate levels as separate
`SessionEvent`s. `AVCaptureService`'s KVO observer maps only the critical/shutdown levels
to a single `thermalPressureCritical` event; everything below that is not surfaced. The
reducer's response to that one event is both effects together (`reduceFrameRate` then
`stopSegment`), not a two-stage "warn, then on a second event stop" sequence — there is no
second thermal event to wait for in this model.

Plus, separately:

- **`StoryCueTests/SegmentLedgerTests.swift`** — `testOrphanedEntryDetectedAfterSimulatedCrash`
  (write a `.writing` entry, construct a fresh `SegmentLedger` pointed at the same
  directory, assert it's returned by `orphanedEntries()`); `testMarkFinishedRemovesFromOrphans`.
- **`StoryCueTests/DeckDataTests.swift`** — `testAllFiveV1DecksExist`,
  `testAllQuestionIDsUnique`, `testHolidayTableDeckUsesRoundRobinMode`,
  `testAllV1DecksAreIncluded`, `testEachV1DeckHasBetweenEightAndTwelveQuestions`,
  `testNoV1QuestionsAreVHPSourced` (no veterans deck ships in v1 — `isVHPSourced` exists
  now to avoid a schema migration when PLAN's optional veterans/VHP deck lands later, but
  every v1 question must be `false`).
- **`StoryCueTests/MockCaptureServiceTests.swift`** — `testSimulatedEventsDeliveredInOrder`,
  `testStartStopSegmentCallsRecorded`.
- **`StoryCueTests/AVCaptureServiceTests.swift`** — `testConfigureSessionThrowsWhenDeviceUnavailable`
  (the one `AVCaptureService` test that can run on the simulator/CI host, since it tests
  the nil-safety path, not real capture). Today's runner has no camera, so this asserts
  `CaptureServiceError.deviceUnavailable` is thrown; if a future runner image changes that,
  treat it as an infra change to this test, not a `SessionMachine`/`CaptureService` logic
  regression.

## Deck copy — a scope decision, not mechanical

PLAN §2: "copy is the product... gets a research pass and a Kimi readability pass."
Handing question-writing to a bulk-implementation executor produces generic filler. This
spec fixes 5 decks, their `id`/`mode`, and a target of 8–12 questions per deck, but ships
`// TODO copy` placeholder `Question.text` values for `/orchestrate` to implement
against. Actual copy is a separate, later Routine-tier pass (`glm-4-flash` /
`gemini-2.5-flash` per PLAN §8, then a Kimi readability pass) — not this spec and not
`/orchestrate`'s bulk-implementation dispatch. `DeckDataTests` checks shape (counts,
unique ids, mode), not copy quality.

## Do not

- No Duo-path code in `AVCaptureService` or anywhere outside `#if DUO_SDK` /
  `StoryCueDuoTests` — direction coordinator, hinge reads at the AVFoundation layer, and
  reserved-region layout are week 2.
- No inner/outer UI, no export-to-Files/Photos implementation, no final deck copy — named
  above as step-4/5/later work, out of scope for this dispatch.
- Don't let `MockCaptureService` leak into a Release build (`#if DEBUG` around the whole
  file). Note this protects the *file*, not callers — a later step-4 caller that
  references it from non-`#if DEBUG` code would still break the Release build at that
  point; not this week's problem, but don't design around evading it.
- No AI attribution trailers on any implementation commit.

## Notes for later, not this week

- **Week 2 seam:** `HingeStatus`/`hingeChanged` are defined in the baseline
  `SessionMachine.swift`, but their only real source is Duo hardware (week 2,
  `#if DUO_SDK`). When `SessionStore` wires an actual hinge signal, it must do so through
  conditional compilation on the *caller* side (translating a Duo-only signal into the
  already-platform-agnostic `hingeChanged` event) — `SessionEvent` itself should not need
  to change shape for that.
- **Audit checklist item (Sol, diff review):** confirm `MockCaptureService.swift`'s
  contents are wrapped in `#if DEBUG`/`#endif` (not just individual members) and that no
  implementation commit carries an AI attribution trailer — neither is mechanically
  testable, both are a visual check on the diff.

## Routing

Steps above (`SessionMachine`, `CaptureService`/`MockCaptureService`/`AVCaptureService`,
`SegmentLedger`, deck data, `ExportManifest`, and all named tests) → `/orchestrate` (Kimi
executor; Sol audits the diff — the executor is never its own reviewer). Then **Kimi on
the state machine** (`docs/PLAN.md` §8 row 4, the paste-ready prompt) once `SessionMachine`
exists, and **Sol on the recorder diff** at the week-1 gate (`docs/PLAN.md` §9).
Dispatching to `/orchestrate` is a separate session from this spec-authoring pass.
