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
   omitted-not-empty rule. A segment is **keep-worthy** if its outcome is `.saved`,
   `.failed(kept: true)` or `nil` (undecided — never deleted without the user). A checkpoint with
   zero clips is ignored. `finish` on a session with no keep-worthy segment leaves no record:
   it removes only the files of its `.failed(kept: false)` segments and their ledger entries.
   Deleting those without a prompt is intended — the reducer already judged them unusable and
   `exportManifest` already excludes them. A late checkpoint for a finished or deleted session
   is ignored (`closedSessionIDs`), because `endSession()` can return while a `.persistLedger`
   effect is still queued.
4. **Launch reconciliation (`Library.load()`).** It returns immediately if `isLoaded` is
   already true or `activeSessionID != nil`. It works on **local copies** and assigns `sessions`
   in one synchronous step after its last await, so nothing the user does can be overwritten —
   and nothing can be done meanwhile: until `isLoaded`, every mutating `Library` method is a
   no-op (`delete` returns false), the deck picker's Recordings button is disabled, and the
   consent button is disabled. Exactly these rules, in this order:
   1. `await exporter.purgeStaleExports()` (S3 hand-off; nothing can be exporting at launch).
   2. Load the index. If it fails with a `DecodingError`, **move the file aside** to
      `session-index.unreadable-<yyyyMMdd-HHmmss>-<first 8 of a UUID>.json` in the same directory
      (never overwrite or delete it) and continue with `[]`; step 5 rebuilds what it can from the
      ledger. If it fails with any other error (I/O), leave the file alone, set the private
      `savesSuspended = true` (no index save happens for the rest of this launch, so a good index
      is never clobbered), skip steps 3–5 and finish at step 6 with `[]`.
   3. Every record with `isFinished == false` (an app kill mid-session) → `isFinished = true`.
   4. Every segment with `outcome == nil` in a record: if its file has size > 0 it stays `nil` —
      that is a **recovered clip**, shown for the user to keep or delete. If the file is missing
      or empty → `outcome = .failed(kept: false)` and `ledger.markFinished(id)`.
   5. **Ledger entries no record mentions** (a crash before the first checkpoint, or an index
      lost in step 2). If `ledger.allEntries()` throws, skip this step. Otherwise take only
      entries whose file has size > 0 and whose `questionID` belongs to a v1 deck. Group them by (deck, calendar day of `startedAt` in `Calendar.current`) into
      one synthesized record per group: `id` new, `deckTitle` from the deck, `startedAt` = the
      earliest entry, clips grouped by `questionID` ordered by each clip's first `startedAt`,
      segments ordered by `startedAt`, `endReason nil`, outcome **`.failed(kept: true)`** for
      `.finished` entries (the ledger doesn't store outcomes, and a `.finished` entry may have
      been an unkept failure — so it exports flagged "may be incomplete", never silently as
      clean) and `nil` (recovered) for `.writing` / `.orphaned`, `isFinished = true`. Entries with
      no file or no matching deck are left untouched.
   6. Sort newest `startedAt` first; assign `sessions`; save if anything changed;
      `refreshStorage()`; `isLoaded = true`.

   The UI calls `load()` once at launch. **Accepted gaps (IDEAS, not this step):** a `.mov` in
   the segment directory with neither a ledger entry nor a record (the `try? ledger.record` in
   `.startSegment` failed) stays invisible but is counted in `usedBytes`; a `.saved` segment
   whose ledger entry is still `.writing` (crash between the reducer and `.persistLedger`) is
   left as is. `SessionStore.recoverOrphans()` / `recoveredSegments` stay in place, unused by
   the UI, with their S1 tests.
5. **Delete order: files → verify → ledger → index.** A crash mid-delete leaves at worst a
   record whose files are gone (the planner drops them as `.missingFile`, and the user can
   delete again) — never invisible files eating space that nothing points to. If any file
   still exists after the removal attempts (`fileSize` non-nil), the delete **aborts** before
   touching the ledger or the index and returns false. **Refused** for the active session and
   for a session with an export in flight; while a delete runs, the session is in
   `deletingSessionIDs` and no export can start on it. Every delete in the UI goes through a
   confirmation dialog. This is the first code that deletes a segment, so S3's "your recordings
   are safe" copy now depends on this rule: **the export path still never deletes**; only
   `Library.delete` and `Library.discard` do.
