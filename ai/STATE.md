# STATE -- storycue

> Seeded 2026-09-18 by hand from dev-ops branch claude/ios-duo-app-ideas-te3edu: the four docs
> copied with `git show` and byte-matched via `cmp`, seed files written directly. The branch's
> bootstrap-storycue.ps1 was NOT executed (the session's classifier refused it) and has run on
> no machine; its -DevOps default resolves wrong when run from outside dev-ops. Keep short; read first.

## What this is
See README.md and docs/PLAN.md. Decisions of record are in docs/HANDOFF-2026-09-18.md
(name "StoryCue" for now; NO Duo hardware; identifiers and pipeline as Shortless).
**docs/PLAN.md was edited in one coordinated pass on 2026-09-21** from
docs/research/SYNTHESIS-2026-09.md, which is where every research/review verdict lives.

## What's Done
- [x] Plan, handoff, two Gemini research prompts (2026-09-18)
- [x] Local folder seeded (this file)
- [x] Kimi plan review, adjudicated: docs/reviews/PLAN-REVIEW-2026-09-18.md (3 accept, 1 reject-with-replacement)
- [x] GitHub remote pmartin1915/storycue (private), main pushed 2026-09-18; dev-ops registry row added (on dev-ops master, 92d29df)
- [x] Gemini Deep Research reports landed 2026-09-18: docs/research/PROMPT-A-ship-path-REPORT.md, PROMPT-B-product-REPORT.md
- [x] Tech Talk transcripts landed 2026-09-18: docs/techtalks/111461, 111463, 111464, 111465
- [x] Reference fixes 2026-09-19 (commit 6d0c3f7)
- [x] **Sol plan review RAN 2026-09-21** (943 s, return_code 0, read the files): docs/reviews/SOL-PLAN-REVIEW-2026-09-21.md. 3 blocking + 3 should-fix; all adjudicated in SYNTHESIS §S (5 accept, 1 partial, 1 deferred to IDEAS).
- [x] **Synthesis 2026-09-21**: docs/research/SYNTHESIS-2026-09.md folds both Gemini reports, all four transcripts, Kimi 1/2/4/5 and Sol 1-6, plus two first-hand checks that changed verdicts (below). PLAN.md sections 1, 2, 4, 5, 7, 8, 9 edited in the same pass.
- [x] Runner README re-read 2026-09-21: unchanged since 09-18 (image 20260912.0186.1, Xcode 27.0, no 27.1 SDK, no Duo simulator). Image has xcbeautify 3.2.1 and xcodes; NOT xcodegen or xcpretty.

- [x] **Scaffold written, Kimi-reviewed (docs/reviews/SCAFFOLD-REVIEW-2026-09-21.md), pushed as 195da92** -- project.yml, build.yml, deploy.yml, PrivacyInfo.xcprivacy, usage strings, DuoSupport + two test bundles.
- [x] **Week-0 gate MET 2026-09-22: CI is green** (run 35676600490, conclusion success). Confirmed the correct baseline-only green: iphoneos SDK 27.0, Duo SDK headers NO (flag NOT SET), Duo simulator device type NO -- exactly the expected facts for today's runner image.
  - Root cause of every prior run never even starting (all showed `runner_id:0`, never `in_progress`): **`runs-on: macos-27` is not a real GitHub-hosted runner label.** Confirmed against `actions/runner-images`'s published catalog -- the Xcode 27 preview image's label is `xcode-27` (fixed in build.yml and deploy.yml, commit 994e577). This was NOT a billing/minutes problem; the Actions spending limit was never touched or queried.
  - Two further build-config bugs found by actually running it, fixed forward in small commits (3 executing runs total, within budget):
    1. `994e577` -- runner label fix (macos-27 -> xcode-27).
    2. `84378e7` -- `StoryCueTests` and `StoryCueDuoTests` both left `PRODUCT_NAME` unset in project.yml, so both resolved to an empty product name and collided on the same `PlugIns/.xctest` output path when the scheme built both together ("Multiple commands produce..."). Fixed by giving each an explicit `PRODUCT_NAME`.
    3. `30696c0` -- the app module was built without `-enable-testing`, so `StoryCueTests` couldn't `@testable import StoryCue` ("Unable to resolve Swift module dependency"). A hand-authored XcodeGen project doesn't inherit the `ENABLE_TESTABILITY=YES` default that an Xcode-created project's template bakes into its Debug config -- added explicitly under `settings.configs.Debug` in project.yml.
  - `build.yml`'s `push:` trigger was never removed -- green landed within the 3-run budget, no need to switch to workflow_dispatch-only iteration.

## What's Next
- [ ] **App icon from DevProjects/brand: BLOCKED, needs a Perry decision, not mechanical.** `brand`'s icon pipeline requires a new per-app glyph SVG at `marks/apps/storycue.svg` (doesn't exist) and an accent-line assignment -- brand's two-line table (clinical=teal / outdoor-life=rust) doesn't cover a family-video-recorder app. Perry chose to defer this 2026-09-22 rather than have a session invent the glyph/line. Revisit when he has a glyph concept or a line assignment to give.
- [ ] Week 1 (plan section 9): single-screen recorder with segment finalization (Sol 2's event table), mocked capture, XCTest. Product rules: SYNTHESIS Q7. **Not started this session** -- deliberately scoped out; needs its own `/orchestrate` spec pass (see docs/HANDOFF-2026-09-22.md).
- [ ] Kimi state-machine enumeration once the state machine exists (plan section 8 row 4).
- [ ] 2026-10-10 pivot check (plan section 5) -- the EXPECTED path is 1.0 without Duo.

## Open Loops
- The hosted runner has no iOS 27.1 SDK (re-checked 2026-09-21). Pivot date 2026-10-10 (plan section 5). PROMPT-A expects hosted 27.1 late Oct / early Nov.
- **Outer-display touch: CORRECTED 2026-09-21.** The earlier note here said "RESOLVED non-interactive by 111465 + PROMPT-A". Wrong on both counts: no transcript says anything about interactivity, and PROMPT-A quoted the UIKit *external display* article. Apple's DocC for CameraCaptureAccessory (read directly via the DocC JSON endpoint, which works where the HTML page returns only a title) says "unlike ExternalNonInteractiveAccessory, the content can be interactive." v1 is display-only BY DECISION (no hardware to verify hit-testing), not by platform limit. SYNTHESIS Q1.
- **Xcode 27.1 / Duo simulator contradiction: RESOLVED 2026-09-21.** PROMPT-A's "later this month" line is from the Xcode 27.2 beta notes (as its own footnote says); Apple forum 847137's accepted answer says the Duo simulator shows up in 27.1 beta after re-downloading the iOS 27.1 simulator runtime component. Press was right. Moot anyway: no Mac. Apple's own 27.1 release-notes HTML still unreadable (title only) -- try the DocC JSON endpoint pattern next time.
- Name: PROMPT-B recommends abandoning "StoryCue" but says its trademark search was SIMULATED. No evidence weight. Perry's call; locked "for now".
- Pricing: free + one-time unlock (PROMPT-B) is a Perry decision, deferred; deck model gets an `isIncluded` bit from the start.
- Optional operator act 2026-09-23: Apple online Duo Q&A (plan section 7 item 7).
- Sol's ASC pre-query for build-number collisions: deferred to ai/IDEAS.md.

## Git state
- Branch: main, remote https://github.com/pmartin1915/storycue.git (private). 2026-09-21 session: b8e5902 (synthesis + Sol review + PLAN pass), 195da92 (scaffold), 4d99fe3 + 332af19 (handoff, STATE, build.yml concurrency). 2026-09-22 session: 994e577 (runs-on label fix), 84378e7 (PRODUCT_NAME fix), 30696c0 (ENABLE_TESTABILITY fix) -- CI green on 30696c0 (run 35676600490).
