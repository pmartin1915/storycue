# Plan review, 2026-09-18 -- docs/PLAN.md sections 1-5

Plan section 8 named Sol as the plan reviewer and Kimi for later layout / state-machine
work. What actually happened on the laptop the evening of 2026-09-18:

- **Sol (`pal clink cli_name=codex role=codereviewer`): NOT RUN.** Returned *"You've hit
  your usage limit ... try again at Sep 20th, 2026 2:36 PM"* in 14.6 s, `return_code: 1`,
  before reading the file. Money Rule STOP: nothing purchased, no retry. Re-dispatch the
  section 8 row-1 prompt after that time; this is a window, not a dead lane.
- **Kimi (`pal clink cli_name=kimi role=codereviewer`): RAN.** 113.6 s, `return_code: 0`,
  one file-read tool call, body verified non-empty and on-topic (not the cp1252 empty-exit
  failure). It stated up front that iPhone Duo, iOS 27.1 and Xcode 27.1 postdate its
  training data and confined itself to plan logic and CI mechanics. That is the right
  scope and the findings are read that way.

Adjudicated by the Claude session that dispatched it. Verdicts are on the finding, not the
reviewer; ACCEPT means fold into the plan at the next gate, REJECT means the claim is wrong
as stated and the replacement is given.

## Findings

1. **ACCEPT, narrowed.** With `DUO_SDK` off, the entire Duo path is preprocessor-stripped,
   so a green run on the 27.0 image proves nothing about that code -- it has not been
   parsed. The plan already makes the step print which path it took (section 4 item 2);
   what it does not say is that the `if #available(iOS 27.1, *)` fallback branch is also
   unexercised until 27.1 exists. Kimi's mitigation "compile with the flag on the earliest
   SDK" is not possible before the runner carries 27.1 (the APIs do not exist in 27.0).
   The actionable part: **when 27.1 lands, run the XCTest suite on BOTH a 27.1 simulator
   and a 27.0 simulator runtime**, so the availability fallback is measured, not assumed.
   Add to section 5 rung 2.
2. **ACCEPT.** Section 5 rung 6 ("App Review itself runs the build on devices, a crash in
   the accessory path gets caught before users do") is the weakest claim in the ladder.
   App Review smoke-tests a happy path; nothing says it folds, unfolds, or drops a camera
   session, and "nothing leaves the device" (section 2) means there is no crash telemetry
   fallback either. Soften rung 6 to "catches a crash on launch or in the reviewer's
   happy path only". No evidence source is proposed because none is known; do not invent
   one.
3. **REJECT as stated; a real adjacent trap stands.** Kimi: `github.run_number` is shared
   across all workflows in a repo, so `build.yml` and `deploy.yml` interleave and a deploy
   can get a number ASC already has. **Wrong**: GitHub documents `run_number` as unique
   per *workflow* ("a unique number for each run of a particular workflow ... does not
   change if you re-run the workflow run"). Within `deploy.yml` it is monotone. The two
   failure modes that ARE real, from that same sentence: (a) **re-running a deploy that
   already uploaded** produces the same number and ASC 409s -- the fix is never to re-run
   a deploy past the upload step, or use `run_number` plus `run_attempt`; (b) **renaming
   `deploy.yml`** starts a new workflow and restarts the counter at 1. Keep Wilderness's
   read-the-number-back-from-the-.ipa step regardless; it catches both.
4. **ACCEPT.** The gate keys `DUO_SDK` on `xcodebuild -showsdks` listing `iphoneos27.1`,
   which is SDK-headers presence. Rung 3 additionally needs a 27.1 *simulator runtime* and a
   Duo *device type* in `xcrun simctl list`. Those are separate facts on the runner image
   and can land separately. Give rungs 2 and 3 their own printed checks; do not let one
   flag imply both.
5. **ACCEPT, minor.** Rung 5's evidence (TestFlight testers who own a Duo) names no
   recruitment path. Week 3 needs one line: where the public TestFlight link gets posted
   and by when. Not a plan defect, a missing task.
6. Kimi's uncertainty disclosure -- recorded above, no action.

## What this changes

Nothing in the plan is edited by this review. Findings 1, 2, 4 are section 4 / section 5
edits to make at the week-1 gate or when Sol's review lands, whichever is first, so the two
reviews are folded in once. Finding 3(a) is a `deploy.yml` design rule for the scaffold
step. Finding 5 is a week-3 task.
