# S2b storage sweep spec — close the three deferred byte leaks

_Written 2026-10-02. Follow-up to `docs/S2B-LIBRARY-SPEC.md` (Part A merged, PR #6). Closes the
three 2026-10-02 `ai/IDEAS.md` entries that were deferred because they leak bytes but never
lose a recording. Touches `Library`, `SessionIndex`, `SegmentLedger`, `UICopy` and tests only.
**Not on the recording path:** no `RecorderView`, `SessionStore`, `SessionMachine`, capture
service or `AppModel` change._

## The data-loss invariant (the one rule this spec is built on)

> **The sweep may delete only a file it can prove is not part of any kept session.**

A file is *provably not kept* in exactly three cases, and **no others**:

1. **Verdict.** It is the `<id>.mov` of a segment whose outcome is `.failed(kept: false)` — the
   reducer judged it unusable, `exportManifest` already excludes it, and the user was never
   offered it (S2b decision 3).
2. **Empty.** It is a `<UUID>.mov` that no index record references and whose size is exactly 0.
   There are no bytes to lose.
3. **Scratch.** It is a leftover `session-index.<UUID>.tmp` or `segment-ledger.<UUID>.tmp`
   (the atomic-save temp names). Nothing reads them.

Everything else is never deleted by the sweep: any file with bytes that is unreferenced
(it is **adopted** and shown, section 1), any file whose segment outcome is `.saved`,
`.failed(kept: true)` or `nil`, `session-index.json`, `segment-ledger.json`,
`session-index.unreadable-*.json`, and any name that does not match a pattern above.

Corollaries, each tested:
- **No proof, no delete.** The launch sweep is skipped entirely when the index or the ledger
  could not be read, or when `activeSessionID != nil` (a live recording's file may be 0 bytes
  and unreferenced for a moment). A `fileSize` that returns nil on a listed file means "can't
  tell" and the file is left alone.
- **Files first, ledger second.** A ledger entry is dropped only for a segment whose file is
  verified gone (`fileSize == nil` after the removal attempt). A file that survived keeps its
  entry, so the next launch's step 5 (or adoption) can still surface it.
- **Index-referenced bytes never vanish silently.** Deleting happens only after the in-memory
  records are final; the index save is enqueued first.

## Decisions made here (the executor does not re-decide these)

1. **Bare `.mov` with bytes is adopted, not deleted** (IDEAS entry a). After step 5, the launch
   sweep lists `*.mov` files whose name parses as a UUID and whose ID appears in no record.
   Non-empty ones become **one synthesized record**: `id` new, `deckID` `"unsorted"` (matches no
   deck, so `record.deck == nil` and export is not offered), `deckTitle`
   `UICopy.unsortedRecordingsTitle`, `startedAt` = the earliest file creation date (fallback
   `Date()`), one `Clip(questionID: "unknown")` with a segment per file (outcome `nil`,
   `endReason nil`, ordered by creation date), `isFinished = true`. The user sees them as
   recovered clips and decides keep / discard through the existing `keep` / `discard` paths
   (`discard` already deletes the record when nothing keep-worthy is left). This also
   surfaces the unreferenced-by-any-record case the old step 5 skips (a ledger entry whose
   question is in no v1 deck).
2. **Unkept failures are deleted at both seams** (IDEAS entry b). `Library.finish`, in the
   keep-worthy branch, deletes the files of that session's `.failed(kept: false)` segments
   after enqueuing the index save. The launch sweep does the same for every record, so
   already-leaked files and crash leftovers are cleaned. Ledger entries of verified-gone
   segments are dropped.
3. **`finish`'s nothing-kept branch drops a ledger entry only for a verified-gone file**
   (IDEAS entry c, part 1). Today `try? removeItem` can fail and the entry is dropped anyway,
   making the surviving `.mov` invisible; now the entry stays and the next launch recovers it.
4. **No stray temp on a failed save** (entry c, part 2). `SessionIndex.save` and
   `SegmentLedger.save` (identical code) delete their own temp file if the write, replace or
   move throws, then rethrow. The launch sweep also removes temps a crash left behind.
5. **Order inside `load()`:** the sweep runs after step 5 and before the step-6 assignment,
   synchronously (no await between its `activeSessionID` check and its deletions), on the local
   `records`. Its only await is the final `ledger.remove` for verified-gone IDs. It sets
   `changed = true` when it adopted anything, so the index is saved.

## Interfaces

`Library` (private, in `Library.swift`):
```swift
/// Deletes each segment's .mov; returns the IDs whose file is verifiably gone afterwards.
private func removeFiles(for ids: [UUID]) -> Set<UUID>
/// Launch sweep (decision 5). Mutates `records` (adoption); returns IDs safe to drop from the ledger.
private func sweepStorage(records: inout [SessionRecord]) -> (removedIDs: Set<UUID>, adopted: Bool)
```
`UICopy`: `static let unsortedRecordingsTitle = "Unsorted recordings"`.
`SegmentLedger.save` / `SessionIndex.save`: temp cleanup on throw (no signature change).

## Tests (new, in `LibraryTests`, `SessionIndexTests`, `SegmentLedgerTests`)

(a) bare `.mov`
- `testLoadDeletesZeroByteUnreferencedMov` — empty bare file is removed, its ledger entry dropped.
- `testLoadAdoptsUnreferencedMovWithBytes` — file kept, one unsorted record, `recovered` lists it,
  `storage.usedBytes` unchanged, `deck == nil`; a second launch does not duplicate it.
- `testLoadAdoptsLedgerEntryWithUnknownDeck` — the ledger-only, no-deck case becomes visible.
- `testAdoptedClipCanBeDiscarded` — discard deletes the file and the record, bytes freed.
- `testLoadSweepNeverTouchesReferencedFiles` — saved, kept-true and nil segments (including a
  zero-byte nil, which step 4 handles) keep their files.
- `testLoadSweepSkippedWhenIndexUnreadable` — index I/O error: bare empty and non-empty files
  both untouched.
- `testLoadSweepSkippedWhenLedgerUnreadable` — corrupt ledger JSON: bare empty file untouched.

(b) unkept failures in a kept session
- `testFinishDeletesUnkeptFailureFilesInKeptSession` — saved sibling's file stays.
- `testLoadDeletesUnkeptFailureFilesInKeptSession` — launch cleanup of an existing leak.

(c) ledger and temp hygiene
- `testFinishNothingKeptKeepsLedgerEntryWhenRemovalFails` — stubbed `fileSize` reports the file
  still present; the entry survives and the next load recovers the clip.
- `testLoadRemovesStrayTempFilesOnly` — `session-index.<UUID>.tmp` and
  `segment-ledger.<UUID>.tmp` go; `session-index.json`, `session-index.unreadable-*.json` and
  `notes.tmp` stay.
- `testSaveFailureLeavesNoTempFile` (`SessionIndexTests`, `SegmentLedgerTests`) — with the target
  path blocked by a directory, whether `save` throws or not, no `*.tmp` remains.

## Sol audit focus (merge gate)

Data-loss only: that no code path in this change deletes a file with bytes that is unreferenced
or referenced with outcome `.saved` / `.failed(kept: true)` / `nil`; the skip conditions
(index/ledger unreadable, active session); the adoption record never being exportable or
deletable without the user; ledger entry retained whenever a file survives. **Owed, see the PR.**

## Do not

- No change to the recording path (`RecorderView`, `SessionStore`, `SessionMachine`, capture
  service, `AppModel`), no new deletion outside `Library` and the two `save` temp cleanups.
- No `try!`, `as!`, `Task.detached`, `unchecked Sendable`, `nonisolated(unsafe)`.
- No user-visible string outside `UICopy`. No AI attribution trailers.

## Done when

CI green on both lanes (baseline + Duo flag) with the new tests visible in the `.xcresult`, the
S2b spec's grep gates still empty, and Sol's data-loss audit recorded (or listed as owed).
