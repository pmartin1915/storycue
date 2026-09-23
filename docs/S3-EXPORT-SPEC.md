# S3 spec — export engine (stitch → Files / share / Photos)

_Written 2026-09-22 (late). Step S3 of `docs/STRATEGY-2026-09-22.md`. Same contract as
`docs/S1-SESSIONSTORE-SPEC.md`: every type, method and test name is fixed here so
`/orchestrate` (Kimi executor, Sol audits the diff) doesn't invent shapes. Inputs: PLAN §2
("exported to Photos or Files as clips or as one stitched file"; "export stitches segments
into the clip"), `StoryCue/ExportManifest.swift`, `StoryCue/SegmentFiles.swift`, the
`NSPhotoLibraryAddUsageDescription` already in `project.yml`._

## Scope

**In:** a UI-free export engine — a pure planner, a stitcher protocol plus its AVFoundation
implementation, a Photos add-only protocol plus its PhotoKit implementation, an `Exporter`
actor that orchestrates them, a failure enum with user-visible copy, temp-file lifecycle, the
container-path fix to orphan recovery (§7), and the tests named below.

**Out:** every view and button. The Export action, the share sheet / `fileExporter`
presentation and the progress UI belong to **S2b (library)**, which can't be specced until
S2a's `AppModel` compiles. S3 doesn't touch `AppModel`, any view, `StoryCueApp.swift`,
`SessionMachine` or `ExportManifest.swift`. No persisted session format is invented here:
the input is `[ClipManifestEntry]` straight from `exportManifest(for:)`.

**Independence:** S3 forks from `main` (`052a3ee` or later). It doesn't depend on PR #3
(S2a) and must not import anything S2a adds.

## Decisions made here (Kimi does not re-decide these)

1. **The 1.0 export unit is one `.mov` per clip** (per question), with its segments stitched
   in order. **Whole-session** (all clips in manifest order, one file) is a second
   `ExportUnit` case. It uses the same stitcher, so it costs nothing extra.
2. **Segment URLs are always re-derived from the segment ID**, using
   `SegmentFiles.url(for: segment.id, in: segmentDirectory)`. Nothing reads the URL stored in
   `.saved(url:)` or `SegmentLedgerEntry.fileURL`. Both are absolute paths into the app's
   data container, and iOS doesn't guarantee that path across app updates. A path stored
   before an update can point into a container that no longer exists, even though the file is
   still there.
3. **Nothing is ever dropped silently.** A segment that the manifest includes but that can't
   go into the output is reported in `ExportResult.dropped` with a reason. That covers a
   missing file, a file of zero size, and a file whose tracks won't load. Segments from
   `.failed(kept: true)` that *were* stitched are reported in `ExportResult.flagged`, so
   S2b can say "part of this clip may be incomplete".
4. **Stitching never re-encodes when it doesn't have to.** It uses
   `AVAssetExportPresetPassthrough` when that preset is compatible with the composition, and
   `AVAssetExportPresetHighestQuality` otherwise. The output type is always `.mov`.
5. **Photos is add-only**: `PHPhotoLibrary.requestAuthorization(for: .addOnly)`.
   Authorization is resolved **before** any stitching, so a denied user isn't made to wait
   through an export that can't land.
6. **Space is checked before stitching.** The export needs the sum of the source file sizes
   × 1.1, checked against `volumeAvailableCapacityForImportantUsage` of the temp directory.
   If the check fails, nothing is written. A `nil` capacity (the value can't be read) skips
   the check and doesn't fail the export. Disk-full during the export is still mapped (§5).
7. **Every output lives in a per-export temp directory**, `<tmp>/Exports/<UUID>/`. The
   engine never writes into the segment directory, and it never deletes a segment.

## 1. Planner — `StoryCue/ExportPlan.swift` (pure Foundation, no AVFoundation)

```swift
enum ExportUnit: Equatable, Sendable { case perClip, wholeSession }

enum DropReason: Equatable, Sendable { case missingFile, emptyFile, unreadable }

struct DroppedSegment: Equatable, Sendable {
    let segmentID: UUID
    let questionID: String
    let reason: DropReason
}

struct PlannedOutput: Equatable, Sendable {
    let fileName: String            // e.g. "StoryCue - Grandparents - 2026-10-02 - Q03.mov"
    let questionIDs: [String]       // one for .perClip; manifest order for .wholeSession
    let sources: [URL]              // SegmentFiles-derived, in stitch order
    let flaggedSegmentIDs: [UUID]   // .failed(kept: true) segments among `sources`
}

struct ExportPlan: Equatable, Sendable {
    let outputs: [PlannedOutput]
    let dropped: [DroppedSegment]
    let totalSourceBytes: Int64
}

enum ExportPlanner {
    /// `fileSize` returns nil for a missing file. It's injected so tests need no disk.
    static func plan(
        entries: [ClipManifestEntry],
        deck: Deck,
        sessionDate: Date,
        unit: ExportUnit,
        segmentDirectory: URL,
        fileSize: (URL) -> Int64?,
        calendar: Calendar            // tests pass a fixed-timezone Gregorian calendar
    ) -> ExportPlan

    /// "StoryCue - <deck title> - <yyyy-MM-dd>" + (" - Q<nn>" for .perClip) + ".mov".
    /// nn = 1-based index of the question in `deck.questions`, zero-padded to 2 digits.
    /// A questionID not found in the deck gets "Q00". Characters in / \ : * ? " < > | and
    /// control characters are replaced with "-". The date is formatted with the injected
    /// calendar's time zone, not TimeZone.current.
    static func fileName(deck: Deck, questionID: String?, sessionDate: Date, calendar: Calendar) -> String
}
```

Rules:
- Source URL for every segment = `SegmentFiles.url(for: segment.id, in: segmentDirectory)`
  (decision 2).
- `fileSize == nil` → dropped `.missingFile`; `== 0` → dropped `.emptyFile`. A dropped
  segment isn't counted in `totalSourceBytes`.
- `.perClip`: one `PlannedOutput` per entry that still has at least one source after the
  drops. An entry left with none produces no output, and its segments show up in `dropped`.
- `.wholeSession`: exactly one `PlannedOutput` holding every surviving source in manifest
  order (entry order, then segment order within the entry), with `questionID: nil` in the
  file name. If nothing survives, `outputs` is empty.
- `dropped` is in manifest order.

## 2. Stitcher — `StoryCue/Stitcher.swift`

```swift
struct StitchReport: Equatable, Sendable {
    let unreadable: [URL]           // sources whose tracks failed to load; skipped
    let durationSeconds: Double
}

protocol Stitcher: Sendable {
    /// Writes one .mov at `output` from `sources`, in order. Skips a source whose asset or
    /// video track fails to load, and reports it in `unreadable`. Throws
    /// ExportFailure.nothingToExport if no source is readable. Honors Task cancellation.
    func stitch(_ sources: [URL], to output: URL) async throws -> StitchReport
}

struct AVStitcher: Stitcher { init() }
```

How `AVStitcher` builds the composition:
- One `AVMutableComposition` with one video track and one audio track, both
  `kCMPersistentTrackID_Invalid`.
- For each source, create an `AVURLAsset(url:)` and load it with
  `try await asset.load(.duration)` and `asset.loadTracks(withMediaType: .video)`. A throw,
  or no video track, marks the source unreadable and moves on to the next one.
- Insert the video time range `CMTimeRange(start: .zero, duration: duration)` at the running
  cursor. If the source has an audio track, insert it at the same cursor. A source with no
  audio leaves a silent gap. It isn't an error, because S2a has a "no audio" state.
- Set the composition video track's `preferredTransform` from the **first readable** source's
  video track (`load(.preferredTransform)`). The recorder is portrait-locked, so every
  segment carries the same transform.
- Export with the preset from decision 4. Choose it with
  `await AVAssetExportSession.compatibility(ofExportPreset:with:outputFileType: .mov)`, then
  run `try await session.export(to: output, as: .mov)`. That's the async API, with no
  `exportAsynchronously` and no completion handlers. Remove any file already at `output`
  before exporting.
- `#if canImport(AVFoundation)` guards aren't needed, because this is an iOS-only target.

## 3. Photos — `StoryCue/PhotoLibrary.swift`

```swift
enum PhotoAddAuth: Equatable, Sendable { case notDetermined, authorized, limited, denied, restricted }

protocol PhotoLibrarySaving: Sendable {
    func addOnlyStatus() async -> PhotoAddAuth
    func requestAddOnly() async -> PhotoAddAuth
    func saveVideo(at url: URL) async throws    // PHAssetCreationRequest, .video resource
}

struct PHPhotoLibrarySaver: PhotoLibrarySaving { init() }
```

`.limited` counts as allowed. `PHPhotoLibrary.shared().performChanges` is used in its async
form.

## 4. Orchestrator — `StoryCue/Exporter.swift`

```swift
enum ExportDestination: Equatable, Sendable { case files, photos }   // .files also serves the share sheet

struct ExportResult: Equatable, Sendable {
    let directory: URL                  // the per-export temp dir; S2b calls discard(_:) when done
    let files: [URL]                    // outputs written, in plan order
    let dropped: [DroppedSegment]       // planner drops + stitcher-unreadable (reason .unreadable)
    let flaggedSegmentIDs: [UUID]
    let savedToPhotos: Bool
}

actor Exporter {
    init(
        segmentDirectory: URL,
        temporaryRoot: URL,                         // production: FileManager.default.temporaryDirectory
        stitcher: any Stitcher,
        photos: any PhotoLibrarySaving,
        availableCapacity: @escaping @Sendable () -> Int64?,   // production: temp volume's important-usage capacity
        fileSize: @escaping @Sendable (URL) -> Int64?          // production: attributesOfItem size
    )

    func export(
        entries: [ClipManifestEntry], deck: Deck, sessionDate: Date,
        unit: ExportUnit, destination: ExportDestination
    ) async throws -> ExportResult

    /// Removes a result's temp directory. Idempotent.
    func discard(_ result: ExportResult)

    /// Launch-time sweep: removes every <temporaryRoot>/Exports/* directory. S2b calls it at
    /// launch. Nothing that's still in use survives a relaunch.
    func purgeStaleExports()
}
```

Order inside `export`. Each step stops the export on failure, and nothing is written before
step 4:
1. `.photos` only: resolve authorization. `notDetermined` → `requestAddOnly()`.
   `denied` → throw `.photosDenied`. `restricted` → throw `.photosRestricted`.
2. Plan with `ExportPlanner.plan`, using `Calendar(identifier: .gregorian)` with
   `TimeZone.current` in production. No outputs → throw `.nothingToExport`.
3. Preflight space: `availableCapacity()` non-nil and less than
   `Int64(Double(plan.totalSourceBytes) * 1.1)` → throw
   `.insufficientSpace(neededBytes:availableBytes:)`.
4. Create `<temporaryRoot>/Exports/<UUID>/`, then stitch each output in plan order. Check
   `Task.checkCancellation()` between outputs. Merge each `StitchReport.unreadable` into
   `dropped` with reason `.unreadable`. If a stitch throws `.nothingToExport` for one
   output, skip that output (its segments are already in `dropped`) and continue. If the
   export ends with zero files, remove the directory and throw `.nothingToExport`.
5. `.photos`: `saveVideo` each file in order. After all of them succeed, remove the temp
   directory. `files` stays in the result for reporting, and `directory` no longer exists.
6. **On any throw after step 4 starts, including cancellation, the temp directory is
   removed before the error propagates.** A failed export leaves nothing behind.

## 5. Failures — `StoryCue/ExportFailure.swift`

```swift
enum ExportFailure: Error, Equatable, Sendable {
    case nothingToExport
    case insufficientSpace(neededBytes: Int64, availableBytes: Int64)
    case outOfSpace                      // disk filled during the write
    case photosDenied, photosRestricted
    case cancelled
    case failed(domain: String, code: Int)

    /// Maps any error thrown by AVFoundation / PhotoKit / Foundation / cancellation.
    static func from(_ error: any Error) -> ExportFailure

    var userMessage: String { get }      // exact copy below; lives here, not in UICopy (S2a)
}
```

Mapping for `from(_:)`, applied in the order listed:

| Input | → |
|---|---|
| already an `ExportFailure` | itself |
| `CancellationError`, or `CocoaError(.userCancelled)` | `.cancelled` |
| `AVError(.diskFull)`, `CocoaError(.fileWriteOutOfSpace)`, `POSIXError(.ENOSPC)` | `.outOfSpace` |
| `PHPhotosError(.accessUserDenied)` | `.photosDenied` |
| `PHPhotosError(.accessRestricted)` | `.photosRestricted` |
| anything else | `.failed(domain: (error as NSError).domain, code: (error as NSError).code)` |

The exporter wraps every throw in steps 4–5 with `from(_:)`, so callers only ever see
`ExportFailure`.

`userMessage` copy (plain, no blame, no jargon):
- `nothingToExport`: "There's nothing to export yet. None of these clips have any saved video."
- `insufficientSpace`: "Your iPhone needs about <needed − available, formatted> more free space to export this. Free up some space and try again." Use `ByteCountFormatter`, `.file` style.
- `outOfSpace`: "Your iPhone ran out of space during the export. Your recordings are safe. Free up some space and try again."
- `photosDenied`: "StoryCue can't save to Photos. To allow it, go to Settings › StoryCue › Photos and choose Add Photos Only."
- `photosRestricted`: "Saving to Photos is restricted on this iPhone. Export to Files instead."
- `cancelled`: "Export canceled. Your recordings are unchanged."
- `failed`: "The export didn't finish. Your recordings are safe. Try again." (Domain and code go to
  the log, not into the copy.)

Every message that follows a failed write says the recordings are safe. That's true by
construction, because nothing in S3 writes to or deletes from the segment directory.

## 6. Tests — `StoryCueTests/`

Test doubles live in `StoryCueTests/ExportTestDoubles.swift` (not in the app target):
`MockStitcher` (records calls, writes a 1-byte file at `output`, and can be configured per
source URL to report unreadable, throw, or wait for a continuation so cancellation can be
tested) and `MockPhotoLibrary` (configurable status and request result, records saved URLs,
can throw).

**`ExportPlannerTests`** (pure, no disk):
- `testPerClipOneOutputPerEntryInManifestOrder`
- `testWholeSessionOneOutputAllSourcesInOrder`
- `testSourcesDerivedFromSegmentIDNotStoredURL`: a `.saved(url:)` pointing at `/nonexistent/...` still plans `SegmentFiles.url(for:in:)`
- `testMissingFileDroppedWithReason`
- `testEmptyFileDroppedWithReason`
- `testEntryWithAllSourcesDroppedProducesNoOutput`
- `testFailedKeptSegmentsAreFlagged`
- `testTotalSourceBytesExcludesDropped`
- `testFileNameUsesDeckQuestionNumber`: the third question in the deck → "Q03"
- `testFileNameUnknownQuestionIsQ00`
- `testFileNameSanitizesReservedCharacters`
- `testFileNameUsesInjectedTimeZone`: the same instant, in two time zones, gives two dates

**`ExportFailureTests`**:
- `testMapsCancellation`, `testMapsDiskFullVariants` (all three inputs in the table),
  `testMapsPhotosErrors`, `testPassesThroughExportFailure`, `testUnknownErrorKeepsDomainAndCode`
- `testEveryPostWriteMessageSaysRecordingsAreSafe`: `outOfSpace`, `cancelled` and `failed` contain "recordings"
- `testInsufficientSpaceMessageFormatsShortfall`

**`ExporterTests`** (`MockStitcher`, `MockPhotoLibrary`, a real temp dir under
`FileManager.default.temporaryDirectory`, injected `fileSize` and `availableCapacity`):
- `testFilesExportWritesOneFilePerClip`
- `testPhotosDeniedThrowsBeforeAnyStitch`
- `testPhotosNotDeterminedRequestsThenProceeds`
- `testPhotosRestrictedThrows`
- `testInsufficientSpaceThrowsBeforeAnyStitch`
- `testNilCapacitySkipsPreflight`
- `testUnreadableSourcesMergedIntoDropped`
- `testOutputWithNoReadableSourceIsSkippedOthersContinue`
- `testAllOutputsUnreadableThrowsNothingToExportAndLeavesNoDirectory`
- `testStitchErrorMapsAndRemovesTempDirectory`
- `testCancellationMidExportThrowsCancelledAndRemovesTempDirectory`
- `testPhotosExportSavesEachFileThenRemovesTempDirectory`
- `testDiscardIsIdempotent`
- `testPurgeStaleExportsRemovesOldDirectories`
- `testExportNeverTouchesSegmentDirectory`: the segment directory's file list is identical before and after, on success and on failure

**`AVStitcherTests`** (real AVFoundation on the simulator):
- Helper `StoryCueTests/SyntheticMovie.swift`:
  `static func write(to url: URL, seconds: Double, withAudio: Bool) async throws`. It uses
  `AVAssetWriter` with small H.264 frames (64×64, 10 fps), plus silent AAC when `withAudio`.
- `testStitchesTwoSegmentsDurationIsSum`: 1.0 s + 1.0 s → 2.0 s ± 0.15
- `testStitchesSegmentWithoutAudio`: one source with audio and one without → succeeds, with the durations summed
- `testCorruptSourceReportedUnreadableOthersStitched`: random bytes named `.mov`, plus one good source
- `testAllSourcesUnreadableThrowsNothingToExport`
- **Pre-registered fallback:** if `SyntheticMovie.write` itself throws on the runner, because
  no encoder is available there, the test calls `XCTSkip("synthetic movie unavailable: \(error)")`.
  Only the helper's own failure is skippable. A stitch assertion that fails is a real
  failure. If the tests are skipped, real stitching is verified on device at S5 (rung 4b).
- `PHPhotoLibrarySaver` has no test. It's compile-only in CI and verified at S5.

## 7. Container-path fix in orphan recovery (S1 code, same rule as decision 2)

`SessionStore.recoverOrphans()` currently checks `entry.fileURL.path`. After an app update
that path may point into the old container, so a real recovered file would show as
`fileExists: false`, which is the "vanished recording" this app promises never to cause.
The fix changes one line. Compute the path as
`SegmentFiles.url(for: entry.segmentID, in: segmentDirectory)`. `SessionStore` already holds
`segmentDirectory`. Don't change `SegmentLedgerEntry`, which stays `Codable`-compatible.
- New test in `SessionStoreTests`: `testRecoverOrphansUsesSegmentIDNotStoredPath`. Seed a
  `.writing` ledger entry whose `fileURL` points at a nonexistent directory, while the real
  file exists at `SegmentFiles.url(for:in:)`. Assert `fileExists == true`.

## Do not

- Add a view, button, `AppModel` property or share sheet. That's S2b.
- Read `SegmentOutcome.saved(url:)`'s URL or `SegmentLedgerEntry.fileURL` anywhere in new code.
- Delete, move or modify a file in the segment directory.
- Use `exportAsynchronously`, `requestAuthorization(_:)` (the old read-write API) or `PHPhotoLibrary` read access.
- Add a dependency or a new Info.plist key (`NSPhotoLibraryAddUsageDescription` is already present).
- Touch `ExportManifest.swift`, `SessionMachine.swift`, `.github/`, or `project.yml`. XcodeGen
  picks up the new files from the existing `StoryCue`/`StoryCueTests` source globs.

## Done when

- All tests above exist with exactly these names, and the existing suite still passes on both
  CI lanes. The new count is expected to be 89 plus about 40.
- `AVStitcherTests` is green or skipped, never red. A skip is recorded in STATE as "stitching
  unverified until S5".
- Sol diff audit, focused on the data-loss paths: decision 2, decision 3, §4 step 6 and §7.
  The audit runs **after** CI has compiled the branch, never before.