6. **`SegmentLedger` gains two methods** (`remove`, `allEntries`). S2a's "no ledger changes" rule
   is lifted for exactly these two; `record` / `markFinished` / `orphanedEntries` are unchanged.
7. **Share sheet = a `UIActivityViewController` representable**, not `ShareLink`: its
   `completionWithItemsHandler` is the only dismissal hook, and it calls
   `exporter.discard(result)` so the temp directory goes as soon as the sheet closes (Save to
   Files is in that sheet). Photos exports discard themselves (S3).
8. **Low space = under 1 GB available** (`StorageStatus.lowSpaceThreshold = 1_000_000_000`), read
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
    static let lowSpaceThreshold: Int64 = 1_000_000_000   // on the struct, not the @MainActor class
    let usedBytes: Int64            // sum of *.mov sizes in the segment directory
    let availableBytes: Int64?      // nil when the volume won't say
    var isLow: Bool { availableBytes.map { $0 < Self.lowSpaceThreshold } ?? false }
}

struct RecoveredClip: Equatable, Identifiable, Sendable {
    let sessionID: UUID
    let segment: Segment            // outcome == nil
    var id: UUID { segment.id }
}

@MainActor @Observable
final class Library {
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
    func finish(sessionID: UUID, deck: Deck, startedAt: Date, clips: [Clip]) async   // decision 3
    func keep(_ clip: RecoveredClip) async               // outcome .failed(kept: true); ledger.markFinished
    func discard(_ clip: RecoveredClip) async            // delete file; outcome .failed(kept: false); ledger.remove
    func canDelete(_ sessionID: UUID) -> Bool           // loaded, not active, not exporting, not deleting
    func canStartExport(_ sessionID: UUID) -> Bool      // loaded, not active, not exporting, not deleting
    @discardableResult func delete(sessionID: UUID) async -> Bool   // decision 5
    func beginExport(_ sessionID: UUID)                  // no-op unless canStartExport
    func endExport(_ sessionID: UUID)
    func refreshStorage()
    func record(id: UUID) -> SessionRecord?
    /// Test hook: resumes when every queued save has finished.
    func waitForPendingSaves() async
    #if DEBUG
    /// Part B demo only: sets `sessions` directly and `isLoaded = true` (so `load()` no-ops). No save.
    func seedForDemo(_ records: [SessionRecord])
    #endif
}
```

Private state: `closedSessionIDs: Set<UUID>`, `deletingSessionIDs: Set<UUID>`,
`savesSuspended: Bool`, `saveTask: Task<Void, Never>?`, and `deleteUnchecked(sessionID:) async ->
Bool` (decision 5's steps without the `canDelete` check; `delete` calls it after the check).

Rules:
- **Saves are serial and ordered.** Every mutation updates `sessions` synchronously on the main
  actor, then enqueues `index.save(snapshot)` with the snapshot taken at that moment, chained
  after the previous save (`let previous = saveTask; saveTask = Task { await previous?.value;
  try? await index.save(snapshot) }`). A failed save is not retried (the next mutation saves the
  whole array again). Nothing is saved while `savesSuspended`.
- `checkpoint`: ignored if `clips` is empty or the ID is in `closedSessionIDs`. Otherwise insert
  `SessionRecord(id:deckID:deckTitle:startedAt:clips:isFinished: false)` or replace an existing
  record's `clips` **keeping its `isFinished`**.
- `finish`: inserts the ID into `closedSessionIDs` before its first await. If `clips` has a
  keep-worthy segment (decision 3) → set `clips` and `isFinished = true`, inserting the record
  (from `deck` / `startedAt`) if no checkpoint ever landed. Otherwise → remove the record if
  present, `try?`-remove the files of the `.failed(kept: false)` segments, and
  `ledger.remove(segmentIDs:)` for every listed segment.
- `keep` / `discard`: no-op unless the session isn't active and the segment's outcome is
  **still `nil` at call time** (re-read from `sessions`). `discard`: after it, if the record has no
  keep-worthy segment left → `deleteUnchecked(sessionID:)`.
- `delete`: refuses (false, no change) when `canDelete` is false. `deleteUnchecked`: insert into
  `deletingSessionIDs`; `try?`-remove every segment file; if any `fileSize(url)` is still
  non-nil → remove from `deletingSessionIDs`, return false; else `ledger.remove(segmentIDs:)`
  (`try?`), drop the record from `sessions`, save, `refreshStorage()`, remove from
  `deletingSessionIDs`, true.
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
  `archive: { [weak library = self.library] clips in library?.checkpoint(sessionID: id,
  deck: deck, startedAt: startedAt, clips: clips) }` to the store, sets
  `library.activeSessionID = id`. Everything else unchanged.
- `endSession()`: the refusal checks, `store.stop()` and `active = nil` stay synchronous before
  the first await (S2a rule). Capture `id`, `deck`, `startedAt` and `store.state.clips` into
  locals first, all before the first await; then `await capture.shutdown()` (release the camera
  first), then `await library.finish(...)`, and only then clear `library.activeSessionID` (if it
  still equals `id`). That tail runs as a stored `ending` task, and `beginSession` awaits it
  first, so a new session can't replace the protected ID or overlap the old camera. Amended
  2026-10-02 after the Sol audit: clearing it before the awaits let a delete or discard during
  shutdown be undone by `finish`. The
  local clips are final: `endSession` only proceeds from `.idle`/`.paused`, which the reducer
  reaches only after `fileOutputFinished` has set the outcome; a still-queued `.persistLedger`
  only writes the ledger.

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
    var canExport: Bool                     // record exists, deck resolves, manifest non-empty, library.canStartExport
    func start(_ destination: ExportDestination)   // no-op unless canExport and phase is .choosing/.finished/.failed
    func cancel()                           // cancels the running task
    func shareDismissed() async             // exporter.discard(result); phase .finished(summary)
}
```

