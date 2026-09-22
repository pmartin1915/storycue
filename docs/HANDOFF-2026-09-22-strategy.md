# Handoff 2026-09-22 (cross-app strategy, S0 landed, S1 spec ready)

First Opus 5.5 session on StoryCue + Retold. The brief was to organize and plan finishing both
apps with Kimi and Sol. Read **`docs/STRATEGY-2026-09-22.md`** first. It governs the order
for both repos.

## What changed in the picture

1. **StoryCue's "week 1 done" is only the domain layer.** There is no `SessionStore`, no screens,
   and `ContentView` is still the placeholder, so the app records nothing yet. The strategy
   resequences to a single-screen 1.0 by 10-16 (S0–S8), with the Duo path afterwards (S9 / 1.1).
2. **The runner image is mid-rollout.** `sort -V | tail -1` handed baseline *and deploy* a beta
   Xcode on some runs. Beta builds may go to TestFlight but not to App Review (Sol, from Apple's
   ASC release notes). The earlier STATE claim that "the runner now has the Duo SDK" was not
   steady state.
3. **Recordings were written to purgeable Caches.** Moving them is in the S1 spec.
4. **Retold reordered:** CI-provable logic first (R1–R5), device-gated recorder after 10-16.

## Done this session

- Strategy doc, reviewed by **Kimi** (23 findings, remaining-work gaps) and **Sol** (9 findings:
  Xcode allowlist, early-callback race, TestFlight timing, Retold schema spike). All adjudicated in
  `docs/reviews/STRATEGY-REVIEW-2026-09-22.md`.
- **S0 landed in both repos** (storycue `1bcf70c` + fix-forward `5552678`; retold `b650c1b` +
  `31a837a`). CI green: storycue run `35775511198` (59/59, Release compile passed), retold run
  `35775513678`, both on the allowlisted `Xcode_27_Release_Candidate.app`: `.github/scripts/select-xcode.sh` picks baseline/deploy Xcode from the App-Review
  allowlist `ASC_REVIEW_XCODE_BUILDS` (fails closed) and the Duo lane Xcode by SDK. Deploy archives
  Duo only on an explicit `duo=true` dispatch and reports the shipped `.ipa`'s `DTXcodeBuild`.
  Also: unsigned Release compile in CI, XcodeGen pinned to 2.46.0, docs-only pushes skip the
  build, and `TARGETED_DEVICE_FAMILY: "1"`. One fix-forward: `/usr/bin/realpath` doesn't exist
  on the runner, so it now uses `cd -P && pwd -P`.
- **`docs/S1-SESSIONSTORE-SPEC.md` is written and passed Kimi's pre-dispatch review** (13
  findings, all folded, including 4 that would not have compiled or would have failed tests).
  It is ready for `/orchestrate`.

## Next session, in order

1. Check session-claims for a live storycue peer first (the week-1 `.orchestrate/spec.md`
   collision came from exactly that). Then dispatch S1 via `/orchestrate` (Kimi executor) and have Sol audit the diff. The spec
   names 18 + 6 + 3 + 1 tests.
2. Write the R1 spec for Retold (the SwiftData schema spike comes first; see strategy R1). Dispatch
   it in the gap while S1 is in Sol's audit.
3. Write the S2a spec (recorder core UI).

## Needs Perry

- **Operator acts for both apps in one sitting, as early as you can manage. The hard latest is
  10-03** (strategy "Perry's operator acts"): check the certificate's expiry, then create two
  App IDs, two App Store profiles, two ASC records, and GitHub secrets on both repos. A session
  pushes a signed smoke build to TestFlight the same day.
- Retold prompt D re-run (optional; Labs toggle off).

## Verify this handoff

- `git log --oneline -5` in both repos shows the ci + docs commits; both are even with `origin/main`.
- Latest Build & Test run in each repo: the "Select Xcode" step summary names
  `Xcode_27_Release_Candidate.app` (or another allowlisted build) as the baseline, and the Release
  compile step passes.
- `grep -n ASC_REVIEW_XCODE_BUILDS .github/scripts/select-xcode.sh` shows `27A266a`.

## Do not

- A red "Select Xcode" once the image ships a GA Xcode is the allowlist working. Check the printed
  Xcode table against Apple's ASC release notes: a GA (non-beta) 27.x is approved by definition, so
  add its build to `ASC_REVIEW_XCODE_BUILDS`. Betas never go on the list.
- The Duo lane and the `DUO_SIM` check under the alternate `DEVELOPER_DIR` have not run yet (the
  green run landed on the RC-only image). The first run on the 27.2-beta image proves them.
- Don't start Duo-path code before S5 (rung 4b) passes.
- No AI attribution on commits.
