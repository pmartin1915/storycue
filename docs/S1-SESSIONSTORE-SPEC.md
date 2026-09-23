# S1 spec — `SessionStore` + capture-service hardening

_Written 2026-09-22 (strategy session). Step S1 of `docs/STRATEGY-2026-09-22.md`. Same
contract as `docs/WEEK1-SPEC.md`: every type, method and test name is fixed here so
`/orchestrate` (Kimi executor, Sol audits the diff) doesn't invent shapes. Inputs:
`docs/WEEK1-SPEC.md` "Step-4 surface" and "Concurrency"; `ai/IDEAS.md` 2026-09-22 entries
(advisor `.writing` gap, Sol findings 2 and 6); `docs/reviews/STRATEGY-REVIEW-2026-09-22.md`
Kimi findings 2, 7, 8, 9, 12._

## Scope

**In:** `SessionStore`; `BackgroundTaskRunner`; additions to `CaptureService` /
`AVCaptureService` / `MockCaptureService` (authorization, frame-rate reduction, session
recreation, audio-input fact, segment directory); one new reducer event + end reason
(segment cap); `SegmentFiles` (the one place segment URLs are made); orphan recovery at
launch; the tests named below.

**Out (S2a/S2b/S3):** every SwiftUI view, the preview layer, scene-phase → event mapping in
the view layer, export/stitching, deck copy, Duo code. `StoryCueApp.swift` is **not
touched** in S1 — the store is exercised only by tests this step.

## 1. Where segment files live — moved out of Caches

`AVCaptureService.makeSegmentFileURL` writes to `Caches/segments/`. **iOS purges Caches under
storage pressure**, so a user's recording could vanish silently — the opposite of this app's
promise. New home: `Application Support/Segments/`. `SegmentFiles.url(for:in:)` never creates
directories; `AVCaptureService.startSegment` creates the injected directory
(`createDirectory(withIntermediateDirectories: true)`) if missing. Files are left
eligible for the user's own device backup (not `isExcludedFromBackup`); the privacy policy
(S6) says so.

```swift
// StoryCue/SegmentFiles.swift — pure Foundation
enum SegmentFiles {
    /// Production directory: <Application Support>/Segments. Created if missing.
    static func defaultDirectory() throws -> URL
    /// "<id.uuidString>.mov" inside `directory`. The ONLY constructor of segment URLs.
    static func url(for id: UUID, in directory: URL) -> URL
    /// Inverse of url(for:in:): nil for any filename that isn't "<UUID>.mov".
    static func segmentID(from url: URL) -> UUID?
}
```

`AVCaptureService.init(segmentDirectory: URL)` takes the directory (no default parameter);
`handleRecordingFinished` uses `SegmentFiles.segmentID(from:)`. `SessionStore` computes the
same URL for the ledger with `SegmentFiles.url(for:in:)` — one directory, injected into both,
so the ledger's `fileURL` and the file actually written can't disagree.

## 2. `CaptureService` additions

```swift
enum AuthState: Equatable, Sendable { case notDetermined, authorized, denied, restricted }
struct CaptureAuthorization: Equatable, Sendable { var camera: AuthState; var microphone: AuthState }

protocol CaptureService: Actor {
    // existing, unchanged:
    func startSegment(id: UUID, for questionID: String) async throws
    func stopSegment(_ segmentID: UUID) async
    func configureSession() async throws
    var events: AsyncStream<CaptureServiceEvent> { get }
    // new:
    func authorization() async -> CaptureAuthorization
    func requestAuthorization() async -> CaptureAuthorization   // camera first, then microphone; never re-prompts a determined state
    var hasAudioInput: Bool { get async }                        // false until configured, or when the mic input couldn't be added
    func reduceFrameRate() async                                 // best effort; never throws
    func recreateSession() async throws                          // tear down, then configureSession()
}
```

`AVCaptureService`:
- `authorization()` maps `AVCaptureDevice.authorizationStatus(for: .video/.audio)`;
  `requestAuthorization()` uses `AVCaptureDevice.requestAccess(for:)` only for
  `.notDetermined` media types.
- `configureSession()` throws `CaptureServiceError.notAuthorized` (new case) if camera auth is
  not `.authorized`, **before** any device lookup — so the S2a UI can tell "denied" from "no
  camera". On the simulator camera auth is not `.authorized`, so the existing test will now see
  `.notAuthorized`: **update `testConfigureSessionThrowsWhenDeviceUnavailable`** — rename it
  `testConfigureSessionThrowsWithoutUsableCamera`, accept either `.deviceUnavailable` or
  `.notAuthorized`, and construct the service with a temp directory:
  `AVCaptureService(segmentDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))`.
  No other existing test changes.
