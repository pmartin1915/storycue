# Handoff 2026-09-22 (spec pass) — Week 1 spec written; dispatch is next

For whichever session picks this up next. Read `ai/STATE.md` first, then this.

## What this session did

Retold/Hippo (the other active thread this session started from, via `dev-ops`) had
nothing actionable — its own kickoff handoff gates everything on Perry (build decision
after StoryCue ships 10-23; the Gemini Labs toggle flip is explicitly his). Redirected to
StoryCue, whose week-0 CI gate was already met (`docs/HANDOFF-2026-09-22.md`, run
`35676600490`) but whose week-1 deliverable had been deliberately left unstarted twice
because dispatching it to `/orchestrate` without first naming every exported type and
test file lets Kimi's tests "re-implement whatever logic the brief doesn't pin down by
name" (`docs/HANDOFF-2026-09-22.md:65-70`).

Wrote **`docs/WEEK1-SPEC.md`**: full type declarations for `SessionMachine` (pure
reducer, no `AVFoundation` import), `CaptureService`/`MockCaptureService`/
`AVCaptureService` (actor-based, Swift 6 strict concurrency), `SegmentLedger`
(crash-recovery ledger), deck data (`Deck`/`Question`/`Decks`, five v1 decks), and
`ExportManifest`. A 20-row acceptance table maps every event in Sol's event table
(`docs/reviews/SOL-PLAN-REVIEW-2026-09-21.md` finding 2) plus PLAN §4 item 5's "deck
index, timer, export manifest" line to an exact `StoryCueTests/SessionMachineTests.swift`
test method name, so the tests can't drift from spec. Also named:
`StoryCueTests/SegmentLedgerTests.swift`, `DeckDataTests.swift`,
`MockCaptureServiceTests.swift`, `AVCaptureServiceTests.swift`.

Design decisions made explicit in the spec (not left to the implementer to infer):

- **Pause and involuntary interruption collapse to one `.paused(reason:)` state.** Sol's
  review says "any discontinuity finishes the segment; reopening is a new segment after a
  tap" — so a user-initiated pause and e.g. a hinge-close or thermal shutdown produce the
  same phase transition, distinguished only by the recorded `reason`. This avoids a
  separate needs-confirmation flag that an earlier draft of this design carried.
- **Direction-coordinator wiring inside this week's `AVCaptureService` is a named spec
  violation, not an omission** — it's week 2, under `#if DUO_SDK`, and would otherwise
  break the flag-scoping invariant `DuoGateTests`/`DuoSupportTests` already protect.
- **Nil-safety at init is a named requirement.** `StoryCueTests`' `TEST_HOST` launches the
  real app binary, so an eager `AVCaptureDevice` force-unwrap at `StoryCueApp` launch
  would crash every unit test on the simulator/CI host, not just camera tests — a failure
  mode that looks unrelated to whatever test actually failed if it isn't called out.
- **Deck copy is explicitly out of scope for `/orchestrate`'s bulk pass.** PLAN §2 says
  copy is the product and gets its own research + Kimi readability pass; the spec ships
  deck shape (id/mode/question count) with `// TODO copy` placeholders so the bulk
  implementation doesn't produce generic filler question text.

Updated `ai/STATE.md` (spec recorded under What's Done; What's Next now points at
`/orchestrate` dispatch instead of "not started").

## What's next

**Dispatch `docs/WEEK1-SPEC.md` to `/orchestrate`** — a separate, later session, not this
one. Kimi executor implements against the named types and acceptance table; Sol audits
the diff (executor is never its own reviewer). Then Kimi reviews the state machine once it
exists (`docs/PLAN.md` §8 row 4, prompt already written there), then Sol reviews the full
recorder diff at the week-1 gate (`docs/PLAN.md` §9).

## Do not (unchanged from prior handoffs, still true)

- Don't implement Duo-path code this week — week 2, under the SDK gate.
- Don't widen `deploy.yml`'s secret set or run it — App ID/profile/ASC record don't exist yet.
- Don't reopen the name, no-hardware, or v1-display-only decisions.
- No AI attribution trailers on any commit.

## Housekeeping done this session

- Session claim `storycue` released (`node dev-ops/scripts/session-claim.mjs release`
  from `dev-ops`).

## Verification for the next session to trust this handoff

- `docs/WEEK1-SPEC.md` exists and names every type/file referenced above.
- `git log --oneline -3` on `storycue/main` shows this session's commit on top of `30696c0`.
- `git status` clean.
