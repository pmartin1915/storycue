# Handoff 2026-09-19 — Sol review, then synthesis

For a Sonnet session (any machine with `pal clink cli_name=codex` reachable) run **after
2026-09-20 14:36 Central**, not before. Read `ai/STATE.md` first, then this.

## State when this was written

- Both Gemini Deep Research reports landed and pushed: `docs/research/PROMPT-A-ship-path-REPORT.md`,
  `docs/research/PROMPT-B-product-REPORT.md` (commits `bce7940`, `65b473f`).
- All four Tech Talk transcripts landed and pushed: `docs/techtalks/111461-prepare-your-app.md`,
  `111463-adaptive-layouts.md`, `111464-multiple-displays-and-scenes.md`,
  `111465-camera-experience.md` (commit `33f74eb`) — all four had a working Transcript tab on
  the laptop; the egress block that stopped the cloud session did not reproduce here.
- Kimi's plan review is already adjudicated: `docs/reviews/PLAN-REVIEW-2026-09-18.md` (3 accept,
  1 reject-with-replacement). Its accepted findings (1, 2, 4) are **not yet folded into
  PLAN.md** — that fold happens in Task 2 below, in the same pass as Sol's review and the
  research reports, per the original `docs/HANDOFF-2026-09-18-research-run.md` Task 3.
- Sol has **not** reviewed the plan yet — blocked by a ChatGPT Plus usage limit until
  2026-09-20 14:36. Do not retry before then; that is a Money Rule STOP, not a broken lane.
- `docs/PLAN.md` has not been edited since 2026-09-18 — sections 1, 4, 5 are still pre-research.
- `ai/STATE.md` reflects all of the above as of commit `91eb136`.

## Task 1 — Dispatch Sol's plan review (only after 2026-09-20 14:36)

Per `docs/PLAN.md` §8, row 1:

```
pal clink cli_name=codex role=codereviewer, absolute_file_paths=[docs/PLAN.md]
Prompt: "Review PLAN.md sections 1-5 as a senior iOS engineer. Is CameraCaptureAccessory
the right and only mechanism for a subject-facing prompt on iPhone Duo? What in the SDK
gate (section 4) will bite? What is missing from the hardware-risk section? Be concrete;
cite the API by name."
```

Read the response **body**, not the verdict line — a clink verdict line can read clean while
the body says it never actually engaged with the file. Save the raw response to
`docs/reviews/SOL-PLAN-REVIEW-<date>.md` before doing anything else with it.

## Task 2 — Synthesize everything into one pass

One file, `docs/research/SYNTHESIS-2026-09.md`, same shape as dev-ops
`LEGIBILITY-SYNTHESIS-2026-08.md`: per question, what was ESTABLISHED vs INFERRED vs left
UNVERIFIED, and what it changes in `PLAN.md` sections 1, 4, 5. Inputs to fold, in one pass:

- `docs/research/PROMPT-A-ship-path-REPORT.md`
- `docs/research/PROMPT-B-product-REPORT.md`
- `docs/techtalks/111461-prepare-your-app.md`, `111463-adaptive-layouts.md`,
  `111464-multiple-displays-and-scenes.md`, `111465-camera-experience.md` — note 111465
  already answers a question the plan flagged as open: outer-display `CameraCaptureAccessory`
  content is explicitly **non-interactive/display-only**, confirmed independently by the
  Prompt A report.
- `docs/reviews/PLAN-REVIEW-2026-09-18.md` — Kimi's accepted findings 1, 2, 4
- `docs/reviews/SOL-PLAN-REVIEW-<date>.md` — from Task 1 above

Edit `PLAN.md` sections 1, 4, 5 in this same pass, not as a separate later edit — the point of
doing it once is that a second uncoordinated edit is how sections drift out of sync.

## Task 3 — Update STATE.md and stop

Check off the "Sol plan review" and "SYNTHESIS... fold into PLAN" items in `ai/STATE.md`,
clear the corresponding Open Loop, and stop there. The scaffold
(`project.yml` + `build.yml` + `deploy.yml` adapted from `shortless-ios`) is the next
session's week-0 gate and deserves a fresh context rather than being squeezed into this one.

## Do not

- Retry Sol before 2026-09-20 14:36, or buy anything to get around the quota wall.
- Write Swift.
- Edit `PLAN.md` before the Task 2 synthesis pass.
- Add attribution trailers to commits (global rule).
