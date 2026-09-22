# Handoff 2026-09-22 (coverage pass + CI's Duo SDK surprise + icon prompts)

Continues from `docs/HANDOFF-2026-09-22-pr1-merge.md` (PR #1 merged, `7b93894`). This
session did two things Perry asked for directly, plus found one thing nobody asked for.

## What this session did

**1. Kimi coverage-hardening pass — done, merged, CI green.**
Wrote `docs/WEEK1-COVERAGE-SPEC.md`, naming all 10 test methods needed to cover the 13
(phase x event) gaps the prior session's Kimi transition-gap analysis found (logged in
`ai/IDEAS.md` 2026-09-22) — exact setup and assertions for each, derived from reading
`SessionMachine.swift`'s reducer directly, so `/orchestrate` had nothing to invent.
Dispatched via `/orchestrate` (Kimi executor): `kimi-exec.sh --review` first (mostly the
known review-mode artifact — it can't see the referenced doc — but two real gaps: no
escalation path if the reducer itself turned out wrong, no explicit done-checklist; both
fixed in the spec before dispatch). `kimi-exec.sh --implement` in an isolated worktree
produced exactly the spec'd diff: one file, +128/−0, `StoryCueTests/SessionMachineTests.swift`
only. Independently re-verified all 10 tests by hand against the reducer before touching
anything else. Sol's decorrelated audit (correlation guard — Kimi is the executor, so Sol
reviews, not Kimi) found **zero findings**, independently confirmed the same thing.
Cherry-picked onto `main` as `68037c9`, later a docs commit brought `main` to `7510d67`.
**CI green: run `35759964133`, 59/59 tests both lanes** (49 prior + 10 new).

**2. Found, unprompted: the hosted CI runner now has the Duo SDK.**
The same CI run's `Duo SDK gate` step reported `iphoneos SDK 27.2` (`Xcode 27.2 beta`),
`Duo SDK headers: YES`, `Duo simulator device type: YES` — `StoryCueDuoTests` actually
compiled and ran (not skipped) for the first time, 59/59 passing on that lane too. Last
check (2026-09-21) had SDK 27.0, no Duo. This beats PROMPT-A's "late Oct / early Nov"
estimate by 5–6 weeks and is a load-bearing fact for the **2026-10-10 pivot check**
(`docs/PLAN.md` §5) — that check's premise ("runner won't have it in time") is now stale.
Recorded in `ai/STATE.md` Open Loops, flagged to Perry, **not acted on** — starting
Duo-path code is still the deliberate week-2-under-the-gate scoping decision (unrelated to
CI availability), and whether this SDK availability is the new steady state or a transient
beta rollout is unconfirmed (re-check on the next CI run before treating it as permanent).

**3. Icon glyph concepts — four options given directly to Perry, not blocked on a session.**
Read `DevProjects/brand/BRAND.md` for the actual constraint set (per-app glyph = single
stroked line, 44 viewBox, no container/fill; accent color is assigned by *product line*,
never per-app; the two existing lines are Clinical=teal and Outdoor/life=rust, neither of
which cleanly fits a family-video-recorder app — the exact gap `ai/STATE.md` had been
flagging as blocked-on-Perry). Presented four differentiated glyph concepts via
AskUserQuestion (Quote-wave, Cue card, Nested arcs, Story path + play) plus the accent-line
question. **Perry picked: generate all four himself on Gemini to compare visually
(leaning Quote-wave), accent = rust (outdoor/life line, broadened reading).** I wrote
ready-to-paste Gemini prompts for all four concepts (shared brand constraints + one
concept-specific paragraph each) directly in chat — not saved to a file, since Perry is
running them himself outside this session. **If a future session needs them again, they
are not written down anywhere in the repo — reconstruct from this paragraph and
`BRAND.md`'s geometry/color rules, or ask Perry which one he picked.**

## What's next

- **Perry is generating icon candidates on Gemini himself.** Once he picks a winner: turn
  it into the actual `marks/apps/storycue.svg` in the `brand` repo (not `storycue` — the
  glyph lives in the house brand system), then run `brand`'s `npm run check` /
  `check-icons.mjs` gate. That's Codex/Sol- or hand-authored SVG work, not `/orchestrate`
  bulk implementation — small, precise, single-file.
- **2026-10-10 pivot check needs re-reading against the new Duo-SDK-availability fact**
  before that date, not assumed stale-but-fine. Perry's call, not mechanical.
- Nothing else queued. `ai/STATE.md`'s "What's Done" is current through `7510d67`.

## Do not (unchanged from prior handoffs, still true)

- Don't implement Duo-path code — still week 2's scoping decision, not unblocked by CI
  alone (see above).
- Don't widen `deploy.yml`'s secret set or run it — App ID/profile/ASC record don't exist yet.
- Don't reopen the name, no-hardware, or v1-display-only decisions.
- Don't invent the icon glyph or accent line yourself — both are now Perry's to finish
  (concept pick + generated SVG), not a session's to decide further.
- No AI attribution trailers on any commit.

## Verification for the next session to trust this handoff

- `git log --oneline -3 origin/main` shows `7510d67`, `68037c9`, `a552d38`.
- `gh run view 35759964133 --json conclusion` reports `success`.
- `ai/IDEAS.md`'s 2026-09-22 Kimi transition-gap entry is marked `**RESOLVED 2026-09-22**`.
- `ai/STATE.md` Open Loops' top entry is the Duo-SDK-availability correction, dated
  2026-09-22, not the older "no iOS 27.1 SDK" note.
- No new file exists under `marks/apps/` in `brand` yet — the icon is still unresolved,
  waiting on Perry's Gemini pick, not on any session action.