- `start`: `library.beginExport(sessionID)`, phase `.running(0, 0)`, then one stored `Task` that
  calls `exporter.export(entries: record.manifest, deck:, sessionDate: record.startedAt, unit:,
  destination:, progress:)`. The progress closure hops to the main actor and applies **only
  `if case .running = phase`**, keeping the max `done` seen (hops can reorder, and a late hop
  must not drag `.sharing`/`.finished` back to `.running`). Outcomes: `.files` success → `.sharing(result)`;
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
- **`DeckPickerView`**: a trailing toolbar button `UICopy.libraryButton`
  (`.accessibilityIdentifier("libraryButton")`, disabled until `library.isLoaded`) that pushes
  `LibraryView(model:)`; when `library.storage.isLow`, a first `Section` holding
  `StorageBanner`.
- **Question labels everywhere in S2b**: `i = deck.questions.firstIndex { $0.id == questionID }`
  → `UICopy.questionCounter(i, deck.questions.count)` plus the question text; if the deck or
  question isn't found → `UICopy.unknownQuestion` and no text (never a raw ID).
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
    pushes `SessionDetailView`. Delete by `.swipeActions(allowsFullSwipe: false)` with a
    `Button(role: .destructive)` (only when `canDelete`) that only sets `@State pendingDelete`;
    the `confirmationDialog` (`UICopy.deleteSessionConfirm`, destructive `UICopy.deleteSession`)
    is driven by that state. No `.onDelete` (a full swipe would skip the dialog).
  - Empty state (no sessions, no recovered): `ContentUnavailableView` with
    `UICopy.libraryEmptyTitle` / `UICopy.libraryEmptyBody`.
  - Footer: `UICopy.storageFooter(used:available:)`.
  - Navigation title `UICopy.libraryTitle`. `.onAppear { library.refreshStorage() }`.
- **`SessionDetailView(sessionID:model:)`**: reads `library.record(id:)` live (it may be deleted
  out from under it → shows `UICopy.sessionGone` and nothing else). One row per clip, in order:
  `UICopy.questionCounter` + the question text (`.body`), a `UICopy.mayBeIncomplete` caption when
  any segment is `.failed(kept: true)`, and `UICopy.recoveredUndecided` with Keep/Delete for a
  `nil` segment — **hidden when `sessionID == library.activeSessionID`** (that `nil` is a live
  recording). Clips with only `.failed(kept: false)` segments are not shown. The view owns
  `@State private var exportModel: ExportModel?`; toolbar `UICopy.export` (disabled unless a
  fresh `ExportModel(...).canExport`) sets it, and `.sheet(isPresented:)` bound to
  `exportModel != nil` presents `ExportView(model:)`, clearing it on dismiss. A destructive
  `UICopy.deleteSession` button at the bottom (disabled unless `canDelete`, dialog first);
  after a successful delete, `dismiss()`.
