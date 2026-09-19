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

## What's Next
- [ ] Gemini Deep Research reports into docs/research/ -- a Sonnet session runs them via the gemini-deep-research skill; see docs/HANDOFF-2026-09-18-research-run.md
- [ ] Tech Talk transcripts into docs/techtalks/ (111464, 111465, 111463, 111461)
- [ ] Sol plan review after 2026-09-20 14:36, then SYNTHESIS-2026-09.md and fold into PLAN.md
- [ ] Scaffold: project.yml + build.yml + deploy.yml adapted from shortless-ios, CI green on macos-27
- [ ] Week 1 (plan section 9): single-screen recorder, mocked capture, XCTest

## Open Loops
- Sol plan review NOT run: ChatGPT Plus usage limit until 2026-09-20 14:36. Re-dispatch plan section 8 row 1 after that; then fold both reviews into PLAN.md sections 4-5 in one pass.
- The hosted runner has no iOS 27.1 SDK yet (checked 2026-09-18). Pivot date 2026-10-10 (plan section 5).
- Outer-display touch interactivity unconfirmed -- transcripts / prompt A.

## Git state
- Branch: main (local only until the remote exists)