- Microphone stays best-effort, but the fact is now exposed as `hasAudioInput` (Kimi 3 — the UI
  must show a "no audio" state instead of silently recording video-only).
- **Audio session:** delete the manual `try? AVAudioSession.sharedInstance().setCategory(...)`.
  `AVCaptureSession.automaticallyConfiguresApplicationAudioSession` defaults to `true` and owns
  category + activation for capture; setting the category by hand beside it is the
  half-configuration Kimi 8 flagged. Leave the automatic default explicit in code with a comment.
- `reduceFrameRate()`: lock the active video device and set
  `activeVideoMinFrameDuration`/`activeVideoMaxFrameDuration` to 1/24 s if the active format
  supports it; swallow errors.
- `recreateSession()`: stop and release `captureSession`, `movieFileOutput`,
  `recordingDelegate`, `pressureObservation`; set `configured = false`; then
  `try await configureSession()`. (IDEAS: Sol finding 2.)
- **Notification tasks (IDEAS: Sol finding 6):** store the four `Task` handles; each loop
  captures `[weak self]` and exits when `self` is gone; the two `AVCaptureSession`
  notification streams are started in `configureSession()` with `object:` set to *that*
  session and cancelled by `recreateSession()`. The `AVAudioSession` interruption stream stays
  app-wide (started in `init`). No `@unchecked Sendable`, no `nonisolated(unsafe)`.
- `CaptureServiceError` gains `notAuthorized`.
- `SegmentLedgerEntry` and `LedgerStatus` gain `Sendable` (all members already are). Required:
  `RecoveredSegment` is `Sendable` and `orphanedEntries()` returns entries across an actor
  boundary.

`MockCaptureService` (still whole-file `#if DEBUG`): settable `stubAuthorization`,
`stubHasAudioInput` (default `true`), `stubStartError: CaptureServiceError?`,
`stubRecreateError: CaptureServiceError?`; records `requestAuthorizationCount`,
`reduceFrameRateCount`, `recreateCount`. `requestAuthorization()` turns each
`.notDetermined` in the stub into `.authorized` and returns it.

## 3. Segment cap (PLAN §2 "10-minute segment cap")

- `SegmentEndReason` gains `.segmentCapReached`; `SessionEvent` gains `.segmentCapReached`.
- Reducer: from `.recording(id)` → `.finishing(id, .segmentCapReached)` + `[.stopSegment(id)]`;
  every other phase: no-op. The finish lands in `.paused(.segmentCapReached)` via the existing
  `finish` path — **no auto-resume**; PLAN §2: nothing resumes recording without a tap.
- The store, not the reducer, owns time: see `tick(now:)` below.
- **Background-task expiry:** `SessionEvent` gains `.backgroundTaskExpired`. Reducer: if
  `!state.backgroundTaskActive` → no-op; else `backgroundTaskActive = false`, phase unchanged, no
  effects. Without it an expired task leaves the flag stuck `true`, blocking the next
  `sceneWillResignActive` and producing a spurious `.endBackgroundTask` later.

## 3b. Early file-output completion (data-loss race — `ai/IDEAS.md` 2026-09-22, Sol strategy review 3)

AVFoundation does not guarantee the finish delegate arrives *after* the interruption /
runtime-error notification that caused it. Today a matching `fileOutputFinished` while still
`.recording` is ignored (the guard accepts only `.finishing`), and the later notification then
moves to `.finishing` waiting for a callback that already came — wedged, and the segment's
outcome is never recorded.

- `SegmentEndReason` gains `.outputEndedUnexpectedly`.
- Reducer: `.fileOutputFinished(segmentID: id, outcome)` while `.recording(id)` with the **same**
  id → run the existing `finish` path with reason `.outputEndedUnexpectedly` → `.paused(.outputEndedUnexpectedly)`,
  `.persistLedger(clip)`, and `.endBackgroundTask` if one is active. A **different** id while
  `.recording` stays ignored (`testStaleFileOutputFinishedIgnored` unchanged).
- The late notification then arrives in `.paused` and is already a no-op under the existing
  guards — no buffering needed. No auto-resume.

## 4. `BackgroundTaskRunner`