- **`ExportView(model: ExportModel)`** (sheet, `NavigationStack` with title `UICopy.exportTitle`):
  - `.choosing`: a `Picker` (`.segmented`) bound to `unit`: `UICopy.exportEachAnswer` (`.perClip`)
    / `UICopy.exportOneVideo` (`.wholeSession`); buttons `UICopy.exportToFiles` (`.files`) and
    `UICopy.exportToPhotos` (`.photos`).
  - `.running`: `ProgressView(value:total:)` (indeterminate while total == 0),
    `UICopy.exporting(done, total)`, button `UICopy.cancel` → `cancel()`.
  - `.sharing`: `.sheet` presenting `ShareSheet(items: result.files) { Task { await
    model.shareDismissed() } }`.
  - `.finished` / `.failed`: the message, button `UICopy.done` → `dismiss()`.
  - `.interactiveDismissDisabled(phase is .running)`; `.onDisappear`: `.running` → `cancel()`;
    `.sharing` → `Task { await model.shareDismissed() }` (so the temp directory and the
    exporting flag never outlive the sheet). `shareDismissed` is a no-op unless phase is
    `.sharing`, so the share sheet's own callback and this one can't double-discard.
- **`ShareSheet`** (`ShareSheet.swift`): `UIViewControllerRepresentable` wrapping
  `UIActivityViewController(activityItems: items, applicationActivities: nil)`;
  `completionWithItemsHandler` calls `onComplete` exactly once (completed or cancelled).

## 7. `UICopy` additions (exact text)

| Key | Text |
|---|---|
| `fileSize(_ bytes: Int64) -> String` | `ByteCountFormatter`, `.file` count style (helper used by the two below) |
| `unknownQuestion` | "A question" |
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

