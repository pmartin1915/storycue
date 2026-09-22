# Handoff 2026-09-22 (implement + review pass) — week 1 CI is GREEN, PR #1 open, needs Perry's review/merge

For whichever session picks this up next. Read `ai/STATE.md` first, then this. **Start
that next session directly in `storycue`** (`C:\Users\perry\DevProjects\storycue`), not
`dev-ops` or `Recall` — this session ran from `Recall` (an empty placeholder folder) and
had to reconstruct all context by hand; every doc/log/worktree this handoff points to
lives inside `storycue` itself.

## What this session did

Picked up after `docs/HANDOFF-2026-09-22-week1-spec.md` left off ("dispatch is next"),
across a `/clear` that lost that context — reconstructed state from the worktree, logs,
and a peer session (`storycue-ci-unblock`) before doing anything, per that peer's own
status update (a `.orchestrate/spec.md` collision + unrelated shell/process hazards it's
writing up separately). Confirmed with the peer it wasn't mid-task before proceeding.

Found the `/orchestrate --implement` dispatch had actually **already succeeded** on its
third attempt (`.orchestrate/logs/20260922T050125Z-implement.log`, exit 0) — the peer's
last status update predated that run. Kimi had written all 13 spec'd files
(`SessionMachine`, `CaptureService`/`MockCaptureService`/`AVCaptureService`,
`SegmentLedger`, `Deck`/`Decks`, `ExportManifest`, five test files, ~1470 lines) into
`.orchestrate/wt/week1` as **untracked files** — committed them as WIP on `week1-impl`
(`e6ec9e0`) first, since a collision had already happened once this session and untracked
work is fragile.

**Verified spec compliance mechanically before spending a review call:** extracted every
test name from `docs/WEEK1-SPEC.md`'s acceptance table (35 rows — not the 20 `STATE.md`
used to say; it grew across three post-spec-write commits) and the other four test files'
named tests, diffed both directions against what Kimi actually wrote.
**Zero invented names, zero missing coverage.** All six "Do not" invariants also checked
directly against source and held (no `AVFoundation` import in the reducer, `#if DEBUG`
around all of `MockCaptureService`, no Duo code outside the gate, no eager
`AVCaptureService` construction, `project.yml`/`StoryCueApp.swift` untouched, no AI
attribution).

Read `SessionMachine.swift`'s reducer against all 35 acceptance rows by hand — no
discrepancies found, including the subtle ones (thermal's two-effect ordering, both
`runtimeError`-escapes-wedged-`.finishing` branches, background-task pairing).
`ExportManifest.swift` and `SegmentLedger.swift` (atomic temp-file+rename writes) also
checked out.

**Dispatched two decorrelated reviews in parallel**, each in a throwaway detached-HEAD
worktree at the WIP commit so nothing either wrote touched the reviewed artifact:
- **Sol** (`codex-exec.sh --implement`, `.orchestrate/sol-audit.md`) — full diff audit.
  Correlation guard: Kimi is the executor, so Kimi can't review its own diff (orchestrate
  skill step 4).
- **Kimi** (`kimi-exec.sh --implement`, `.orchestrate/kimi-transitions.md`) — state-machine
  transition gap analysis (`docs/PLAN.md` §8 row 4, the prompt the plan already names).

**Sol found a real bug, traced deeper than Sol's own report showed it:**
`AVCaptureService`'s single mutable `activeSegmentID` can't distinguish two recordings
when the reducer's `runtimeError` escape hatch (acceptance rows 20/21) starts a new
segment before the old one's real movie-file delegate has fired. Advisor's trace found it
was worse than Sol's framing: the late callback for the *old* segment doesn't just
mislabel itself as the new one — it also nils the property, so the *new* segment's own
later callback then finds `nil` and is silently dropped, wedging it permanently. **Fixed**
by deriving the segment ID from the recording's own file URL (`makeSegmentFileURL` already
names it `<id>.mov`) instead of actor-mutable state — eliminates the property entirely.

Also fixed: a duplicate `.mediaServicesReset` emission (both the movie-delegate path and
the `runtimeErrorNotification` handler were reporting the same reset; kept only the
notification handler, since it's the documented source per the file's own header — an
early `return` would have been the wrong fix here, since the delegate's `segmentFinished`
fallthrough is what lets the reducer exit `.finishing`), and a manifest-order test whose
fixture couldn't distinguish "preserves `state.clips` array order" from "sorts by
questionID" (reordered the fixture so they diverge).

Three more Sol findings and all 13 of Kimi's transition-gap items were judged real but
**not** week-1 blockers — logged to `ai/IDEAS.md` with file:line and the fix shape so a
later session doesn't have to rediscover them (non-idempotent `configureSession()` on
reset — unreachable until `SessionStore`/step 4 exists; unbounded/uncancelled
`NotificationCenter` tasks — low risk while only one instance ever exists; two internal
helper types Sol flagged as "not in the spec" — judged not a violation, they're
implementation plumbing the spec deliberately left unspecified; 13 untested
(phase × event) corners in the reducer — all confirmed as *test* gaps only, the code
already handles them correctly).