```swift
@MainActor protocol BackgroundTaskRunner: AnyObject {
    func begin(expiration: @escaping @Sendable () -> Void)   // @Sendable, not @MainActor: UIKit's expirationHandler is an unisolated () -> Void
    func end()
}
```
Production `UIKitBackgroundTaskRunner` wraps `UIApplication.shared.beginBackgroundTask(withName:expirationHandler:)`
/ `endBackgroundTask`, holding at most one identifier; `end()` with none held is a no-op.
Test double `FakeBackgroundTaskRunner` (in the test target) records `beginCount`, `endCount`, an
ordered `callLog: [String]` of `"begin"`/`"end"`, and exposes `fireExpiration()`.

## 5. `SessionStore`

```swift
// StoryCue/SessionStore.swift
import Foundation
import Observation

enum CaptureAvailability: Equatable, Sendable { case unknown, ready, notAuthorized, unavailable }

struct RecoveredSegment: Equatable, Sendable {
    let entry: SegmentLedgerEntry
    let fileExists: Bool
}

@MainActor @Observable
final class SessionStore {
    private(set) var state: SessionState
    private(set) var captureAvailability: CaptureAvailability = .unknown
    private(set) var authorization: CaptureAuthorization?
    private(set) var hasAudioInput = true
    private(set) var recoveredSegments: [RecoveredSegment] = []
    private(set) var now: Date

    var currentQuestion: Question { get }            // state.deck.questions[state.questionIndex]
    var nextQuestionPreview: Question? { get }       // nil at the last question
    var elapsedInSegment: TimeInterval { get }       // 0 unless .recording; now - current segment's startedAt
    var canResume: Bool { get }                      // phase is .paused

    static let segmentCap: TimeInterval = 600
    private var capNotifiedSegmentIDs: Set<UUID> = []   // one .segmentCapReached per segment id

    init(deck: Deck,
         capture: any CaptureService,
         ledger: SegmentLedger,
         segmentDirectory: URL,
         background: any BackgroundTaskRunner,
         now: Date = Date())

    func start()                                     // begins consuming capture.events ONLY (no ticker); idempotent
    func startTicker()                               // 1 Hz wall-clock tick(now: Date()); S2a's view calls it; tests never do
    func stop()                                      // cancels the event pump and the ticker
    func send(_ event: SessionEvent)                 // reduce + enqueue effects
    func tick(now: Date)                             // updates `now`; sends .segmentCapReached once when elapsed >= cap
    func prepareCapture() async                      // auth check/request, configureSession, sets captureAvailability + hasAudioInput
    func recoverOrphans() async                      // launch-time crash recovery (section 6)
    func waitForIdleEffects() async                  // test hook: resumes when the effect queue is drained
}
```

Rules:

1. **Effects run strictly in order, FIFO across calls.** `send` reduces synchronously on the
   main actor (so `state` is never stale), then appends the effects to a single serial queue;
   one consumer `Task` executes them one at a time with `await`. The consumer `Task`, the event
   pump and the ticker are plain `Task {}` created inside the `@MainActor` class, so they inherit
   the main actor — **never `Task.detached`**; every `capture`/`ledger` call inside is `await`ed. Two back-to-back `send`s can
   never interleave their effects. (WEEK1-SPEC: "`[SessionEffect]` order is significant".)
2. Event pump: `start()` iterates `capture.events`, maps 1:1 per WEEK1-SPEC
   (`segmentFinished → fileOutputFinished`), and calls `send`.
3. Effect execution:
   - `.startSegment(id, q)`: **first** `ledger.record(SegmentLedgerEntry(segmentID: id,
     questionID: q, fileURL: SegmentFiles.url(for: id, in: segmentDirectory), startedAt: <look the
     segment up by id in state.clips; it is always present, fall back to now if not>, status: .writing))`, **then**
     `capture.startSegment(id:for:)`. Closes the IDEAS advisor gap: a crash mid-recording now
     leaves a `.writing` entry to find. If `startSegment` throws: `send(.runtimeError)`, and if
     the error is `.notAuthorized` also set `captureAvailability = .notAuthorized`. If
     `ledger.record` throws, still start the capture (losing crash-recovery for one segment
     beats losing the recording) and keep going.
   - `.stopSegment(id)`: `await capture.stopSegment(id)`.
   - `.beginBackgroundTask`: `background.begin(expiration:)`; the expiration closure hops to the
     main actor (`Task { @MainActor in ... }`, capturing the store weakly), calls
     `background.end()` (the system requires it), then `send(.backgroundTaskExpired)`.
   - `.endBackgroundTask`: `background.end()`.
   - `.reduceFrameRate`: `await capture.reduceFrameRate()`.
   - `.recreateCaptureSession`: `try await capture.recreateSession()`; on success
     `captureAvailability = .ready`; on throw: `CaptureServiceError.notAuthorized` → `.notAuthorized`, anything else → `.unavailable`. Never sends
     an event (phase may not be `.recording`).
   - `.persistLedger(clip)`: for each segment in `clip` whose `outcome != nil`,
     `try? await ledger.markFinished(segment.id)`. (`markFinished` is idempotent already.)
