# Handoff 2026-10-03 -- S2b dispatch (S5 pipeline live)

<!-- READ-FIRST:START -->
**State:** main `948973a`. S5 pipeline LIVE: TestFlight build 1.0 (6.1) uploaded 10-02 (deploy run 36989598761). S2b spec written + Sonnet-reviewed: docs/S2B-LIBRARY-SPEC.md (Part A = index/library/recovery/delete/export UI, 55 tests; Part B = screenshot UI test).
**Next:** 1. Check Kimi quota, then `/orchestrate` S2b **Part A** from the spec (Kimi 403'd on 09-30; fallback = Opus writes it, S4 precedent). 2. Kimi layout review, then Sol audit (data-loss paths, spec "Sol audit focus"). 3. Part B as a second dispatch.
**Waiting on Perry:** device run of the 4b-recorder checklist on 6.1 (ai/STATE.md S5); recorder-screenshot choice (default dark gradient vs a real device shot, spec Part B "Open item").
**In flight:** nothing. `.orchestrate/` is untracked scratch, ignore.
**Traps:** profile name must be "StoryCue AppStore". `!`-prefixed `gh secret set` saves an EMPTY value. Another storycue session may share this checkout: `git status` before committing. Repo is PUBLIC: no secret values anywhere.
<!-- READ-FIRST:END -->

## Detail

### S5 (10-02)
All five operator acts done; full record in ai/STATE.md S5 bullet (commit `3c7f80e`).
- Cert expires 2027-03-14. Profile "StoryCue AppStore" (first named "StoryCue App Store" by
  mistake, archive failed, renamed). ASC record StoryCue, Apple ID 6818468570, SKU storycue.
- 7 secrets set. storycue has its OWN `.p12` (`C:\tmp\apple-signing\storycue.p12`, `-legacy`,
  rebuilt from distribution.key + .pem) because the original `.p12` password was lost; Perry's
  new password is in his password manager.
- `storycue/.claude/settings.local.json` (globally gitignored) allows
  `gh secret set|list -R pmartin1915/storycue`.
- Remaining for S5: Perry's device checklist on 6.1, plus the IDEAS item "deny camera → Open
  Settings → grant → does iOS relaunch?". Export/playback is 4b-export, after S2b lands.

### S2b spec
- `89e83f9` first draft; `948973a` revision after a fresh-context Sonnet review (20 findings,
  19.5 accepted; adjudication at the end of the spec). Biggest fixes: `finish` never deletes a
  nil-outcome clip with bytes; `delete` verifies files are gone before touching ledger/index;
  ledger-synthesized segments are `.failed(kept: true)`; `load()` blocks mutations until loaded.
- ASC screenshots: verified 10-02 that one 6.9" set suffices (STRATEGY's 6.9"+6.5" pair is stale).
  Part B uses a new `workflow_dispatch`-only `screenshots.yml`; build.yml stays PR-only.
- Two accepted gaps logged in ai/IDEAS.md (untracked .mov files; unkept partials in kept sessions).
- Dispatch per the spec header: Opus spec → Kimi implement → Kimi layout review → Sol audit.
  Code goes through a PR (docs/state go straight to main).
