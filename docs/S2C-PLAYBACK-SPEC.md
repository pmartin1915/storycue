# S2c spec — in-app playback, Done opens the session, completion state

_Written 2026-10-03. Perry decided after the S5 device pass that 1.0 gets in-app playback. Builds
on S2b (`Library`, `SessionDetailView`) and S3 (`AVStitcher`). Same contract style as S2a/S2b:
every type, method, file and test name below is fixed, so `/orchestrate` does not invent shapes.
Single-screen 1.0, no Duo code. Visual polish (accent color, record button, haptics elsewhere) is
**S2d**, not this step. Design context: `docs/reviews/DESIGN-REVIEW-2026-10-03.md` rows 10, 11, 13._

## Scope

**In:** play one answer in the app, full screen, with the question as a caption; Done (or Finish)
after a session with at least one kept answer opens that session's detail screen; a one-line
completion header plus a success haptic on that screen.

**Out:** "Play all" reel; next/previous inside the player; previewing an undecided recovered
segment before Keep (IDEAS); thumbnails; any change to export output; landscape playback.

## Decisions made here (the executor does not re-decide these)

1. **One composition builder, shared by export and playback.** Extract the composition-building
   half of `AVStitcher.stitch` (everything up to, not including, the passthrough check and
   `AVAssetExportSession`) into
   `static func makeComposition(_ sources: [URL]) async throws -> (composition: AVMutableComposition, durationSeconds: Double, unreadable: [URL])`
   on `AVStitcher`. Order inside `stitch` stays: **remove any file at `output` first**, then call
   `makeComposition`, then (unchanged) return `outputWritten == false` when `durationSeconds == 0`,
   else the passthrough check and export. The `preferredTransform` assignment and the
   empty-audio-track removal move **into** `makeComposition` (they precede the passthrough check today). **Behavior of `stitch`
   must not change**: every existing `AVStitcherTests` test still passes unchanged. Playback builds an
   `AVPlayerItem(asset:)` from the returned composition, in memory: playback never writes a file and
   never touches the segment directory. Swift 6: `AVMutableComposition`/`AVPlayerItem` are not
   Sendable, so `AnswerPlayerView.swift` uses `@preconcurrency import AVFoundation` (as `Stitcher.swift`
   does), and the `AVPlayer` is created on the main actor and held in the view's `@State`. A
   `CancellationError` while loading (cover dismissed early) does nothing; it is not "unavailable".
