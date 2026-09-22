# Strategy review 2026-09-22 — Kimi + Sol, adjudicated

Subject: `docs/STRATEGY-2026-09-22.md`. Both reviewers ran read-only through PAL `clink`.
Verdicts: **accept** (folded into the strategy), **partial**, **defer** (to `ai/IDEAS.md`),
**reject** (with reason). Claims were spot-checked against the repo before accepting.

## Kimi — remaining work to a submittable single-screen 1.0

`clink cli_name=kimi role=codereviewer`, 238 s, return_code 0, 19 tool calls. Brief: list what
the strategy is missing between today's code and a build that passes App Review and rung 4b.

| # | Finding | Verdict | Where |
|---|---|---|---|
| 1 | `TARGETED_DEVICE_FAMILY` unset; XcodeGen's iOS preset is universal → mandatory iPad screenshots, untested iPad layout | **accept**, verified (grep: absent in both project.yml) | S0, both apps |
| 2 | No camera/mic permission request anywhere (grep: zero `requestAccess`/`authorizationStatus`); no denied/revoked UI | **accept**, verified | S1 (service auth API + mock) + S2a (UI) |
| 3 | Mic denied → silent video-only clip with no warning (`AVCaptureService` drops audio input best-effort) | **accept** | S2a "no audio" state |
| 4 | Deck copy is `// TODO copy`; S4 must gate the archive; UI test asserts no "TODO" in question text | **accept** | S4 becomes a submission gate |
| 5 | Photos add-only authorization never requested (usage string exists, call doesn't) | **accept** | S3 |
| 6 | Storage-full / file-output failure collapsed into `.failed(kept:)`, no user-visible state | **accept** | S3 error mapping + S2b UI |
| 7 | `SegmentLedger.orphanedEntries()` has no caller and no UI destination | **accept** | S1 detection, S2b library surface |
| 8 | `AVAudioSession` category set with `try?`, never `setActive(true)`, no route-change handling | **partial**: the half-configuration is real, but the fix is the opposite — `AVCaptureSession.automaticallyConfiguresApplicationAudioSession` (default `true`) owns category + activation for capture, so the manual `setCategory` is the bug; delete it, keep automatic. Route changes: capture session handles mic routing; no 1.0 work | S1 spec §2 |
| 9 | `.reduceFrameRate` / `.recreateCaptureSession` effects have no implementation | **accept** | S1, explicitly in scope |
| 10 | Non-Duo 6.9"/6.5" ASC screenshot set has no owner | **accept** | S2b capture + S6 assembly |
| 11 | Age rating + privacy nutrition-label answers unnamed | **accept** | S6 checklist |
| 12 | 10-minute cap has no `SessionEvent` | **accept** | S1 (event) + S2a (timer) |
| 13 | `CaptureService` exposes no preview source | **accept** | S2a extends protocol + mock in same dispatch |
| 14 | Library needs delete / free-space | **accept** | S2b |
| 15 | "Share" from PLAN §2 not in S3 | **partial**: share sheet ships (it's the same `UIActivityViewController` Files export uses); no in-app social targets (PLAN non-goal) | S3 |
| 16 | Landscape allowed; rotation finishes segments; needs a decision | **accept** — decision: recorder locks to portrait for 1.0 (UI orientation lock on the recorder screen), capture rotation via the rotation coordinator per PLAN §1 | S2a |
| 17 | Dynamic Type / accessibility | **accept** as spec line, not a gate | S2a/S2b |
| 18 | PrivacyInfo declares UserDefaults CA92.1 with no UserDefaults in code | **accept** — reconcile in S6's code-vs-policy pass (a later UI may add UserDefaults; decide then) | S6 |
| 19 | Consent read-aloud line is UI copy, must not depend on S4 | **accept** | S2a |
| 20 | `deviceUnavailable` (and simulator) has no UI state | **accept** | S2a |
| 21 | S2 too big for one dispatch → S2a recorder core, S2b library/debug/screenshots | **accept** | strategy |
| 22 | S3 borderline; consider splitting Photos from stitching/Files | **partial** — one spec, two dispatches if the spec runs long | S3 |
| 23 | S1 at the ceiling; keep surgical | **accept** | S1 spec |

## Found while writing the S1 spec (neither reviewer raised it)

- **Recordings are written to `Caches/segments/`** (`AVCaptureService.makeSegmentFileURL`). iOS
  purges Caches under storage pressure, so a recording could disappear without any error.
  Moved to `Application Support/Segments/` in `docs/S1-SESSIONSTORE-SPEC.md` §1, with a CI
  test that the default directory is not Caches.

## Sol — sequencing, Xcode pinning, Retold reorder

`clink cli_name=codex role=codereviewer`, 1006 s, return_code 0, web search on. Checked runs
`35759964133`/`35769450879` itself and GitHub's runner-image release notes + Apple's ASC release
notes.

| # | Finding | Verdict | Where |
|---|---|---|---|
| 1 | Diagnosis right (one image is deterministic; the rollout makes the *outcome* vary). Per Apple's ASC release notes (2026-09-22): 27.1/27.2 **beta builds are allowed for internal and external TestFlight**; only Xcode 27 / 27 RC for App Store distribution. My "build number ≥ 5000 = beta" heuristic is undocumented; replace with a fail-closed **allowlist of App-Review-approved build numbers** (`27A266a`) and select the Duo Xcode by SDK only | **accept** — `select-xcode.sh` rewritten to Sol's shape; allowlist is `ASC_REVIEW_XCODE_BUILDS`, updated by hand when Apple approves another toolchain. Strategy wording corrected: beta *can* TestFlight | S0 |
| 2 | Missing "production vertical slice" between S1 and S2: durable storage (Caches), persistent session/library index, preview plumbing, auth + denial, audio session, storage/error UI, 10-min event, orphan recovery, **Release compile in CI** | **partial** — no new step; each item is now owned: storage, auth, audio, cap event, orphan detection → S1 spec; preview → S2a; persistent session index (atomic JSON snapshot of finished sessions) + storage/error UI → S2b; Release compile → S0 (added to build.yml in both repos) | S0/S1/S2a/S2b |
| 3 | S1 omitted the 4th IDEAS item: `fileOutputFinished` arriving while still `.recording` is dropped, then the late interruption wedges `.finishing` forever | **accept** — S1 spec §3b: matching-id callback while `.recording` finishes with `.outputEndedUnexpectedly` → `.paused`; late notification is then a no-op under existing guards; both orderings tested | S1 |
| 4 | First TestFlight on 10-06 has zero contingency; do Apple setup in S0 and push a minimal signed smoke build ~09-25..27; recorder-core TF 10-04..06, candidate 10-08..10; outer-preview panel off the 1.0 critical path | **accept, pending Perry** — the operator acts are Perry's time in his heaviest week (slides 9/28, talk 10/1). Strategy now asks for them ASAP with 10-03 as the hard latest, and a smoke build the day secrets exist. Outer-preview panel moved to S9 (it previews the outer display, which 1.0 doesn't use) | strategy |
| 5 | Retold R1–R5 before R6 is sound; but R1 must start with a **SwiftData schema spike** (`Confirmable<T>` inside `@Model` is unproven; iOS 27 adds `.codable` attribute option), round-trip every entity through in-memory and on-disk containers; flatten if generic persistence is unstable; define `VerifiedSpan`, `TranscriptionStatus`, `UserCorrection`, `RejectedProposal`. Re-run R2's template integration after R3's deck | **accept** | R1/R2 |
| 6 | "No code path persists `.model` as a fact" can't be proven before filing code exists; make it unrepresentable via restricted initializers / repository API, re-run the tests at R7 | **accept** — reworded | R1 |
| 7 | S9 claims rungs 2–3 but the Duo lane runs on `iPhone 17`; rung 3 needs a UI-test target on a Duo simulator destination gated by `DUO_SIM` | **accept** — S9 now claims rung 2 until that lane exists | S9 |
| 8 | Deploy verifies only `CFBundleVersion`; also verify `DTXcodeBuild`/`DTSDKBuild`, validate, poll ASC processing. Pin XcodeGen (StoryCue downloaded `latest`) | **partial** — `DTXcodeBuild`/`DTSDKBuild` read from the shipped `.ipa` and warned if not allowlisted (both repos); XcodeGen pinned to 2.46.0 in both StoryCue workflows. ASC processing poll → **deferred** to `ai/IDEAS.md` (needs an authenticated ASC API loop; Perry sees processing state in ASC anyway) | S0 |
| 9 | Retold STATE still had the duplicated old week-1 ordering | **already fixed** in the same session before the review landed | — |