Fix commit: `0dd159e` on `week1-impl` (2 files, +16/−10). Re-ran both mechanical checks
after editing — still 35/35 exact match, all invariants hold.

## What happened after that (same day, autonomous-loop ticks)

Asked Perry how to get a compile signal (pushing a new branch to the private repo is an
ask-first action under standing instructions) — he chose **push + open a PR against
main**. Pushed `week1-impl`, opened **PR #1**
(https://github.com/pmartin1915/storycue/pull/1). First compile of ~1,500 lines of
Swift 6 strict-concurrency code written blind on a non-Mac host predictably needed
iteration — **three real, distinct bugs, no flakes, four CI rounds total:**

1. `51fbeb7` — three `Notification`-is-not-`Sendable` errors in `AVCaptureService`'s
   `NotificationCenter` consumers (`SendingRisksDataRace`). Fixed by extracting the one
   Sendable value each handler needs (a raw `UInt`/`Int`/`AVError`) synchronously inside
   the `for await` loop, before the `await` hop into the actor, instead of passing the
   whole `Notification` across.
2. `9622535` — two `SessionMachineTests` "finish-then-advance" tests
   (`testNextQuestionWhileRecordingFinishesFirst`,
   `testNextQuestionAtLastQuestionFinishesThenClamps`) passed the
   `(SessionState, [SessionEffect])` tuple from a first `reduce()` call straight into a
   second `reduce()` call's `SessionState` parameter instead of unpacking `.0` — the
   pattern used correctly everywhere else in the file (e.g. line 132). Checked the whole
   file for the same anti-pattern; these were the only two instances.
3. `1042f22` (`week1-impl`) / `e735199` (`main`) — **not a week-1 bug, a pre-existing
   scaffold gap**: `project.yml` never set `SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG`
   for the Debug config. Same class of gap as the `ENABLE_TESTABILITY` fix in `30696c0`
   (this morning's earlier session) — a hand-authored XcodeGen project doesn't inherit
   Xcode's project-template defaults for free. `#if DEBUG` never activated anywhere in the
   project, so `MockCaptureService.swift` (entirely `#if DEBUG`-gated) failed to compile —
   the first week any file used that gate, so the gap had never surfaced before. Fixed on
   **both** branches since it's repo-wide, not implementation-specific; `main`'s own CI
   confirmed green on `e735199` too.

**Final green run: `35694965403`.** `Build & test (baseline, flag off)`: 49/49 tests
passed, including all 35 `SessionMachineTests` acceptance rows. `Build & test (Duo, flag
on)`: skipped, correctly (this runner has no iOS 27.1 SDK — expected per `STATE.md`).

Each CI-fix commit went through the same discipline as everything else this session: read
the actual failing log (not just the conclusion), confirm the root cause in the real
source before touching anything, re-run the spec-compliance mechanical checks after
editing test files, check for remote divergence before every push.

**Did NOT merge PR #1.** The push/PR go-ahead covered getting a compile signal, not
merging to `main` — that's Perry's call. Sent a desktop push notification when CI went
green.

## What's next

- **PR #1 needs Perry's review + merge.** Nothing mechanical is left: spec-compliant
  (35/35 acceptance rows, zero invented names), boss-reviewed (Sol + Kimi + own read, one
  real concurrency bug found and fixed), CI green on both the feature branch and `main`.
- Once merged: Kimi's transition-gap coverage pass (`ai/IDEAS.md`, optional hardening,
  not blocking) and Sol's other two deferred `AVCaptureService` items become relevant
  again once `SessionStore` (step 4) starts.
- App icon (`ai/STATE.md` — blocked on a Perry decision, unrelated to this PR).

## Do not (unchanged from prior handoffs, still true)

- Don't implement Duo-path code this week — week 2, under the SDK gate.
- Don't widen `deploy.yml`'s secret set or run it — App ID/profile/ASC record don't exist yet.
- Don't reopen the name, no-hardware, or v1-display-only decisions.
- Don't merge PR #1 without Perry actually looking at the diff first — CI green isn't the
  same thing as reviewed.
- No AI attribution trailers on any commit.

## Verification for the next session to trust this handoff

- `gh pr view 1` shows state OPEN, branch `week1-impl` -> `main`.
- `gh run view 35694965403 --json conclusion` reports `success`; job step
  `Build & test (Duo, flag on)` shows `skipped`, not `failure`.
- `git log --oneline -6 origin/week1-impl` should show, top to bottom: `1042f22`,
  `9622535`, `51fbeb7`, `0dd159e`, `e6ec9e0`, `11cf380`.
- `git log --oneline -3 origin/main` should show `6b5afef`, `e735199`, `4a22aee` on top
  of `11cf380`.
- `ai/IDEAS.md` has six 2026-09-22 entries (Sol findings 2/6/9, Kimi's 13-item gap list,
  the advisor's delegate-ordering note, and the already-present persistLedger one).
- `.orchestrate/logs/20260922T055148Z-sol-implement.final.txt` and the tail of
  `20260922T055152Z-implement.log` hold the two reviews' full text.
