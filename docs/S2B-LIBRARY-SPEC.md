# S2b spec — session library, recovery, delete, export UI (+ screenshot UI test)

_Written 2026-10-02. Step S2b of `docs/STRATEGY-2026-09-22.md`. Builds on S1 (`SessionStore`),
S2a (`AppModel`, screens, `UICopy`) and S3 (`Exporter`). Same contract as S2a: every type,
method, file and test name is fixed so `/orchestrate` (Kimi executes; Kimi layout review; Sol
audits the data-loss paths) doesn't invent shapes. **Single-screen 1.0** — no Duo code._

Two dispatches, in order. **Part A** is the product (it unblocks S5's 4b-export device check);
**Part B** is the screenshot UI test (it unblocks S6's App Store screenshots). Part A ships on its
own if Part B slips.

## Scope

**In (Part A):** a persistent session index; the library list; a session detail screen;
launch-time crash recovery with keep/delete; deleting a session (files + ledger + index);
storage status and a low-space banner; the export screen over S3's `Exporter` (unit choice,
Files/share sheet, Photos, progress, cancel, results); the launch-time stale-export purge.

**In (Part B):** a UI-test target and a DEBUG-only demo launch mode that produce the 6.9" App
Store screenshot set as a CI artifact.

**Out:** Duo/outer display; any change to `SessionMachine`'s reducer; re-recording; renaming
sessions; iCloud/backup settings; cleanup of `.failed(kept: false)` partial files inside a kept
session (IDEAS); a "no TODO in question text" UI assertion (S4's `DeckDataTests` copy lint
already covers it).

## Decisions made here (the executor does not re-decide these)

1. **The index is the library's source of truth; the ledger is its recovery backstop.** One
   JSON file, `session-index.json`, in the segment directory, written atomically (temp file +
   replace, the `SegmentLedger.save` pattern). It stores `[SessionRecord]`. Every segment path is
   re-derived with `SegmentFiles.url(for:in:)`; `SegmentOutcome.saved(url:)` is never read
   (S3 decision 2).
2. **Checkpoints come from the store's effect queue, after capture starts.** `SessionStore`
   gains an optional `archive` callback, called with `state.clips` (a) in
   `execute(.startSegment)` right after `capture.startSegment` succeeds, and (b) at the end of
   `execute(.persistLedger)`. Order inside `.startSegment` becomes ledger record → capture start
   → archive, so the Record tap waits on no extra disk write. Because the effect queue is serial,
   checkpoints arrive in order. A crash between capture start and the checkpoint leaves a
   ledger `.writing` entry with no index record — decision 4 recovers it.
3. **A session with nothing worth keeping leaves no record.** Mirrors `exportManifest`'s
   omitted-not-empty rule: a checkpoint with zero clips is ignored, and `finish` on a session
   whose clips have no `.saved` / `.failed(kept: true)` segment **deletes** it (files, ledger,
   record — decision 5's order). A late checkpoint for a finished or deleted session is ignored
   (`closedSessionIDs`), because `endSession()` can return while a `.persistLedger` effect is
   still queued.
4. **Launch reconciliation (`Library.load()`), exactly these rules, in this order:**
   1. `await exporter.purgeStaleExports()` (S3 hand-off; nothing can be exporting at launch).
   2. Load the index. If the file exists but won't decode, **move it aside** to
      `session-index.unreadable-<yyyyMMdd-HHmmss>.json` in the same directory (never overwrite or
      delete it) and continue with `[]`; step 5 rebuilds what it can from the ledger.
   3. Every record with `isFinished == false` (an app kill mid-session) → `isFinished = true`.
   4. Every segment with `outcome == nil` in a record: if its file has size > 0 it stays `nil` —
      that is a **recovered clip**, shown for the user to keep or delete. If the file is missing
      or empty → `outcome = .failed(kept: false)` and `ledger.markFinished(id)`.
   5. **Ledger entries no record mentions** (a crash before the first checkpoint, or an index
      lost in step 2): take only entries whose file has size > 0 and whose `questionID` belongs
      to a v1 deck. Group them by (deck, calendar day of `startedAt` in `Calendar.current`) into
      one synthesized record per group: `id` new, `deckTitle` from the deck, `startedAt` = the
      earliest entry, clips grouped by `questionID` ordered by each clip's first `startedAt`,
      segments ordered by `startedAt`, `endReason nil`, outcome `.saved(url: SegmentFiles.url…)`
      for `.finished` entries and `nil` (recovered) for `.writing` / `.orphaned`,
      `isFinished = true`. Entries with no file or no matching deck are left untouched.
   6. Sort newest `startedAt` first; save if anything changed; `refreshStorage()`;
      `isLoaded = true`.

   `load()` is idempotent. The UI calls it once at launch. The consent button stays disabled
   until `isLoaded`, so no session starts during reconciliation.
5. **Delete order: files → ledger → index.** A crash mid-delete leaves at worst a record whose
   files are gone (the planner drops them as `.missingFile`, and the user can delete again) —
   never invisible files eating space that nothing points to. **Refused** for the active
   session and for a session with an export in flight. Every delete in the UI goes through a
   confirmation dialog. This is the first code that deletes a segment, so S3's "your recordings
   are safe" copy now depends on this rule: **the export path still never deletes**; only
   `Library.delete` and `Library.discard` do.
6. **`SegmentLedger` gains two methods** (`remove`, `allEntries`). S2a's "no ledger changes" rule
   is lifted for exactly these two; `record` / `markFinished` / `orphanedEntries` are unchanged.
7. **Share sheet = a `UIActivityViewController` representable**, not `ShareLink`: its
   `completionWithItemsHandler` is the only dismissal hook, and it calls
   `exporter.discard(result)` so the temp directory goes as soon as the sheet closes (Save to
   Files is in that sheet). Photos exports discard themselves (S3).
8. **Low space = under 1 GB available** (`Library.lowSpaceThreshold = 1_000_000_000`), read
   through an injected `availableCapacity` closure (the `Exporter` pattern). It shows a banner on
   the deck picker and a line on the consent card. **It does not block recording** — a 10-minute
   answer is well under a gigabyte, and refusing to record is worse than warning.

## 1. `SessionRecord` + `SessionIndex` — `StoryCue/SessionIndex.swift` (pure Foundation)

```swift
struct SessionRecord: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let deckID: String
    let deckTitle: String           // snapshot, so a renamed/removed deck still lists
    let startedAt: Date
    var clips: [Clip]
    var isFinished: Bool

    var deck: Deck? { Deck.v1Decks.first { $0.id == deckID } }
    /// What an export would contain (exportManifest(for: clips)).
    var manifest: [ClipManifestEntry] { exportManifest(for: clips) }
}

actor SessionIndex {
    init(directory: URL)                         // file: directory/session-index.json; touches no disk
    func load() throws -> [SessionRecord]        // missing file → []; undecodable → throws
    func save(_ records: [SessionRecord]) throws // atomic; creates the directory if needed
    /// Moves an undecodable index aside (decision 4.2). Returns the new URL, nil if no file.
    func quarantineUnreadable(now: Date) throws -> URL?
}
```

**`ExportManifest.swift`** gains `func exportManifest(for clips: [Clip]) -> [ClipManifestEntry]`
with the existing rules, and the existing `exportManifest(for state:)` becomes
`exportManifest(for: state.clips)`. No rule changes.

**`SegmentLedger`** gains:

```swift
func remove(segmentIDs: Set<UUID>) async throws   // drops those entries; atomic save; unknown IDs ignored
func allEntries() async throws -> [SegmentLedgerEntry]
```

## 2. `SessionStore` hook (amends S1)

```swift
init(deck:capture:ledger:segmentDirectory:background:now: Date = Date(),
     archive: (@MainActor ([Clip]) -> Void)? = nil)
```

Called as `archive?(state.clips)` at the two points in decision 2 and nowhere else. Every existing
call site and test compiles unchanged (defaulted parameter). `SessionStore` still imports no
AVFoundation, UIKit or SwiftUI.

## 3. `Library` — `StoryCue/Library.swift`

```swift
struct StorageStatus: Equatable, Sendable {
    let usedBytes: Int64            // sum of *.mov sizes in the segment directory
    let availableBytes: Int64?      // nil when the volume won't say
    var isLow: Bool { availableBytes.map { $0 < Library.lowSpaceThreshold } ?? false }
}

struct RecoveredClip: Equatable, Identifiable, Sendable {
    let sessionID: UUID
    let segment: Segment            // outcome == nil
    var id: UUID { segment.id }
}

@MainActor @Observable
final class Library {
    static let lowSpaceThreshold: Int64 = 1_000_000_000

    private(set) var sessions: [SessionRecord] = []      // newest startedAt first
    private(set) var storage = StorageStatus(usedBytes: 0, availableBytes: nil)
    private(set) var isLoaded = false
    private(set) var exportingSessionIDs: Set<UUID> = []
    var activeSessionID: UUID?                           // set/cleared by AppModel
    var recovered: [RecoveredClip] { get }               // nil-outcome segments, sessions order, excluding the active session

    init(segmentDirectory: URL, index: SessionIndex, ledger: SegmentLedger, exporter: Exporter,
         availableCapacity: @escaping @Sendable () -> Int64?,
         fileSize: @escaping @Sendable (URL) -> Int64?)

    func load() async                                    // decision 4
    func checkpoint(sessionID: UUID, deck: Deck, startedAt: Date, clips: [Clip])
    func finish(sessionID: UUID, clips: [Clip]) async   // decision 3
    func keep(_ clip: RecoveredClip) async               // outcome .failed(kept: true); ledger.markFinished
    func discard(_ clip: RecoveredClip) async            // delete file; outcome .failed(kept: false); ledger.remove
    func canDelete(_ sessionID: UUID) -> Bool           // not active, not exporting
    @discardableResult func delete(sessionID: UUID) async -> Bool   // decision 5
    func beginExport(_ sessionID: UUID)
    func endExport(_ sessionID: UUID)
    func refreshStorage()
    func record(id: UUID) -> SessionRecord?
    /// Test hook: resumes when every queued save has finished.
    func waitForPendingSaves() async
}
```

Rules:
- **Saves are serial and ordered.** Every mutation updates `sessions` synchronously on the main
  actor, then enqueues `index.save(snapshot)` with the snapshot taken at that moment, chained
  after the previous save (`let previous = saveTask; saveTask = Task { await previous?.value;
  try? await index.save(snapshot) }`). A failed save is not retried (the next mutation saves the
  whole array again).
- `checkpoint`: ignored if `clips` is empty or the ID is in `closedSessionIDs` (private
  `Set<UUID>`). Otherwise insert `SessionRecord(id:deckID:deckTitle:startedAt:clips:
  isFinished: false)` or replace an existing record's `clips` **keeping its `isFinished`**.
- `finish`: insert the ID into `closedSessionIDs` first. If `clips` has no `.saved` or
  `.failed(kept: true)` segment → `delete(sessionID:)` (bypassing the active check — the caller
  has already cleared it) and also remove the files of any listed segments. Otherwise set
  `clips` and `isFinished = true` (inserting the record if no checkpoint ever landed).
- `discard`: after it, if the record has no `.saved`, `.failed(kept: true)` or `nil` segment
  left → `delete(sessionID:)`.
- `delete`: refuses (false, no change) when `canDelete` is false. Otherwise remove every
  segment file (`try?` each), then `ledger.remove(segmentIDs:)` (`try?`), then drop the record,
  save, `refreshStorage()`, true.
- `refreshStorage`: list the segment directory (missing → used 0); sum sizes of `.mov` files via
  `fileSize`; `availableBytes = availableCapacity()`.
- Production closures (built in `AppModel.production()`): `availableCapacity` reads
  `.volumeAvailableCapacityForImportantUsageKey` on the segment directory (nil on error);
  `fileSize` reads `attributesOfItem(...)[.size]` (nil on error).

## 4. `AppModel` (amends S2a)

```swift
struct ActiveSession {
    let id: UUID                    // new
    let startedAt: Date             // new
    let deck: Deck
    let store: SessionStore
    let capture: any CaptureService
}
let library: Library                // new

init(segmentDirectory: URL,
     makeCapture: @escaping @MainActor (URL) -> any CaptureService,
     makeBackground: @escaping @MainActor () -> any BackgroundTaskRunner,
     exporter: Exporter? = nil,                              // nil → production Exporter (below)
     availableCapacity: @escaping @Sendable () -> Int64? = { nil },
     fileSize: @escaping @Sendable (URL) -> Int64? = AppModel.attributesFileSize)
let exporter: Exporter              // new; the same instance Library uses
static let attributesFileSize: @Sendable (URL) -> Int64?   // attributesOfItem size, nil on error
```

- `init` builds `SessionIndex(directory: segmentDirectory)` and the `Library`. The default
  exporter is `Exporter(segmentDirectory:, temporaryRoot: FileManager.default.temporaryDirectory,
  stitcher: AVStitcher(), photos: PHPhotoLibrarySaver(), availableCapacity: <temp-volume
  important-usage capacity>, fileSize: attributesFileSize)`. Constructing these touches no camera
  (nil-safety rule holds); S2a's `testInitConstructsNoCapture` must still pass.
- `beginSession(deck:)`: makes `id = UUID()`, `startedAt = Date()`, passes
  `archive: { [weak library] clips in library?.checkpoint(sessionID: id, deck: deck,
  startedAt: startedAt, clips: clips) }` to the store, sets `library.activeSessionID = id`.
  Everything else unchanged.
- `endSession()`: the refusal checks, `store.stop()` and `active = nil` stay synchronous before
  the first await (S2a rule). Capture `id` and `store.state.clips` into locals first, also set
  `library.activeSessionID = nil` before the first await, then `await library.finish(sessionID:
  clips:)`, then `await capture.shutdown()`.

## 5. `ExportModel` — `StoryCue/ExportModel.swift`

```swift
@MainActor @Observable
final class ExportModel {
    enum Phase: Equatable {
        case choosing
        case running(done: Int, total: Int)
        case sharing(ExportResult)          // share sheet up; files in result.files
        case finished(String)               // summary copy
        case failed(String)                 // ExportFailure.userMessage
    }
    private(set) var phase: Phase = .choosing
    var unit: ExportUnit = .perClip
    let sessionID: UUID

    init(sessionID: UUID, library: Library, exporter: Exporter)
    var canExport: Bool                     // record exists, deck resolves, manifest non-empty, not already exporting
    func start(_ destination: ExportDestination)   // no-op unless canExport and phase is .choosing/.finished/.failed
    func cancel()                           // cancels the running task
    func shareDismissed() async             // exporter.discard(result); phase .finished(summary)
}
```

- `start`: `library.beginExport(sessionID)`, phase `.running(0, 0)`, then one stored `Task` that
  calls `exporter.export(entries: record.manifest, deck:, sessionDate: record.startedAt, unit:,
  destination:, progress:)`. The progress closure hops to the main actor and only ever
  **increases** `done` (hops can reorder). Outcomes: `.files` success → `.sharing(result)`;
  `.photos` success → `.finished(summary)`; any thrown `ExportFailure` → `.failed(userMessage)`
  (cancellation arrives as `.cancelled`, whose message already says "Your recordings are
  unchanged."). `library.endExport` on every exit **except** `.sharing`, where `shareDismissed`
  calls it.
- **Summary** = `UICopy.exportDone(destination:count:)` + (if `dropped` non-empty)
  `" " + UICopy.droppedNote(count)` + (if `flaggedSegmentIDs` non-empty) `" " +
  UICopy.flaggedNote`.

## 6. Screens — `StoryCue/Views/`

All text through `UICopy`, Dynamic Type text styles only, every button labelled with its visible
text, 44 pt minimum targets — the S2a rules.

- **`StoryCueApp`**: `.task { await model.library.load() }` on the root view.
- **`DeckPickerView`**: a trailing toolbar button `UICopy.libraryButton` that pushes
  `LibraryView(model:)`; when `library.storage.isLow`, a first `Section` holding
  `StorageBanner`.
- **`ConsentView`**: the confirm button is also disabled while `!model.library.isLoaded`; when
  `storage.isLow`, `UICopy.lowSpaceConsentNote` in `.footnote` under the privacy note.
- **`StorageBanner`** (`StorageBanner.swift`): `UICopy.lowSpaceBanner(available)` with a warning
  symbol; no button.
- **`LibraryView(model:)`** (`LibraryView.swift`), a `List`:
  - When `recovered` is non-empty, a section headed `UICopy.recoveredHeader` with footer
    `UICopy.recoveredExplainer`. One row per clip: the deck title, `UICopy.questionCounter`
    (deck lookup; `questionID` if not found), the date, and two buttons `UICopy.keep` /
    `UICopy.deleteClip`. Delete asks first (`confirmationDialog`, `UICopy.deleteClipConfirm`,
    destructive `UICopy.deleteClip`).
  - A sessions section: one row per session — deck title (`.title2`), date + time
    (`.abbreviated` date, `.shortened` time), `UICopy.clipCount(record.manifest.count)`. Tapping
    pushes `SessionDetailView`. Swipe-to-delete only when `canDelete`, through the same kind of
    dialog (`UICopy.deleteSessionConfirm`, destructive `UICopy.deleteSession`).
  - Empty state (no sessions, no recovered): `ContentUnavailableView` with
    `UICopy.libraryEmptyTitle` / `UICopy.libraryEmptyBody`.
  - Footer: `UICopy.storageFooter(used:available:)`.
  - Navigation title `UICopy.libraryTitle`. `.onAppear { library.refreshStorage() }`.
- **`SessionDetailView(sessionID:model:)`**: reads `library.record(id:)` live (it may be deleted
  out from under it → shows `UICopy.sessionGone` and nothing else). One row per clip, in order:
  `UICopy.questionCounter` + the question text (`.body`), a `UICopy.mayBeIncomplete` caption when
  any segment is `.failed(kept: true)`, and `UICopy.recoveredUndecided` with Keep/Delete for a
  `nil` segment. Clips with only `.failed(kept: false)` segments are not shown. Toolbar:
  `UICopy.export` (disabled unless `ExportModel.canExport`) presenting `ExportView` as a sheet. A
  destructive `UICopy.deleteSession` button at the bottom (disabled unless `canDelete`, dialog
  first); after a successful delete, `dismiss()`.
- **`ExportView(model: ExportModel)`** (sheet, `NavigationStack` with title `UICopy.exportTitle`):
  - `.choosing`: a `Picker` (`.segmented`) bound to `unit`: `UICopy.exportEachAnswer` (`.perClip`)
    / `UICopy.exportOneVideo` (`.wholeSession`); buttons `UICopy.exportToFiles` (`.files`) and
    `UICopy.exportToPhotos` (`.photos`).
  - `.running`: `ProgressView(value:total:)` (indeterminate while total == 0),
    `UICopy.exporting(done, total)`, button `UICopy.cancel` → `cancel()`.
  - `.sharing`: `.sheet` presenting `ShareSheet(items: result.files) { Task { await
    model.shareDismissed() } }`.
  - `.finished` / `.failed`: the message, button `UICopy.done` → `dismiss()`.
  - `.interactiveDismissDisabled(phase is .running)`; `.onDisappear`: running → `cancel()`.
- **`ShareSheet`** (`ShareSheet.swift`): `UIViewControllerRepresentable` wrapping
  `UIActivityViewController(activityItems: items, applicationActivities: nil)`;
  `completionWithItemsHandler` calls `onComplete` exactly once (completed or cancelled).

## 7. `UICopy` additions (exact text)

| Key | Text |
|---|---|
| `libraryButton` / `libraryTitle` | "Recordings" / "Recordings" |
| `libraryEmptyTitle` / `libraryEmptyBody` | "No recordings yet" / "Choose a deck to record your first conversation." |
| `clipCount(_ n: Int)` | n == 1 ? "1 answer" : "\(n) answers" |
| `storageFooter(used: Int64, available: Int64?)` | "Recordings use \(fileSize(used))." + (available: " \(fileSize(a)) free on this iPhone.") — `ByteCountFormatter`, `.file` style |
| `lowSpaceBanner(_ available: Int64?)` | "Your iPhone is almost full (\(fileSize) free). Long answers may not fit." (no figure when nil: "Your iPhone is almost full. Long answers may not fit.") |
| `lowSpaceConsentNote` | "Your iPhone is low on space. Free some up before a long conversation." |
| `recoveredHeader` | "Recovered clips" |
| `recoveredExplainer` | "StoryCue closed while these were recording. They may end early. Keep them or delete them." |
| `recoveredUndecided` | "Recovered after StoryCue closed. It may end early." |
| `keep` | "Keep" |
| `deleteClip` / `deleteClipConfirm` | "Delete clip" / "Delete this clip? This can't be undone." |
| `deleteSession` / `deleteSessionConfirm` | "Delete recording" / "Delete this whole recording? This can't be undone." |
| `sessionGone` | "This recording was deleted." |
| `mayBeIncomplete` | "Part of this answer may be incomplete." |
| `export` / `exportTitle` | "Export" / "Export" |
| `exportEachAnswer` / `exportOneVideo` | "Each answer" / "One video" |
| `exportToFiles` / `exportToPhotos` | "Save or share…" / "Save to Photos" |
| `exporting(_ done: Int, _ total: Int)` | total == 0 ? "Preparing…" : "Exporting \(done) of \(total)…" |
| `exportDone(destination: ExportDestination, count: Int)` | `.photos`: count == 1 ? "Saved 1 video to Photos." : "Saved \(count) videos to Photos."; `.files`: count == 1 ? "Exported 1 video." : "Exported \(count) videos." |
| `droppedNote(_ n: Int)` | n == 1 ? "1 part couldn't be read and was left out." : "\(n) parts couldn't be read and were left out." |
| `flaggedNote` | "Part of this export may be incomplete." |

`ExportFailure.userMessage` stays where S3 put it.

## 8. Tests — `StoryCueTests/` (Part A)

Disk tests use a fresh temp directory per test, removed in `tearDown`. Library/ExportModel tests
build a real `SessionIndex` and `SegmentLedger` there and an `Exporter` over `MockStitcher` /
`MockPhotoLibrary` (`ExportTestDoubles.swift`), with `fileSize` reading real files the test
writes (a few bytes of junk are enough; the mock stitcher doesn't read them).

`SessionIndexTests.swift`: `testLoadMissingFileIsEmpty`, `testSaveLoadRoundTrip`,
`testSaveLeavesNoTempFile`, `testUndecodableFileThrows`, `testQuarantineMovesFileAside` (new
name matches `session-index.unreadable-*.json`, original gone, contents identical).

`SegmentLedgerTests.swift` (add): `testRemoveDropsOnlyNamedEntries`,
`testAllEntriesReturnsEveryStatus`.

`ExportManifestClipsTests.swift`: `testManifestForClipsMatchesState` (same result through both
overloads for a state with saved, kept-failed, unkept-failed and nil segments).

`SessionStoreTests.swift` (add): `testArchiveCalledAfterCaptureStart` (after `.tapRecord` +
drain, the archive received clips containing the new segment, and the mock's start count is 1
before the first archive call — record order with a shared array), `testArchiveCalledOnPersistLedger`
(after a simulated finish, the last archive call's segment has a non-nil outcome),
`testNoArchiveClosureIsFine`.

`LibraryTests.swift` (`@MainActor`):

| Test | Asserts |
|---|---|
| `testCheckpointCreatesUnfinishedRecord` | one record, `isFinished == false`, persisted after `waitForPendingSaves` |
| `testCheckpointIgnoresEmptyClips` | no record |
| `testCheckpointKeepsFinishedFlag` | an unfinished record on disk, `load()` finishes it, then `checkpoint` for that ID (not closed) → clips replaced, `isFinished` still true |
| `testCheckpointAfterFinishIgnored` | finish(id), then checkpoint(id) → record unchanged (still finished) |
| `testFinishMarksFinished` | `isFinished == true`, clips replaced |
| `testFinishWithNothingKeptDeletesSession` | only `.failed(kept: false)` segments → no record, their files gone, ledger entries gone |
| `testLoadFinalizesInterruptedSession` | an unfinished record on disk → finished after `load()` |
| `testLoadKeepsNilOutcomeWithFileAsRecovered` | appears in `recovered` |
| `testLoadMarksNilOutcomeWithoutFileFailed` | outcome `.failed(kept: false)`, ledger entry `.finished`, not in `recovered` |
| `testLoadSynthesizesRecordFromUnindexedLedgerEntries` | two entries, same deck, same day, different questions → one record, two clips in `startedAt` order, `.writing` one recovered |
| `testLoadSkipsUnindexedEntryWithoutFileOrDeck` | missing file → no record; unknown questionID → no record |
| `testLoadQuarantinesUnreadableIndex` | garbage index → moved aside, library rebuilt from ledger |
| `testLoadPurgesStaleExports` | a dir under `<tempRoot>/Exports/` is gone |
| `testLoadIsIdempotent` | second `load()` → identical `sessions` |
| `testKeepFlagsClip` | outcome `.failed(kept: true)`, ledger `.finished`, gone from `recovered`, present in `manifest` |
| `testDiscardRemovesFileAndLedgerEntry` | file gone, ledger entry gone, outcome `.failed(kept: false)` |
| `testDiscardLastClipDeletesSession` | the record is gone |
| `testDeleteRemovesFilesLedgerAndRecord` | all three gone; `true` |
| `testDeleteRefusedForActiveSession` | `false`, nothing changed |
| `testDeleteRefusedWhileExporting` | `beginExport` → `false`; `endExport` → `true` |
| `testStorageLowBelowThreshold` | capacity 999_999_999 → `isLow`; 1_000_000_000 → not; nil → not |
| `testStorageCountsMovFilesOnly` | `.mov` sizes summed, the index/ledger JSON excluded |
| `testSessionsNewestFirst` | ordering |
| `testRecordsPersistAcrossInstances` | a second `Library` over the same directory loads the same sessions |

`ExportModelTests.swift` (`@MainActor`):

| Test | Asserts |
|---|---|
| `testCanExportFalseWithNothingSaved` | a record whose only segment is nil-outcome → false |
| `testFilesExportGoesToSharing` | `.sharing`, files count = manifest entries (perClip) |
| `testShareDismissedDiscardsTempDirectory` | result directory gone; phase `.finished`; not exporting |
| `testPhotosExportFinishesWithCount` | `.finished("Saved 2 videos to Photos.")` for two clips |
| `testPhotosDeniedShowsMessage` | `MockPhotoLibrary(status: .denied)` → `.failed(ExportFailure.photosDenied.userMessage)` |
| `testCancelShowsCancelledMessage` | stitcher delay + `cancel()` → `.failed(ExportFailure.cancelled.userMessage)` |
| `testExportingFlagClearedOnFailure` | after a failure, `exportingSessionIDs` empty |
| `testSummaryIncludesDroppedAndFlagged` | an unreadable source + a kept-failed segment → both notes in the summary |

`AppModelTests.swift` (add): `testBeginSessionSetsLibraryActiveID`,
`testRecordingCheckpointsIntoLibrary` (tapRecord + drain → one unfinished record),
`testEndSessionFinishesRecord` (after a saved segment → `isFinished`, `activeSessionID == nil`),
`testEndSessionWithNoClipsLeavesNoRecord`.

`UICopyTests.testNoCopyContainsTODO` already scans `UICopy.swift`; add
`testClipCountPlural` ("1 answer", "2 answers") and `testExportingPreparingAtZero`.

## Part B — screenshot UI test (second dispatch)

**Screenshot size, verified 2026-10-02** against Apple's "Screenshot specifications" page: an
iPhone app needs **either** a 6.9" set **or** a 6.5" set, and App Store Connect scales the one
you give to the other. STRATEGY's "6.9" and 6.5"" pair is out of date. **One 6.9" set**:
iPhone 17 Pro Max simulator, portrait 1320 × 2868.

- **Demo launch mode (DEBUG only, `#if DEBUG` in `StoryCueApp`)**: launch argument
  `-StoryCueDemo` → `AppModel.demo()`: a temp segment directory, `MockCaptureService` (authorized,
  ready), and a `Library` pre-seeded with two finished records (`grandparents`, three saved
  clips; `holiday-table`, five) whose segment files are a few junk bytes (export isn't
  exercised). Release builds contain none of it: every demo path sits inside `#if DEBUG`, the
  existing Release compile proves it builds without them, and the Done-when grep checks the
  guard.
- **Open item for Perry (default chosen, swap before S6 if you want):** the simulator has no
  camera, so the recorder screenshot's preview area is black. **Default:** in demo mode only,
  `CameraPreview` is replaced by a soft dark warm gradient (no stock photo, no fake person).
  Alternative: a real device screenshot of the recorder, taken by Perry at S5 and uploaded
  by hand in place of this one.
- **Target `StoryCueUITests`** (`bundle.ui-testing`, `TEST_TARGET_NAME: StoryCue`), in its own
  scheme **`StoryCueScreenshots`** — not in the `StoryCue` scheme, so the baseline and Duo lanes
  don't start running UI tests.
- **`ScreenshotTests.swift`**: `testCaptureAppStoreScreenshots` launches with `-StoryCueDemo` and
  attaches (`XCTAttachment`, `.keepAlways`, names fixed) five screenshots:
  `01-decks` (deck picker), `02-consent` (Grandparents consent card), `03-recorder` (after "We're
  ready", idle on question 1), `04-library` (Recordings), `05-session` (the Grandparents detail).
  Each step waits on an element by accessibility label with `waitForExistence(timeout: 10)` and
  fails with the screen name if it's missing.
- **CI (`build.yml`, new job `screenshots`, after the baseline job, push-to-main and
  `workflow_dispatch` only)**: boot "iPhone 17 Pro Max" (fail with the `simctl list devices`
  output if absent), `xcrun simctl status_bar booted override --time "9:41" --batteryState
  charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`, run `xcodebuild test -scheme
  StoryCueScreenshots -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -resultBundlePath
  $RUNNER_TEMP/shots.xcresult`, export attachments with `xcrun xcresulttool export attachments
  --path … --output-path $RUNNER_TEMP/shots`, assert five PNGs at 1320 × 2868 (`sips -g
  pixelWidth -g pixelHeight`), upload as artifact `asc-screenshots-6.9`. Same Xcode selection
  (`select-xcode.sh`) as the baseline job.
- **Part B tests**: `testCaptureAppStoreScreenshots` only. **Done when** the artifact holds five
  1320 × 2868 PNGs and `grep -n "StoryCueDemo" StoryCue/StoryCueApp.swift` shows every use inside
  `#if DEBUG`.

## Kimi layout review (after Part A's implement run, before Sol)

Same checklist as S2a, over `LibraryView`, `SessionDetailView`, `ExportView`, `StorageBanner`:
largest accessibility Dynamic Type doesn't clip or push the Keep/Delete/Export/Cancel controls
off screen; 44 pt targets; no fixed heights; every destructive action has a confirmation; the
export sheet can't be swiped away mid-export. Findings, not edits.

## Sol audit focus (Part A)

Data-loss paths only: decision 4 (reconciliation never deletes a file that has bytes; a corrupt
index is quarantined, not overwritten), decision 5 (delete order, refusal rules), decision 3
(late checkpoints can't resurrect a finished/deleted session), and that nothing in the export
path deletes from the segment directory (`testExportNeverTouchesSegmentDirectory` still passes).

## Do not

- No Duo code, no `#if DUO_SDK` additions; no change to `SessionMachine.reduce`.
- No deletion of any segment file outside `Library.delete` / `Library.discard` / the
  nothing-kept branch of `Library.finish`.
- No reading of `SegmentOutcome.saved(url:)` — paths come from `SegmentFiles`.
- No `ShareLink` for exports (decision 7).
- No `@unchecked Sendable`, `nonisolated(unsafe)`, `try!`, `as!`, `Task.detached`.
- `SessionStore` still never imports AVFoundation/UIKit/SwiftUI.
- No string literal shown to the user outside `UICopy` (and S3's `ExportFailure.userMessage`).
- No AI attribution trailers.

## Done when (Part A)

CI green (Build & Test + Release compile); every S1/S2a/S3/S4 test still passes; the new tests
(5 + 2 + 1 + 3 + 24 + 8 + 4 + 2 = 49) run and pass; and these greps are empty:
`grep -rnE "try!|as!|Task\.detached|unchecked Sendable|nonisolated\(unsafe\)" StoryCue/ StoryCueTests/`,
`grep -rn "\.system(size:" StoryCue/`,
`grep -rnE "import (AVFoundation|UIKit|SwiftUI)" StoryCue/SessionStore.swift`,
`grep -rn "ShareLink" StoryCue/`,
`grep -rn "removeItem" StoryCue/ | grep -vE "Library.swift|Exporter.swift|Stitcher.swift"`
(the Exporter/Stitcher hits are S3's temp-directory cleanup, never the segment directory).
Kimi layout findings and Sol's audit are adjudicated by the boss; edits they call for are boss
follow-up commits. Device verification (export a multi-segment clip to Files and to Photos, then
play it; kill the app mid-answer and confirm the recovered clip appears; delete a recording and
watch storage drop) is **S5 rung 4b-export**, not this step.
