# Handoff 2026-09-22 (implement + review pass) — week 1 code exists, review done, NOT pushed

For whichever session picks this up next. Read `ai/STATE.md` first, then this.

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

## What's next

**Push `week1-impl` and get a real compile/test signal — did NOT do this, needs Perry's
go-ahead.** The branch is local-only (no remote tracking ref). `build.yml` triggers on
`push`/`pull_request` against `main` and `workflow_dispatch` only — nothing triggers on
pushing a feature branch by itself, so getting a compile signal means either opening a PR
against `main` or a manual `workflow_dispatch` run against the pushed branch. Either way is
the first push of this branch to the (private) GitHub repo, which is an ask-first action
under standing instructions. **1,500 lines of Swift 6 strict-concurrency code written
blind on a non-Mac host have never been compiled — expect iteration rounds on the
`xcode-27` runner before green.** Do not merge to `main` before that.

Once it's green: Kimi's transition-gap coverage pass (`ai/IDEAS.md`, optional hardening)
and Sol's other two deferred `AVCaptureService` items become relevant again once
`SessionStore` (step 4) starts.

## Do not (unchanged from prior handoffs, still true)

- Don't implement Duo-path code this week — week 2, under the SDK gate.
- Don't widen `deploy.yml`'s secret set or run it — App ID/profile/ASC record don't exist yet.
- Don't reopen the name, no-hardware, or v1-display-only decisions.
- Don't merge `week1-impl` to `main` before CI is green on it.
- No AI attribution trailers on any commit.

## Verification for the next session to trust this handoff

- `git worktree list` shows `.orchestrate/wt/week1` on `week1-impl` at `0dd159e`.
- `git branch -vv | grep week1-impl` shows no `[origin/week1-impl]` tracking ref (confirms
  not yet pushed).
- `ai/IDEAS.md` has six new 2026-09-22 entries (Sol findings 2/6/9, Kimi's 13-item gap
  list, the advisor's delegate-ordering note, and the already-present persistLedger one).
- `.orchestrate/logs/20260922T055148Z-sol-implement.final.txt` and the tail of
  `20260922T055152Z-implement.log` hold the two reviews' full text.
