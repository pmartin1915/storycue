# STATE: storycue (NOW)

**Updated 2026-10-19.** Keep this to one screen. Update it in the same commit as any change of state, and replace lines rather than appending dated entries. Older state is in `ai/archive/STATE-through-2026-10-04.md`; handoffs live in `docs/HANDOFF-*.md` (newest: `docs/HANDOFF-2026-10-04-s6-icon-card.md`).

## Critical path
Tellfolk (formerly StoryCue) 1.0 was added for review by Perry on 2026-10-19 (ASC status: Waiting for Review; build 15.1 attached; unverified in ASC since the click). Next: watch Apple mail (to:pmartin1912@) for review status; if Apple rejects the name, the fallback is a rename in ASC before approval. Owner: Perry.

## Live workstreams
| Stream | State | Next |
|---|---|---|
| App code | main `34551a9`; S0-S4, S2c, S2d, storage sweep (PR #8 `e0122f9`), privacy manifest (#11 `227470a`), free-drag card (#16 `02c5969`), speech-bubble icon (#15 `7f68cba`), Recording pill (#17 `a93cb62`) all merged. CI 269/269 on #17. No open PRs, no CI runs since 2026-10-05 | Nothing queued; only changes if device checks on 14.1 find something |
| TestFlight | 1.0 (14.1) = deploy run `37258274920` from main `f2332ea`, Xcode 27A266a | Perry device checks (Reduce Motion morph, VoiceOver, haptics, serif over camera, drag feel) |
| S6 listing | metadata in `docs/S6-ASC-METADATA.md`; support/privacy pages on martinapps-site branch `storycue-pages` `cd10b5d`, MERGED and live (martinapps-site `cfaa378`, 2026-10-16) | None; support and privacy URLs resolve |
| Featuring nomination | drafted `docs/S6-FEATURING-NOMINATION.md` (`0e8fe1b`), App Launch window 11-16..11-29 | "Why I built it" line DONE 2026-10-19 (in the doc); Perry files; week of 2026-10-19, Claude prefills the nomination (was targeted ~10-09; filed status unverified, last seen 2026-10-04) |
| S7 Duo pivot check | re-framed: is a RELEASE 27.1+ Xcode on the runner image and does ASC accept 27.1 builds (a beta does not count). Date 10-10 has passed; outcome unverified, last seen 2026-10-04 | Re-check runner image; S9 Duo path is after 1.0 |

Status (moved out of Waiting on Perry, sitting 2026-10-25): **Tellfolk 1.0 submitted for review (2026-10-19).** Name check was exact-match USPTO + App Store only, not legal clearance (real USPTO search done 2026-10-16). Build 15.1 (deploy run `39204181253`, rename PR #18 `4477368`).

## Waiting on Perry
1. Featuring nomination: DRAFT SAVED in ASC 2026-10-25 (nomination a85e1c52; App Launch, publish date 2026-11-16; text trimmed to Apple's 1000/500-char limits, see docs/S6-FEATURING-NOMINATION.md). Perry reads it and presses Submit Tue 2026-10-27, 7 PM (Perry To-Do; not done 10-26, moved at sitting 2026-10-27). Moved to Wed 2026-10-28 7 PM on Perry To-Do. (deferred to 2026-10-28, sitting 2026-10-27)
2. Later: free + one-time unlock for 1.x (parked for 1.1, sitting 2026-10-16; undated, the 2027-01-15 date was model-set and removed, Perry 2026-10-19; `isIncluded` bit exists in the deck model); optional real-camera recorder screenshot and captioned screenshots; incoming-call-mid-clip test was deferred in S5 rung 4b.

## Hard dates
- 2026-10-16: submit 1.0 (S8).
- 2026-11-16..11-29: featuring nomination window (App Launch, Thanksgiving).
- 2027-03-14: distribution cert expires (no renewal needed before then).

## Traps
- Deploy command is blocked by the classifier; Perry runs `! gh workflow run deploy.yml --ref main -f upload=true -f duo=false`. A `!`-prefixed `gh secret set` saves an EMPTY value (no TTY); use a real terminal.
- Red "Select Xcode" on every push means the allowlist gate fails closed: the image replaced the RC with a build not in `ASC_REVIEW_XCODE_BUILDS` (`.github/scripts/select-xcode.sh`, both repos). A GA 27.x is approved by definition; add its build number. Beta Xcode builds cannot be submitted.
- Review-screenshot steps are `continue-on-error`: read the test log, not the check color (`ai/IDEAS.md`). `build.yml` runs on PRs only; code reaches main only through a green PR, docs/STATE commits go straight to main. Repo is public (Actions minutes free).
- Hand-authored XcodeGen lacks Xcode template defaults: `ENABLE_TESTABILITY` (`30696c0`) and `SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG` (`e735199`) had to be set in `project.yml`. Profile name must be exactly "StoryCue AppStore". No local Swift compiler. Kimi/Sol quota walls: check `return_code`, not prose.

## Where things live
- Plan and verdicts: `docs/PLAN.md`, `docs/research/SYNTHESIS-2026-09.md`, governing order `docs/STRATEGY-2026-09-22.md`.
- Specs `docs/S*-SPEC.md`; audits and reviews `docs/reviews/`; design review `docs/reviews/DESIGN-REVIEW-2026-10-03.md`; house style `dev-ops/research/WW-0103-ADJUDICATION.md`.
- Deferred ideas: `ai/IDEAS.md`. ASC screenshots: untracked `.orchestrate/asc-screenshots-2026-10-04/` (artifact `asc-screenshots-6.9`, run `37258281482`).
- ASC app Apple ID `6818468570`, bundle `dev.pmartin1915.storycue`; signing `.p12` at `C:\tmp\apple-signing\storycue.p12`.
- Old per-session commit list, CI run IDs and Duo-SDK runner-image history: `ai/archive/STATE-through-2026-10-04.md`.
