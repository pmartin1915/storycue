# STATE -- storycue

> Seeded 2026-09-18 by hand from dev-ops branch claude/ios-duo-app-ideas-te3edu: the four docs
> copied with `git show` and byte-matched via `cmp`, seed files written directly. The branch's
> bootstrap-storycue.ps1 was NOT executed (the session's classifier refused it) and has run on
> no machine; its -DevOps default resolves wrong when run from outside dev-ops. Keep short; read first.

## What this is
See README.md and docs/PLAN.md. Decisions of record are in docs/HANDOFF-2026-09-18.md
(name "StoryCue" for now; NO Duo hardware; identifiers and pipeline as Shortless).

## What's Done
- [x] Plan, handoff, two Gemini research prompts (2026-09-18)
- [x] Local folder seeded (this file)
- [x] Kimi plan review, adjudicated: docs/reviews/PLAN-REVIEW-2026-09-18.md (3 accept, 1 reject-with-replacement)

- [x] GitHub remote pmartin1915/storycue (private), main pushed 2026-09-18; dev-ops registry row added
- [x] Gemini Deep Research reports landed 2026-09-18 (laptop, gemini-deep-research skill): docs/research/PROMPT-A-ship-path-REPORT.md, docs/research/PROMPT-B-product-REPORT.md
- [x] Tech Talk transcripts landed 2026-09-18 (all four had a working Transcript tab, no egress issue on this machine): docs/techtalks/111464-multiple-displays-and-scenes.md, 111465-camera-experience.md, 111463-adaptive-layouts.md, 111461-prepare-your-app.md
- [x] Reference fixes (2026-09-19, Phase A of the Sol-gate handoff): PLAN.md header (false
  bootstrap-script claim, inverted canonical/historical framing, wrong ai/IDEAS.md pointer),
  §7/§8 research filenames, README handoff pointer. PLAN.md §§1-5 content untouched. Commit
  6d0c3f7; the dev-ops/IPHONE-DUO-PLAN-2026-09-18.md pointer it introduced was confirmed to exist.
  Kimi and Sol were both deliberately NOT dispatched this session -- Sol per the quota gate,
  Kimi because the only open question (Xcode 27.1 SDK support) postdates Kimi's training data
  and a review of a 32-line pointer diff has nothing worth auditing; both resume in Phase B.

## What's Next
- [ ] Sol plan review after 2026-09-20 14:36, then SYNTHESIS-2026-09.md and fold into PLAN.md (fold in both Gemini reports and the four transcripts in the same pass -- Task 3 of docs/HANDOFF-2026-09-18-research-run.md, deliberately NOT done this session)
- [ ] Scaffold: project.yml + build.yml + deploy.yml adapted from shortless-ios, CI green on macos-27
- [ ] Week 1 (plan section 9): single-screen recorder, mocked capture, XCTest

## Open Loops
- Sol plan review NOT run: ChatGPT Plus usage limit until 2026-09-20 14:36. Re-dispatch plan section 8 row 1 after that; then fold both reviews into PLAN.md sections 4-5 in one pass.
- The hosted runner has no iOS 27.1 SDK yet (checked 2026-09-18). Pivot date 2026-10-10 (plan section 5).
- Outer-display touch interactivity: RESOLVED by 111465 transcript + PROMPT-A report -- CameraCaptureAccessory content is explicitly non-interactive/display-only (the outer display cannot host tap targets); not yet folded into PLAN.md, that's Task 3.
- **PLAN.md §1 vs. PROMPT-A-ship-path-REPORT.md contradiction, unresolved and possibly a citation
  problem in the report itself -- for the Task 3 synthesis (checked 2026-09-19, commit 6d0c3f7):**
  PROMPT-A (lines 83, 103) states, at "Confidence: High," that "the iOS SDK and simulator
  support for the iPhone Duo are entirely missing from the initial Xcode 27.1 beta," citing its
  own footnotes 1 and 2, and that it will arrive "later this month." **But footnote 1 in that
  report's Works Cited is titled "Xcode 27.2 Beta Release Notes"** (not 27.1), and footnote 2 is
  an Apple Developer Forums thread, not release notes -- so the report's own citations don't
  clearly support a claim about the 27.1 beta specifically; it may have conflated 27.1 and 27.2.
  Independently, a WebSearch + a WebFetch of the MacRumors 2026-09-18 article
  (https://www.macrumors.com/2026/09/18/apple-releases-xcode-27-1-beta-iphone-duo-support/,
  read directly, not the aggregator summary) confirms that article states the 27.1 beta ships
  "updated SDKs for the iPhone Duo, and a simulator that supports the device's new poses and
  orientations" -- i.e. press coverage says 27.1 already has Duo simulator support. Apple's own
  release-notes page (developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
  could NOT be checked -- it's JS-rendered and WebFetch returned only the page title, no body
  text. So this is a live, unresolved disagreement between one Gemini-report citation (of
  questionable relevance) and press coverage, not something this check settled -- the synthesis
  pass should either get a human/Sol read of Apple's actual release notes page, or treat this as
  UNVERIFIED rather than picking a side. It doesn't change the load-bearing constraint either
  way: Perry has no Mac at all, so a *local* beta's simulator support is moot -- what matters is
  the hosted `macos-27` GitHub Actions runner image, which still lacks the 27.1 SDK as of
  2026-09-18 (Open Loop above). Also re-read PROMPT-A's "self-hosted Mac mandatory" framing as
  conditional on needing 27.1 before hosted runners catch up, not a flat contradiction of
  section 4.3/5's no-Mac constraint, before the synthesis pass tries to reconcile them as
  opposed claims.

## Git state
- Branch: main, remote https://github.com/pmartin1915/storycue.git (private), pushed through 6d0c3f7 (Phase A reference fixes) as of 2026-09-19; a follow-up commit correcting this Open Loop note lands right after
