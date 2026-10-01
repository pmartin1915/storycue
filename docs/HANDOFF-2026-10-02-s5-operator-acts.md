# Handoff 2026-10-02 -- S5 operator acts (signing pipeline for the device window)

<!-- READ-FIRST:START -->
**State:** main at `f620e37`. S0-S4 merged, CI 172/172 on both lanes. S5 (rung 4b-recorder on the 16 Pro via TestFlight) is next. The signing pipeline has never run: `gh secret list -R pmartin1915/storycue` was empty as of 2026-10-01.
**Next:** 1. Walk Perry through the five Apple acts below, one at a time. 2. Load the 7 secrets with `gh secret set`, with each value piped from a file Perry names. 3. Smoke-run `deploy.yml` via `workflow_dispatch` with `upload=false`, then `upload=true` once it is green.
**Waiting on Perry:** every Apple portal click (cert, App IDs, profile, ASC record); the final app name before the ASC record exists; the source files for the secrets.
**In flight:** nothing.
**Traps:** the repo is PUBLIC, so never echo a secret value into a commit, a doc or this transcript. The secrets cannot be copied from shortless-ios, because GitHub never returns secret values; they come from Perry's local files. Rename the app BEFORE creating the ASC record (free before, not after). Hard latest for all of this is 10-03.
<!-- READ-FIRST:END -->

## Detail

Source of truth: `ai/STATE.md` S5 bullet (lines 60-67). This handoff turns that list into steps.

### The five Apple acts (Perry clicks; you guide and verify)

1. **Distribution certificate expiry.** developer.apple.com > Certificates. If the Apple Distribution
   cert expires before ~2026-11 (S8 submits by 10-16, and updates follow), recommend renewing now. A new
   cert means a new `.p12` for `APPLE_CERTIFICATE_P12`/`_PASSWORD`, and the shortless-ios, burn-wizard,
   wilderness and retold secrets would then need updating too. Say that before he renews.
2. **App IDs:** `dev.pmartin1915.storycue` and `dev.pmartin1915.retold` (same sitting). The repo has no
   entitlements file and `project.yml` declares no capabilities (checked 2026-10-01), so the defaults
   are correct. Don't tick extra capabilities.
3. **App Store provisioning profile** for `dev.pmartin1915.storycue`, using the distribution cert from
   act 1. He downloads the `.mobileprovision`.
4. **ASC app record.** Ask the name question first. "StoryCue" is "for now", and an unverified Gemini
   report suggested abandoning it (STATE Open Loops). The SKU and bundle ID are fixed once created.
5. **GitHub secrets**, 7 total. Names are from `deploy.yml`:
   - `APPLE_CERTIFICATE_P12`: the base64 of the `.p12`
   - `APPLE_CERTIFICATE_PASSWORD`
   - `APPLE_TEAM_ID`: `NN8F5WX25R` (already public in `project.yml`)
   - `APP_STORE_CONNECT_API_KEY`: the full `.p8` text, starting `-----BEGIN PRIVATE KEY-----`
   - `APP_STORE_CONNECT_API_KEY_ID`
   - `APP_STORE_CONNECT_API_ISSUER_ID`
   - `PROVISIONING_PROFILE_APP`: the base64 of the storycue `.mobileprovision` from act 3

   The first six match the ones shortless-ios already holds (same team, cert and API key). How Perry
   produced them the first time is in `shortless-ios/CI_SETUP.md`.

### Loading secrets without leaking them

Perry gives you a file path; the value never prints:

```bash
base64 -w0 "<p12 path>" | gh secret set APPLE_CERTIFICATE_P12 -R pmartin1915/storycue
gh secret set APP_STORE_CONNECT_API_KEY -R pmartin1915/storycue < "<p8 path>"
base64 -w0 "<mobileprovision path>" | gh secret set PROVISIONING_PROFILE_APP -R pmartin1915/storycue
```

The password, the key ID and the issuer ID are short strings. Have Perry run `gh secret set NAME -R pmartin1915/storycue` himself
with the `!` prefix, so he types the value at the prompt rather than into chat. Verify by name only:
`gh secret list -R pmartin1915/storycue` should show 7 rows.

### Smoke run

`gh workflow run deploy.yml -R pmartin1915/storycue -f upload=false -f duo=false`. Perry triggers it or
approves it. It is green when archive and export succeed. Check that the "Using:" line names the release
Xcode, not a beta (S0's `select-xcode.sh`; see the allowlist trap in STATE). Then run with `upload=true`
so the build reaches TestFlight. After that, Perry runs PLAN §5 rung-4b's **recorder** checklist on the
16 Pro. Export and playback are deferred to after S2b (STATE line 67).

### Close-out

Update `ai/STATE.md` S5 with what got done, including cert expiry date, run IDs and the TestFlight build
number. Commit docs straight to main (PR-only applies to code). Then spec S2b.