2. **Which segments play = which segments export.** New pure function in `ExportManifest.swift`:
   `func playbackSources(for record: SessionRecord, questionID: String, in directory: URL) -> [URL]`.
   It takes the `exportManifest(for: record.clips)` entry for `questionID` and returns
   `SegmentFiles.url(for: segment.id, in: directory)` for each of its segments, in order; `[]` when
   there is no entry. (Same rules as export: `.saved` and `.failed(kept: true)` play;
   `.failed(kept: false)` and `nil` don't. Never read `SegmentOutcome.saved(url:)`.)
3. **Player = the system player.** `AnswerPlayerView` (new file `StoryCue/Views/AnswerPlayerView.swift`)
   is presented with `.fullScreenCover` from `SessionDetailView`. It wraps `AVPlayerViewController`
   in a `UIViewControllerRepresentable` named `SystemPlayer` (same file). No custom transport
   controls. States: loading (`ProgressView`), playing, unavailable (`UICopy.playbackUnavailable`,
   shown when `makeComposition` throws or returns `durationSeconds == 0`). Autoplays once ready.
   A `Done` button (`UICopy.done`, top-trailing, 44 pt) dismisses; on dismiss the player pauses
   and is released. Playback and an export may overlap (both only read segment files). The
   source URLs are resolved when the cover opens; a file deleted or missing by then maps to the
   unavailable state.
4. **Caption.** The question text (from `record.questionPosition(for:)`, or `UICopy.unknownQuestion`)
   sits in a rounded dark material card at the top, over the video, above the system controls'
   hit area. After 3 seconds it shrinks to one line (`lineLimit(1)`); with Reduce Motion the change
   is instant. It never fully disappears.
5. **Audio.** On appear, `AnswerPlayerView` sets `AVAudioSession.sharedInstance()` category
   `.playback`, mode `.moviePlayback` and activates it (`try?`; a failure only means the silent switch
   may mute playback). Nothing restores it: `AVCaptureSession` reconfigures the app audio session
   itself when the next recording session starts (see the comment near `AVCaptureService.swift:160`;
   unverified, so it is a device check below). On disappear, call
   `try? setActive(false, options: .notifyOthersOnDeactivation)` so other apps' audio resumes.
6. **Where the play control lives.** Each answer row in `SessionDetailView` gets a trailing play
   button: SF Symbol `play.circle.fill`, `.font(.title)`, at least 44 × 44 pt,
   `.buttonStyle(.borderless)` (so it doesn't swallow the row's Keep/Delete buttons),
   `accessibilityLabel(UICopy.playAnswer)`. It shows only when `playbackSources(...)` is non-empty
   **and** the row's session is not the active session (`library.activeSessionID`), because the
   camera owns the audio session while recording. Structure: the row becomes an `HStack` whose
   leading child is the existing `VStack` (question text, incomplete note, Keep/Delete controls,
   unchanged) and whose trailing child is the play button. Tapping it sets
   `@State private var playing: PlayableAnswer?`, where
   `struct PlayableAnswer: Identifiable, Hashable { let questionID: String; var id: String { questionID } }`
   (in `AnswerPlayerView.swift`). One `.fullScreenCover(item: $playing)` on the list builds
   `AnswerPlayerView(sources:caption:)` from `playbackSources(...)` and the question text; it sits
   beside the existing export `.sheet` and the two `confirmationDialog`s, which stay as they are.
   Demo mode shows the button too (the demo files are junk, so tapping it shows the unavailable
   state; screenshots are re-shot after S2d anyway).
7. **Done opens the session.** `AppModel` gains `var finishedSessionID: UUID?` (settable; the view
   binds to it). At the end of `endSession()`, after `await task.value`, set
   `finishedSessionID = id` **iff** `active == nil && library.record(id: id) != nil` (`finish`
   keeps no record when nothing was keep-worthy; the `active == nil` guard stops a late push of the
   old session if the user already started a new one during shutdown, since `beginSession` awaits
   `ending` and its continuation may run first). `beginSession` sets it to `nil`. `RootView` adds
   `.navigationDestination(item: $model.finishedSessionID) { id in SessionDetailView(sessionID: id, model: model, showsCompletion: true) }`
   next to the existing recorder destination. Back returns to whatever is beneath: the deck list on
   iOS 27 per CI run `37083268083`, possibly the consent card. Both are acceptable; do not add a
   `NavigationStack(path:)` or other hacks. The pop (recorder) and push (detail) are two animations
   with a short gap while `finish` runs; that is accepted.
8. **Completion header.** `SessionDetailView` gains `var showsCompletion: Bool = false` (default keeps
   every existing call site unchanged). When true, the list's first section has a header:
   `UICopy.completionTitle(count)` (`.title3.bold()`) and `UICopy.completionBody` (`.callout`,
   secondary), where `count = record.manifest.count`, shown only when `count > 0`. Haptic:
   `@State private var didAppear = false`, `.onAppear { didAppear = true }`,
   `.sensoryFeedback(.success, trigger: didAppear)` (fires once, on the false→true change).
9. **Copy** (in `UICopy`, nothing hard-coded in views):
   `playAnswer = "Play answer"`,
   `playbackUnavailable = "This answer can't be played. The file may be damaged or missing."`,
   `completionTitle(_ n: Int)` → `"You recorded 1 answer"` / `"You recorded \(n) answers"`,
   `completionBody = "They're saved on this iPhone. Tap play to watch one."`.

## Tests (all must run and pass in CI; names fixed)

- `AVStitcherTests.testMakeCompositionDurationMatchesSources`: two `SyntheticMovie` sources;
  `durationSeconds` ≈ their sum (same tolerance the file already uses); `unreadable` empty.
- `AVStitcherTests.testMakeCompositionReportsUnreadable`: one real source + one junk file;
  junk URL in `unreadable`, duration = the real one's.
- `ExportManifestClipsTests.testPlaybackSourcesUsesManifestRules`: a clip with `.saved`,
  `.failed(kept: true)`, `.failed(kept: false)` and `nil` segments returns exactly the first two
  URLs, in order, built from `SegmentFiles`.
- `ExportManifestClipsTests.testPlaybackSourcesUnknownQuestionIsEmpty`.
- `AppModelTests.testEndSessionWithKeptClipSetsFinishedSessionID`.
- `AppModelTests.testEndSessionWithNothingKeptLeavesFinishedSessionIDNil`.
- `AppModelTests.testBeginSessionClearsFinishedSessionID`.
- `AppModelTests.testLateFinishDoesNotSetFinishedSessionIDWhenNewSessionActive`: end a session
  with a kept clip and begin a new one before the first `endSession` returns (the existing shutdown
  delay on `MockCaptureService` holds it); `finishedSessionID` stays `nil`.
- `UICopyTests.testCompletionTitlePlural` ("You recorded 1 answer", "You recorded 2 answers").

(Read the existing tests in each file first and follow their helpers and style.)

## Do not

- No change to `stitch`'s observable behavior or to any existing test.
- No file written by playback; no `removeItem` outside the places S2b allows.
- No reading of `SegmentOutcome.saved(url:)`.
- No `try!`, `as!`, `Task.detached`, `@unchecked Sendable`, `nonisolated(unsafe)`; no `.system(size:)`.
- No user-visible string literal outside `UICopy`.
- No Duo code, no change to `SessionMachine.reduce`, no AVFoundation/UIKit/SwiftUI import in
  `SessionStore.swift`.
- No AI attribution anywhere.

## Done when

CI green (Build & Test both lanes + Release compile; Screenshots still green); the 9 new tests run
and pass; the S2b greps still hold; boss device check on the next TestFlight build: play a
one-segment and a two-segment answer, with the silent switch on; Done after recording lands on the
session with the completion header; Done with nothing recorded lands on the deck list; after playing an answer, record a new session and
confirm it has both video and sound.