4. `elapsedInSegment` = `now.timeIntervalSince(segment.startedAt)` for the `.recording` segment
   (the reducer stamps `startedAt` with the wall clock; tests derive synthetic `now` values from the
   recorded segment's actual `startedAt`). `tick(now:)`: sets `now`; if phase is `.recording(id)` and `elapsedInSegment >= segmentCap`
   and `id` is not in `capNotifiedSegmentIDs` (insert it), `send(.segmentCapReached)`. Production calls it from the
   1 Hz ticker started by `startTicker()` — deliberately separate from `start()`, because tests
   need the event pump but a running wall-clock ticker would overwrite their synthetic `now`
   between `tick(now:)` and the assertion (flaky on a 10×-billed CI). Tests call `start()` and
   `tick(now:)` directly, never `startTicker()`.
5. `prepareCapture()` (safe to call repeatedly; the real service never re-prompts a determined
   state): `authorization = await capture.requestAuthorization()`; camera not
   `.authorized` → `.notAuthorized`, stop. Else `try await capture.configureSession()` →
   `.ready` and `hasAudioInput = await capture.hasAudioInput`; `.notAuthorized` / any other
   throw → `.notAuthorized` / `.unavailable`.
6. **No eager construction** (WEEK1-SPEC nil-safety rule still holds): nothing in `StoryCueApp`
   creates the store or an `AVCaptureService` at launch in S1.
7. `SessionStore` never imports AVFoundation or UIKit (the UIKit runner is its own file).

## 6. Orphan recovery at launch

`recoverOrphans()`: `ledger.orphanedEntries()`; for each, `fileExists` = the file is on disk
with size > 0. Publish `recoveredSegments`. `AVCaptureMovieFileOutput` writes movie fragments
(`movieFragmentInterval`, default 10 s), so a file cut off by a crash is normally playable up
to its last fragment — the library (S2b) shows it as "recovered"; S2b also owns "keep / delete"
and calls the ledger to close it out. Entries whose file is missing are published with
`fileExists: false` so S2b can clear them. S1 adds **no** new ledger status and does not delete
anything.

`AVCaptureService` sets `movieFragmentInterval` explicitly to 10 s with a comment, so the
recovery claim doesn't rest on a default.

## 7. Tests (all in the baseline `StoryCueTests` target)

`StoryCueTests/SessionStoreTests.swift` (MockCaptureService, a temp-dir SegmentLedger,
FakeBackgroundTaskRunner; `await store.waitForIdleEffects()` before assertions):

| Test | Asserts |
|---|---|
| `testTapRecordRecordsLedgerWritingBeforeCaptureStart` | after `.tapRecord`: ledger has one `.writing` entry whose `fileURL == SegmentFiles.url(for: id, in: dir)`; mock recorded the start with the same id |
| `testSegmentFinishedEventMarksLedgerFinished` | simulate `.segmentFinished(id, .saved)` → phase `.paused`/`.idle` per reason; `orphanedEntries()` empty |
| `testEffectsExecuteInOrderAcrossSends` | `.tapRecord` then immediately `.tapPause`: mock's recorded calls are start-then-stop, never reversed |
| `testStartFailurePausesWithoutStop` | `stubStartError = .deviceUnavailable`, `.tapRecord`, drain → `.paused(.outputEndedUnexpectedly)`, segment outcome `.failed(kept: false)`, no stop recorded, no `.writing` orphan. _(Amended after Sol's diff audit: the original row sent `.runtimeError`, which parked the session in `.finishing` waiting for a callback that can't come; the store now reports the failed start as `fileOutputFinished(.failed(kept: false))`.)_ |
| `testStartFailureNotAuthorizedSetsAvailability` | `stubStartError = .notAuthorized` → `captureAvailability == .notAuthorized` |
| `testBackgroundTaskBeginsAndEndsAroundBackgroundedFinish` | record → `.sceneWillResignActive` → `.sceneDidEnterBackground` → simulate finish: `callLog == ["begin", "end"]`, and `callLog` still `["begin"]` before the simulated finish |
| `testBackgroundExpirationEndsTask` | record → `.sceneWillResignActive` (task begun) → `fireExpiration()`, drain → `endCount == 1`, `state.backgroundTaskActive == false` |
| `testThermalRunsReduceFrameRateBeforeStop` | `.thermalPressureCritical` while recording → `reduceFrameRateCount == 1`, then stop recorded |
| `testMediaServicesResetRecreatesSession` | idle + simulate `.mediaServicesReset` → `recreateCount == 1`, `captureAvailability == .ready` |
| `testMediaServicesResetWhileRecordingDoesNotWedge` | _(added after Sol's audit)_ reset while recording, no callback → `.paused(.mediaServicesReset)`, outcome `.failed(kept: true)`, no orphan |
| `testRecreateRefreshesAudioInput` | _(added after Sol's audit)_ after a reset, `hasAudioInput` reflects the rebuilt session |
| `testRecreateFailureMarksUnavailable` | `stubRecreateError = .deviceUnavailable` → `.unavailable` |
| `testTickPastCapSendsSegmentCapOnce` | record; `tick(now: startedAt + 601)` twice → exactly one stop recorded; after simulated finish, phase `.paused(.segmentCapReached)` |
| `testTickBelowCapDoesNothing` | `tick(now: startedAt + 599)` → no stop |
| `testElapsedInSegmentZeroUnlessRecording` | idle → 0; recording + tick → difference |
| `testNextQuestionPreviewNilAtLastQuestion` | index at last → nil; otherwise the next question |
| `testPrepareCaptureDeniedCamera` | `stubAuthorization` camera `.denied` → `.notAuthorized`, no configure |
| `testPrepareCaptureRequestsWhenNotDetermined` | camera `.notDetermined` → `requestAuthorizationCount == 1`, `.ready` |
| `testPrepareCaptureReportsNoAudio` | `stubHasAudioInput = false` → `hasAudioInput == false`, still `.ready` |
| `testRecoverOrphansReportsWritingEntries` | pre-seed ledger with one `.writing` entry whose file exists (write bytes) and one whose file doesn't → two `RecoveredSegment`s with the right `fileExists` |

`StoryCueTests/SessionMachineTests.swift` — **add** six rows, change nothing else:
`testSegmentCapFinishesSegment` (`.recording` + `.segmentCapReached` → `.finishing(id,
.segmentCapReached)`, `[.stopSegment]`) and `testSegmentCapNoOpWhenNotRecording` (`.idle`,
`.paused`, `.finishing` unchanged, no effects); `testEarlyFileOutputFinishedWhileRecordingPausesAndPersists`
(`.recording(id)` + `fileOutputFinished(id, .saved)` → `.paused(.outputEndedUnexpectedly)`,
`[.persistLedger]`, segment outcome recorded); `testEarlyFinishThenLateInterruptionIsNoOp`
(that state + `audioInterruptionBegan`, then + `runtimeError` → unchanged, no effects);
`testEarlyFinishEndsActiveBackgroundTask` (same with `backgroundTaskActive` → `[.persistLedger, .endBackgroundTask]`);
`testBackgroundTaskExpiredClearsFlag` (`backgroundTaskActive` true + `.backgroundTaskExpired` → false, phase unchanged, no effects; and a no-op when already false).
The normal ordering (interruption first, callback second) is already covered by the existing
rows.

`StoryCueTests/SegmentFilesTests.swift`: `testURLRoundTripsSegmentID`,
`testSegmentIDNilForForeignFilename`, `testDefaultDirectoryIsApplicationSupportNotCaches`.

`StoryCueTests/MockCaptureServiceTests.swift` — add `testRequestAuthorizationGrantsNotDetermined`.

## Do not

- No SwiftUI views, no change to `StoryCueApp.swift`, no preview layer (S2a).
- No Duo code; `AVCaptureService` still wires no direction coordinator.
- No change to any existing `SessionMachineTests` expectation — the reducer's 45 existing
  tests must pass untouched. Reducer edits are additive only (two events, two reasons, the
  segment-cap case and the matching-id branch in the `fileOutputFinished` case).
- No `@unchecked Sendable`, `nonisolated(unsafe)`, or `try!`.
- `MockCaptureService` stays whole-file `#if DEBUG`; `FakeBackgroundTaskRunner` lives in the
  test target, not the app.
- No AI attribution trailers.

## Done when

CI green on both lanes plus the Release compile step; `SessionStoreTests` (20), the 6 new reducer tests, `SegmentFilesTests`
(3) and the 1 new mock test all run and pass; `grep -rn "cachesDirectory" StoryCue/` returns
nothing; Sol's diff audit adjudicated.
