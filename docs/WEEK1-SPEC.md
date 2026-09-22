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
enum DeckMode: String, Codable { case sequential, roundRobin }

struct Question: Identifiable, Codable, Equatable {
    let id: String          // "grandparents.001" etc — stable, referenced by tests
    let text: String         // v1: "// TODO copy" placeholder acceptable, see "Deck copy" below
    let isVHPSourced: Bool    // true only on the optional veterans deck (public-domain VHP text)
}

struct Deck: Identifiable, Codable, Equatable {
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
enum HingeStatus: Equatable { case closed, partiallyOpen, fullyOpen }   // nil elsewhere = no hinge

enum SegmentEndReason: Equatable {
    case userPause, userStop
    case hingeClosed, accessoryWithdrawn
    case audioInterruption, captureInterruption(CaptureInterruptionReason)
    case sceneResignedActive, sceneBackgrounded
    case thermalShutdown, runtimeError, mediaServicesReset, directionChanged
}

enum CaptureInterruptionReason: Equatable {
    case audioDeviceInUseByAnotherClient, videoDeviceInUseByAnotherClient
    case videoDeviceNotAvailableInBackground, videoDeviceNotAvailableDueToSystemPressure
}

enum SegmentOutcome: Equatable { case saved(url: URL), failed(kept: Bool) }

struct Segment: Equatable, Codable {
    let id: UUID
    let questionID: String
    let startedAt: Date
    var endReason: SegmentEndReason?
    var outcome: SegmentOutcome?
}

struct Clip: Equatable, Codable { let questionID: String; var segments: [Segment] }

// .paused covers BOTH a user tap and every involuntary interruption. Sol's rule is "any
// discontinuity finishes the segment; reopening is a new segment after a tap" — voluntary
// and involuntary collapse to the same state. The tap itself is the confirmation, for
// every reason; there is no separate needs-confirmation flag.
enum RecordingPhase: Equatable {
    case idle                                              // between questions, no clip started yet
    case recording(segmentID: UUID)
    case finishing(segmentID: UUID, reason: SegmentEndReason)
    case paused(reason: SegmentEndReason)
}

struct SessionState: Equatable {
    var deck: Deck
    var questionIndex: Int
    var phase: RecordingPhase
    var clips: [Clip]
    var hinge: HingeStatus?
}

enum SessionEvent: Equatable {
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

enum SessionEffect: Equatable {
    case startSegment(questionID: String)
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

**Rules the implementation must follow (state these, don't leave them to inference):**

- Every discontinuity event, from **any** `phase` except `.idle`, drives
  `.recording(id) → .finishing(id, reason) → .paused(reason)` and nothing else — no
  direct `.recording → .idle`, no silent `.recording → .recording`.
- `.finishing` only leaves on `fileOutputFinished`. Any other event that arrives while
  `.finishing` is ignored (see acceptance table: `testTapsIgnoredWhileFinishing`).
- `tapNextQuestion` / `tapSkip` while `.recording`: first synthesize the same
  finish-then-wait sequence (reason `.userStop`), then on `fileOutputFinished` advance
  `questionIndex` and set `phase` to `.idle` (not `.paused` — there is no in-progress clip
  to resume for the new question).
- `tapRecord` from `.idle` or `tapResume` from `.paused` both start a **new** `Segment`
  (fresh UUID) appended to the current question's `Clip`. Nothing ever appends to an
  already-finished segment.
- `SegmentOutcome.failed(kept: false)` segments are excluded from the export manifest;
  `.failed(kept: true)` are included but flagged. This is the concrete meaning of "the
  file is kept even when the callback reports an error" (PLAN §2).
- Export manifest is **not** a `SessionEvent`. Expose it as a pure function in
  `StoryCue/ExportManifest.swift`:
  ```swift
  struct ClipManifestEntry: Equatable { let questionID: String; let segments: [Segment] }
  func exportManifest(for state: SessionState) -> [ClipManifestEntry]
  ```
  so step 5 (actual Files/Photos export, out of scope here) has a typed input without the
  reducer knowing about Files/Photos.

### Concurrency — `CaptureService` / `MockCaptureService` / `AVCaptureService`

`project.yml` pins `SWIFT_VERSION: "6.0"` (strict concurrency). Pin the shape now or the
first CI run fails on Sendable errors instead of logic errors.

```swift
protocol CaptureService: Actor {
    func startSegment(for questionID: String) async throws -> UUID
    func stopSegment(_ segmentID: UUID) async
    var events: AsyncStream<CaptureServiceEvent> { get }
}

enum CaptureServiceEvent: Sendable, Equatable {
    case segmentFinished(segmentID: UUID, outcome: SegmentOutcome)
    case interruptionBegan(CaptureInterruptionReason), interruptionEnded
    case runtimeError, mediaServicesReset
}

enum CaptureServiceError: Error { case deviceUnavailable }
```

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
  `AVCaptureDevice.default(...)` returns nil. `configureSession()` throws
  `CaptureServiceError.deviceUnavailable` rather than force-unwrapping.
  **`StoryCueApp` must not construct or configure `AVCaptureService` eagerly at launch** —
  `StoryCueTests`' `TEST_HOST` launches the real app binary to host the test bundle, so an
  eager force-unwrap at launch would crash every unit test, not just camera tests, for a
  reason that looks unrelated to whatever test actually failed.
- **`StoryCue/MockCaptureService.swift`**, gated `#if DEBUG` (never ships in the
  Release/App Store build): implements the same protocol; `startSegment`/`stopSegment`
  record calls, and a test-only `func simulate(_ event: CaptureServiceEvent)` pushes into
  its own `events` stream. This is also what the later outer-preview UI test uses, since
  the simulator has no camera (Sol finding 3).
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
| `.recording` | `accessoryAvailabilityChanged(false)` | `.finishing(id, .accessoryWithdrawn)` | `.stopSegment` | `testAccessoryWithdrawnFinishesSegment` |
| `.recording` | `audioInterruptionBegan` | `.finishing(id, .audioInterruption)` | `.stopSegment` | `testAudioInterruptionFinishesSegment` |
| `.recording` | `captureInterruptionBegan(.videoDeviceInUseByAnotherClient)` | `.finishing(id, .captureInterruption(...))` | `.stopSegment` | `testCaptureInterruptionFinishesSegment` |
| `.recording` | `sceneWillResignActive` | unchanged (background task begins; segment keeps writing) | `.beginBackgroundTask` | `testResignActiveBeginsBackgroundTaskWithoutStopping` |
| `.recording` (backgrounded) | `sceneDidEnterBackground` | `.finishing(id, .sceneBackgrounded)` | `.stopSegment`, `.endBackgroundTask` | `testBackgroundEntryFinishesSegment` |
| `.recording` | `thermalPressureCritical` | `.finishing(id, .thermalShutdown)` | `.reduceFrameRate` then (on repeat/critical) `.stopSegment` | `testThermalCriticalFinishesSegment` |
| `.recording` | `runtimeError` | `.finishing(id, .runtimeError)` | `.stopSegment` | `testRuntimeErrorFinishesSegment` |
| `.recording` | `mediaServicesReset` | `.finishing(id, .mediaServicesReset)` | `.stopSegment`, `.recreateCaptureSession` | `testMediaServicesResetFinishesAndRecreates` |
| `.recording` | `directionChanged` | `.finishing(id, .directionChanged)` | `.stopSegment` | `testDirectionChangeFinishesSegment` |
| `.finishing` | `fileOutputFinished(.failed(kept: true))` | `.paused(reason)`, segment recorded with `.failed(kept:true)` | `.persistLedger` | `testFailedButKeptSegmentStillPersisted` |
| `.finishing` | `fileOutputFinished(.failed(kept: false))` | `.paused(reason)`, segment recorded but excluded from export manifest | — | `testDroppedSegmentExcludedFromManifest` |
| `.recording` | `tapNextQuestion` | finish-then-advance: ends at `.idle`, `questionIndex + 1` | `.stopSegment` | `testNextQuestionWhileRecordingFinishesFirst` |
| `.idle` | `tapSkip` | `.idle`, `questionIndex + 1`, no clip created | — | `testSkipFromIdleAdvancesWithNoClip` |
| `.finishing` | any tap event (`tapRecord`/`tapPause`/`tapResume`) | unchanged — ignored until `fileOutputFinished` | none | `testTapsIgnoredWhileFinishing` |
| n/a | `exportManifest(for:)` over a state with 2 saved + 1 dropped + 1 kept-but-failed segment | manifest has exactly the saved + kept-but-failed entries, in question order | — | `testExportManifestExcludesOnlyDroppedSegments` |

Plus, separately:

- **`StoryCueTests/SegmentLedgerTests.swift`** — `testOrphanedEntryDetectedAfterSimulatedCrash`
  (write a `.writing` entry, construct a fresh `SegmentLedger` pointed at the same
  directory, assert it's returned by `orphanedEntries()`); `testMarkFinishedRemovesFromOrphans`.
- **`StoryCueTests/DeckDataTests.swift`** — `testAllFiveV1DecksExist`,
  `testAllQuestionIDsUnique`, `testHolidayTableDeckUsesRoundRobinMode`,
  `testAllV1DecksAreIncluded`.
- **`StoryCueTests/MockCaptureServiceTests.swift`** — `testSimulatedEventsDeliveredInOrder`,
  `testStartStopSegmentCallsRecorded`.
- **`StoryCueTests/AVCaptureServiceTests.swift`** — `testConfigureSessionThrowsWhenDeviceUnavailable`
  (the one `AVCaptureService` test that can run on the simulator/CI host, since it tests
  the nil-safety path, not real capture).

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
- Don't let `MockCaptureService` leak into a Release build (`#if DEBUG`).
- No AI attribution trailers on any implementation commit.

## Routing

Steps above (`SessionMachine`, `CaptureService`/`MockCaptureService`/`AVCaptureService`,
`SegmentLedger`, deck data, `ExportManifest`, and all named tests) → `/orchestrate` (Kimi
executor; Sol audits the diff — the executor is never its own reviewer). Then **Kimi on
the state machine** (`docs/PLAN.md` §8 row 4, the paste-ready prompt) once `SessionMachine`
exists, and **Sol on the recorder diff** at the week-1 gate (`docs/PLAN.md` §9).
Dispatching to `/orchestrate` is a separate session from this spec-authoring pass.