`SessionStoreTests.swift` (add): `testArchiveCalledAfterCaptureStart` — a test-local
`OrderProbe` (`@MainActor final class` holding `var log: [String]`) and a test-local
`CaptureService` wrapper around `MockCaptureService` whose `startSegment` forwards and then
appends `"start"` via `await MainActor.run`; the `archive` closure appends `"archive"`. After
`.tapRecord` + drain: `log == ["start", "archive"]` and the archived clips contain the new
segment. `testArchiveCalledOnPersistLedger`
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
| `testFinishWithNothingKeepWorthyLeavesNoRecord` | only `.failed(kept: false)` segments → no record, their files gone, ledger entries gone |
| `testFinishKeepsNilSegmentWithBytes` | one `nil`-outcome segment with a file → record kept, file still there |
| `testLoadFinalizesInterruptedSession` | an unfinished record on disk → finished after `load()` |
| `testLoadKeepsNilOutcomeWithFileAsRecovered` | appears in `recovered` |
| `testLoadMarksNilOutcomeWithoutFileFailed` | outcome `.failed(kept: false)`, ledger entry `.finished`, not in `recovered` |
| `testLoadSynthesizesRecordFromUnindexedLedgerEntries` | two entries (fixed **noon** timestamps on one day, so no midnight flake), same deck, different questions → one record, two clips in `startedAt` order; the `.finished` one is `.failed(kept: true)`, the `.writing` one recovered |
| `testLoadSkipsUnindexedEntryWithoutFileOrDeck` | missing file → no record; unknown questionID → no record |
| `testLoadQuarantinesUnreadableIndex` | garbage index → moved aside, library rebuilt from ledger |
| `testLoadPurgesStaleExports` | a dir under `<tempRoot>/Exports/` is gone |
| `testLoadIsIdempotent` | second `load()` → identical `sessions` |
| `testLoadNoOpWhileSessionActive` | `activeSessionID` set before `load()` → `isLoaded` false, unfinished record untouched |
| `testLoadReadErrorSuspendsSaves` | `session-index.json` is a directory (read fails, not a decode error) → not moved, `sessions` empty, a later `checkpoint` writes nothing to disk |
| `testMutationsIgnoredBeforeLoad` | before `load()`: `delete` false, `checkpoint` adds nothing |
| `testKeepFlagsClip` | outcome `.failed(kept: true)`, ledger `.finished`, gone from `recovered`, present in `manifest` |
| `testDiscardRemovesFileAndLedgerEntry` | file gone, ledger entry gone, outcome `.failed(kept: false)` |
| `testDiscardLastClipDeletesSession` | the record is gone |
| `testDeleteRemovesFilesLedgerAndRecord` | all three gone; `true` |
| `testDeleteAbortsWhenFileRemains` | a `fileSize` stub that keeps reporting one segment → `false`, ledger entries and record intact, not in `deletingSessionIDs` |
| `testKeepRefusedForActiveSession` | `activeSessionID` = that session → outcome still `nil` |
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
iPhone 17 Pro Max simulator, portrait 1320 × 2868. **As built (PR #7): iPhone 18 Pro Max** — the iOS 27 runner image has no 17 Pro Max; output is still 1320 × 2868. `screenshots.yml` also runs on PRs touching `StoryCueUITests/**` or itself (Perry OK, 2026-10-03).

- **Demo launch mode (DEBUG only)**: launch argument `-StoryCueDemo` → `AppModel.demo()`
  (inside `#if DEBUG` in `AppModel.swift`; `StoryCueApp` picks it under `#if DEBUG`): a temp
  segment directory, `MockCaptureService` (authorized, ready), and `library.seedForDemo([...])`
  with two finished records (`grandparents`, three `.saved` clips; `holiday-table`, five) whose
  segment files are a few junk bytes written first (export isn't exercised). `seedForDemo` sets
  `isLoaded`, so the root `.task`'s `load()` is a no-op and the seed is never re-read from disk.
  Every demo path — `AppModel.demo()`, the `StoryCueApp` branch, the `RecorderView` preview swap
  below — sits inside `#if DEBUG`.
- **Open item for Perry (default chosen, swap before S6 if you want):** the simulator has no
  camera, so the recorder screenshot's preview area is black. **Default:** in demo mode only,
  `RecorderView` shows a soft dark warm `LinearGradient` instead of `CameraPreview` (no stock
  photo, no fake person); `AppModel` exposes `#if DEBUG var isDemo: Bool`. Alternative: a real
  device screenshot of the recorder, taken by Perry at S5 and uploaded by hand in place of
  this one.
- **Target `StoryCueUITests`** (`bundle.ui-testing`, `TEST_TARGET_NAME: StoryCue`,
  `PRODUCT_BUNDLE_IDENTIFIER: dev.pmartin1915.storycue.uitests`), in its own scheme
  **`StoryCueScreenshots`** (build StoryCue + StoryCueUITests, test StoryCueUITests) — not in
  the `StoryCue` scheme, so the baseline and Duo lanes don't start running UI tests.
- **`ScreenshotTests.swift`**: `testCaptureAppStoreScreenshots` launches with `-StoryCueDemo` and
  attaches (`XCTAttachment(screenshot:)`, `.keepAlways`, `name` fixed) five screenshots:
  `01-decks` (deck picker), `02-consent` (Grandparents consent card), `03-recorder` (after
  "We're ready", idle on question 1), `04-library` (Recordings, reached through the
  `libraryButton` accessibility identifier), `05-session` (the Grandparents detail). Each step
  waits on an element with `waitForExistence(timeout: 10)` and fails naming the screen.
- **CI: new workflow `.github/workflows/screenshots.yml`, `workflow_dispatch` only.**
  `build.yml` is PR-only by design and stays untouched; screenshots are needed once before S6
  and on demand after copy changes. One job on the same runner label as build.yml, with its own
  checkout, `select-xcode.sh` release Xcode, XcodeGen 2.46.0 install and `xcodegen generate`.
  Steps:
  1. Boot "iPhone 17 Pro Max" (fail printing `xcrun simctl list devices` if absent).
  2. `xcrun simctl status_bar booted override --time "9:41" --batteryState charged
     --batteryLevel 100 --cellularBars 4 --wifiBars 3`.
  3. `xcodebuild test -project StoryCue.xcodeproj -scheme StoryCueScreenshots -destination
     'platform=iOS Simulator,name=iPhone 17 Pro Max' -configuration Debug
     -parallel-testing-enabled NO -resultBundlePath "$RUNNER_TEMP/shots.xcresult"
     STORYCUE_DUO_CONDITIONS="" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
     CODE_SIGNING_ALLOWED=NO`.
  4. `xcrun xcresulttool export attachments --path "$RUNNER_TEMP/shots.xcresult" --output-path
     "$RUNNER_TEMP/raw"`; then a script reads `$RUNNER_TEMP/raw/manifest.json` and copies each
     attachment whose suggested name starts `01-`…`05-` to `$RUNNER_TEMP/shots/<name>.png` (the
     exported files are UUID-named; failure or automatic screenshots are ignored).
  5. Assert exactly those five exist at 1320 × 2868 (`sips -g pixelWidth -g pixelHeight`);
     upload `$RUNNER_TEMP/shots` as artifact `asc-screenshots-6.9`.
- **Part B tests**: `testCaptureAppStoreScreenshots` only. **Done when** a dispatched run's
  artifact holds the five named 1320 × 2868 PNGs, and every hit of
  `grep -rnE "StoryCueDemo|seedForDemo|isDemo|func demo" StoryCue/` sits inside an `#if DEBUG`
  block (the boss checks by reading each hit).

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
(5 + 2 + 1 + 3 + 30 + 8 + 4 + 2 = 55, every name visible in the `.xcresult`) run and pass;
and these greps are empty:
`grep -rnE "try!|as!|Task\.detached|unchecked Sendable|nonisolated\(unsafe\)" StoryCue/ StoryCueTests/`,
`grep -rn "\.system(size:" StoryCue/`,
`grep -rnE "import (AVFoundation|UIKit|SwiftUI)" StoryCue/SessionStore.swift`,
`grep -rn "ShareLink" StoryCue/`,
`grep -rn "removeItem" StoryCue/ | grep -vE "^StoryCue/(Library|Exporter|Stitcher)\.swift:"`
(the Exporter/Stitcher hits are S3's temp-directory cleanup, never the segment directory;
`StoryCueTests/` is deliberately not covered — tests clean their temp dirs).
Kimi layout findings and Sol's audit are adjudicated by the boss; edits they call for are boss
follow-up commits. Device verification (export a multi-segment clip to Files and to Photos, then
play it; kill the app mid-answer and confirm the recovered clip appears; delete a recording and
watch storage drop) is **S5 rung 4b-export**, not this step.

## Spec review (fresh-context Sonnet, 2026-10-02) — adjudication

20 findings; the spec above already reflects every accepted one.

- **Accepted (fixed in place):** 1 `finish` could delete a `nil`-outcome clip with bytes (now
  keep-worthy; only `.failed(kept: false)` files go); 2 `load()` racing user mutations (local
  copies + single assignment, mutations no-op and Recordings disabled until loaded, no-op while
  a session is active); 3 `finish` lacked the fields to insert a record (now takes
  `deck`/`startedAt`); 4 `delete` could drop the ledger/record after a failed file removal
  (verify-then-abort); 5 synthesis promoted unkept failures to `.saved` (now
  `.failed(kept: true)`); 6 export could start mid-delete (`deletingSessionIDs`,
  `canStartExport`); 7 late progress hops (apply only while `.running`); 8 unwritable
  archive-order test (`OrderProbe` + wrapper); 9 Part B CI (own `workflow_dispatch` workflow,
  full xcodebuild flags, manifest-based renaming, no parallel testing); 10 Swift 6 (threshold on
  `StorageStatus`, `[weak library = self.library]`); 11 demo seeding (`seedForDemo`, widened
  guard check); 12 edge cases (quarantine only on `DecodingError`, I/O error suspends saves,
  UUID suffix, ledger read failure skips synthesis, untracked `.mov` named as an accepted gap);
  13 Keep/Delete hidden and refused for the active session; 14 no full-swipe delete; 15
  `ExportModel` ownership and `.sharing` teardown; 16 question-label derivation,
  `unknownQuestion`, `fileSize` helper, `libraryButton` identifier; 17 grep escaping and test
  names visible in `.xcresult`; 18 `deleteUnchecked`, camera released before `finish`; 19 noon
  timestamps; 20 `recoverOrphans` stays unused, `.saved`-with-`.writing` left as is.
- **Not taken:** 19's second half (only `production()` should build the real `AVStitcher` /
  `PHPhotoLibrarySaver`). Constructing them touches no hardware, and changing the default
  would churn every existing `AppModelTests` call site for no behavior gain.
