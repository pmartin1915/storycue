# Handoff 2026-09-18 (evening) -- run the research, then adjudicate

For a Sonnet session on perryslenovo (the laptop: it has Chrome and the
`gemini-deep-research` skill; the cloud session that wrote the plan had neither).
Read `ai/STATE.md` first, then this. `docs/HANDOFF-2026-09-18.md` is the earlier handoff and
still holds the decisions; `docs/PLAN.md` is the contract.

## State when this was written

- Repo exists: `https://github.com/pmartin1915/storycue` (private), `main` pushed, tracking
  `origin/main`. Registered in dev-ops `config/portfolio-registry.json` (life-apps, incubating).
- No Swift yet. Do not scaffold it in this session; the research lands first (plan section 8,
  earlier handoff "Start here" item 4: adjudicate before writing Duo code).
- Kimi reviewed the plan; adjudicated in `docs/reviews/PLAN-REVIEW-2026-09-18.md`.
- **Sol is quota-blocked** ("usage limit ... try again at Sep 20th, 2026 2:36 PM"). Money Rule
  STOP: do not retry before then, never buy credits. After that time, re-dispatch plan section
  8 row 1 via `pal clink cli_name=codex role=codereviewer` with `absolute_file_paths` set to
  `docs/PLAN.md`; read the body, not the verdict line.

## Task 1 -- two Gemini Deep Research runs (the reason this handoff exists)

Invoke the `gemini-deep-research` skill and follow it exactly; it was verified end to end on
2026-09-07 and its steps are the steps. Specifics for this repo:

| Run | Brief (paste verbatim, everything between the rules) | Save as |
|---|---|---|
| A, first | `docs/research/PROMPT-A-ship-path.md` | `docs/research/PROMPT-A-ship-path-REPORT.md` |
| B, second | `docs/research/PROMPT-B-product.md` | `docs/research/PROMPT-B-product-REPORT.md` |

- A first: it settles the ship path (27.1 SDK on hosted runners, whether `simctl` can drive
  posture, whether the simulator renders accessory content). B is product research and can
  wait a day if only one run fits.
- The briefs are self-contained; paste via clipboard and **verify the landed head AND tail**
  with `get_page_text` (this machine has pasted stale wrong content before, full length).
- Account is `pmartin1913@gmail.com` at `https://gemini.google.com/u/1/app`; confirm the Pro
  badge. A password prompt or any quota/upgrade banner is a STOP -- hand it to Perry.
- Export lands in `C:\Users\perry\Downloads\<title>.md`. Move it to the path above, strip
  Google's `\[` `\]` escapes, and keep the report's own title line. Do not edit its content.
- Commit each report as it lands (`research: prompt A report`), push to `origin main`.
- Expect 15-25 min per run; poll with a backgrounded `sleep 280`, never short chained sleeps.
  Past 40 min, stop and tell Perry.

## Task 2 -- Tech Talk transcripts, if the browser reaches them

Perry offered to fetch these; the cloud session could not (egress proxy). From the laptop,
try `https://developer.apple.com/videos/play/tech-talks/<id>/` and copy the transcript tab
into `docs/techtalks/<id>-<slug>.md`, priority order **111464, 111465, 111463, 111461**. If the
page has no transcript tab or the copy is not clean text, stop after one attempt and say so;
this is nice-to-have and Perry can paste them himself.

## Task 3 -- adjudicate (only once both reports and, ideally, Sol's review exist)

One file, `docs/research/SYNTHESIS-2026-09.md`, in the shape of dev-ops
`LEGIBILITY-SYNTHESIS-2026-08.md`: per question, what the report ESTABLISHED vs INFERRED vs
left UNVERIFIED, and what it changes in `docs/PLAN.md` sections 1, 4, 5. Fold the Kimi review's
accepted findings (1, 2, 4) into the plan in the same pass so it is edited once. Then update
`ai/STATE.md` and stop; the scaffold (project.yml + workflows from `shortless-ios`) is the next
session's week-0 gate and is worth a fresh context.

## Do not

- Buy anything, retry into a quota banner, or run Sol before 2026-09-20 14:36.
- Write Swift, or edit `docs/PLAN.md` before Task 3.
- Touch dev-ops for this work except `ai/IDEAS.md` if a deferred idea comes up.
- Add attribution trailers to commits (global rule).
