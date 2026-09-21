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

- [x] **Scaffold written, Kimi-reviewed (docs/reviews/SCAFFOLD-REVIEW-2026-09-21.md), pushed as 195da92** -- project.yml, build.yml, deploy.yml, PrivacyInfo.xcprivacy, usage strings, DuoSupport + two test bundles. NEVER EXECUTED YET: see next.

## What's Next
- [ ] **Week-0 gate: read CI run 35646080336** (Build & Test on macos-27, triggered by 195da92, still queued at handoff). Green = gate met; red = fix forward per docs/HANDOFF-2026-09-21.md Task 1. Then the app icon from DevProjects/brand.
- [ ] Week 1 (plan section 9): single-screen recorder with segment finalization (Sol 2's event table), mocked capture, XCTest. Product rules: SYNTHESIS Q7.
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
- Branch: main, remote https://github.com/pmartin1915/storycue.git (private). 2026-09-21 session: b8e5902 (synthesis + Sol review + PLAN pass), 195da92 (scaffold), then this STATE + docs/HANDOFF-2026-09-21.md. CI run 35646080336 pending.
