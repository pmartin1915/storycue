# Synthesis: iPhone Duo research → PLAN.md §1 / §4 / §5 dispositions, and week-1 inputs

**Sources folded (one pass, 2026-09-21):**
`PROMPT-A-ship-path-REPORT.md` and `PROMPT-B-product-REPORT.md` (Gemini Deep Research,
2026-09-18); Apple Tech Talk transcripts 111461, 111463, 111464, 111465 (`docs/techtalks/`);
Kimi plan review `docs/reviews/PLAN-REVIEW-2026-09-18.md` (accepted findings 1, 2, 4, 5;
finding 3 rejected with replacement); Sol plan review `docs/reviews/SOL-PLAN-REVIEW-2026-09-21.md`
(see §S below); a re-read of `actions/runner-images` `images/macos/xcode-27-arm64-Readme.md`
on 2026-09-21; Apple Developer Forums thread 847137 (read directly 2026-09-21).

**Adjudicated:** 2026-09-21 session (Fable, laptop). Every verdict below is on the claim, not
the reporter. ESTABLISHED = a primary source (Apple transcript, Apple forum thread with an
accepted answer, the runner README) says it; INFERRED = a secondary source or a report's
reasoning, plausible, not independently checked; UNVERIFIED = neither, or the report's own
citation does not support it. `PLAN.md` is edited in the same pass as this file so the two
cannot drift; the edit list is at the bottom.

**Citation quality.** PROMPT-A: mixed. Its API-surface section is consistent with the
transcripts, but its headline claim about the 27.1 beta cites the *27.2* release notes (see
Q2), and its "self-hosted Mac is mandatory" conclusion ignores the brief's stated constraint.
PROMPT-B: good on competitors, law and human factors; its trademark search is **self-described
as simulated** (its §7), so the naming section carries no evidence weight. Transcripts: primary,
and 111461/111465 answer questions the plan had left open.

**The one-line takeaway:** nothing in the research moves the load-bearing constraint — the
hosted `macos-27` runner still has no 27.1 SDK and no Duo simulator (re-checked 2026-09-21,
image `20260912.0186.1`, unchanged since 2026-09-18) — but the research does settle the API
surface, adds a camera-switching mechanism the plan had not named, and hands week 1 a list of
product rules that are cheaper to build in than to retrofit.

---

## Q1. Is `CameraCaptureAccessory` the mechanism, and can the subject touch it?

- **ESTABLISHED (111464 5:00–6:32):** `CameraCaptureAccessory` is registered with the SwiftUI
  `sceneAccessory` modifier *on the camera view*, so the outer content exists exactly while the
  camera view is visible; it is "available when your app is full screen on the inner display,
  and your app has an active camera session"; it carries an enabled state driven from a model
  and `onAvailabilityChange` reports when the device state (e.g. closed) makes it unavailable.
  Apple's worked example is a teleprompter. The outer display "cannot create new windows"
  (111464 3:38) — there is no second mechanism for a third-party app.
- **ESTABLISHED (111465 4:49–5:31):** in the two-display case the app has **two `UIView`s at
  once**, one per display, and creates **a separate `AVCaptureDeviceDirectionCoordinator` for
  each**; "camera apps can enable this using the SceneAccessories API." So the accessory view
  is a real view with its own geometry, not a mirrored image.
- **ESTABLISHED (Apple DocC JSON for `CameraCaptureAccessory`, read directly 2026-09-21):**
  availability iOS 27.1 (beta); overview: "The accessory may be presented while the app is in
  the foreground and has an active camera capture session. The system determines whether and
  where to present it. **Unlike ExternalNonInteractiveAccessory, the content can be
  interactive.** For example, you can present a teleprompter that the person being captured
  can read while looking toward the camera." The code sample is exactly the plan's shape
  (`CameraView(...).sceneAccessory { CameraCaptureAccessory { TeleprompterView(...) } }`).
  **So PROMPT-A's "strictly non-interactive" (its §1, "Confidence: High") is wrong**: the
  sentence it quotes — "Register a scene accessory to present noninteractive content on the
  connected display…" — is from the UIKit article *Presenting content on a connected display*
  (also read directly 2026-09-21), which is about `ExternalNonInteractiveAccessory` /
  `windowExternalDisplayNonInteractive` for cabled/AirPlay displays and never mentions
  cameras or iPhone Duo. Sol's review (finding 4) caught this independently.
  **Two corrections to `ai/STATE.md`:** it recorded touch as "RESOLVED by 111465 transcript +
  PROMPT-A report." Neither transcript says anything about interactivity (a grep of all four
  for "interact" finds only hinge *interactions* and safe-area "interactive controls"), and
  the report's claim was a conflation. **Design decision unchanged:** v1's outer view is
  display-only — not because the platform forbids touch, but because nothing Perry owns can
  verify hit-testing on the outer panel before launch, and a tappable subject-side prompt is a
  feature, not a requirement. Reopen at 1.x with rung-5 evidence.
- **UNVERIFIED (PROMPT-A's own "unknown" list, and nothing here contradicts it):** accessory
  behaviour at `.partiallyOpen`; what happens on an incoming call or thermal interruption;
  outer-display safe areas / corner radii; whether Dynamic Type scales inside the accessory.
  The session state machine treats *every* one of these as "accessory may vanish, clip must
  survive" (see Q3 and §S).

**Changes:** §1 table — replace the "unconfirmed touch" cell with the DocC verdict and the
v1 display-only decision; add the two-views/two-coordinators fact and the UIKit spelling
(`UISceneAccessory.cameraCapture`, per Sol). `ai/STATE.md` Open Loop — rewrite.

## Q2. Xcode 27.1, the Duo simulator, and the hosted runner

- **ESTABLISHED (runner README, 2026-09-21):** `macos-27` = macOS 27.0 (26A5406e), image
  `20260912.0186.1`, one Xcode (27.0, build 27A266a), SDKs `iphoneos27.0` /
  `iphonesimulator27.0` only, simulator runtime iOS 27.0 with iPhone 17 / 17e / 18 Pro /
  18 Pro Max / Air. **No Duo, no 27.1.** Same as 2026-09-18.
- **ESTABLISHED (Apple forum thread 847137, accepted answer):** the Xcode 27.1 beta *does*
  surface an iPhone Duo simulator — but only after the iOS 27.1 beta simulator runtime is
  (re)downloaded from Settings → Components; several developers reported it missing until they
  did that. The sentence PROMPT-A quoted at "Confidence: High" — Duo SDK and simulator "will be
  available later this month in an upcoming release of Xcode 27.1" — is from the **Xcode 27.2**
  beta release notes, exactly as its own footnote 1 is titled. The report conflated the two.
  This resolves the STATE.md open loop in favour of the press coverage (MacRumors 2026-09-18).
- **UNVERIFIED:** Apple's Xcode 27.1 release-notes page itself (JS-rendered, title only on
  2026-09-21). Not worth more effort: **it is operationally moot.** Perry has no Mac, so what a
  local beta can do never enters the plan; only the hosted image does, and that is measured.
- **INFERRED (PROMPT-A, medium):** hosted runners lag point-release betas by weeks; 27.1 on
  `macos-27` "late October or early November." That would be after the 10-16 submission and
  after launch. Consistent with the plan's 10-10 pivot condition; nothing to change except
  to say the pivot is the *expected* path, not the exception.
- **ESTABLISHED (111461 0:30):** an app built with the **iOS 27.0 SDK runs on iPhone Duo** —
  when closed it uses the screen left of the status bar and camera; when open it is "a
  familiar size and aspect ratio." So the pivot build (1.0, single-screen recorder) installs
  and works on every Duo sold on 10-23; it just does not use the outer display. That is a
  materially better pivot than the plan describes.
- **DECLINED in writing (PROMPT-A §2 and executive-summary point 5):** "transitioning to a
  self-hosted Mac mini or EC2 Mac is mandatory." The brief's constraints — no Mac, no Duo, no
  spend on hardware — are locked (Perry, 2026-09-18). PROMPT-A's cost facts are accepted and
  make §4.3 sharper: `xcodes install` on a hosted runner is ~35 GB per job, un-cacheable, and
  "operationally prohibitive"; EC2 Mac has a 24-hour minimum. §4.3 stays a last resort with
  those numbers attached, and the pivot stays the default.

**Changes:** §1 row on Xcode 27.1 (simulator-runtime nuance; moot); §4.1 re-check date; §4.3
costs; §5 pivot paragraph gains the 27.0-runs-on-Duo fact and "expected path" framing.

## Q3. The camera API surface the plan did not name (111465)

All ESTABLISHED, from the transcript:

- iPhone Duo has **two front cameras**, both square ultrawide sensors: outer (up to 4K/120)
  and inner (under-display, 1080p/60). Discovery with `.front` + wide/ultrawide returns a new
  **Virtual Front Camera** `AVCaptureDevice` that auto-switches inner↔outer on open/close and
  exposes only the common capabilities (1080p/60, no depth).
- Individual devices: **built-in outer ultrawide** and **built-in inner ultrawide** device
  types. If the app uses them, *the app* must switch on fold via
  **`AVCaptureDeviceDirectionCoordinator`** (in AVKit, main-actor, tied to a `UIView`), whose
  change handler delivers an **`AVCaptureDeviceDescriptor`** (sendable) to pass to the capture
  actor, which reconfigures the `AVCaptureSession`. Mirroring should follow "forward-facing."
- Rear cameras become "forward-facing" when the phone is flipped open — the filmer-holds-inner,
  subject-faces-outer posture StoryCue wants is, in coordinator terms, *rear cameras
  forward-facing relative to the outer view*.
- **Rotation coordinator** updates when the app moves displays; adopt it, then disable
  camera-sensor-orientation compensation.
- Preview: `AVCaptureVideoPreviewLayer.videoGravity`; `dynamicAspectRatio` to use the square
  sensor for a landscape preview on the inner display.

**Consequence for week 1 (this is the decision):** the `CaptureService` protocol must abstract
*which physical camera is active and why*, not just start/stop. v1 uses the Virtual Front
Camera for selfie mode and the rear camera for the filmer posture; the direction coordinator
is Duo-path (week 2, under the gate) and its change handler is one more "camera may
reconfigure mid-clip" event the state machine must model (§S). Do not build v1 on the
individual inner/outer device types — they do not exist on the 27.0 SDK the runner has.

**Changes:** §1 gains a camera row; §4.5 names the coordinator handler as a tested transition.

## Q4. Testing without hardware (§5 ladder)

- **INFERRED (PROMPT-A §5, medium):** `xcrun simctl` has no documented sub-command to set
  posture or hinge angle; posture in the simulator is Device Hub (GUI). Headless posture
  testing in CI is therefore **not available** as far as anyone has found; the workaround
  (an env var the *app* reads to fake an angle) tests the app's own branch, not the OS. So
  rung 3 shrinks: it can run layout tests on both display *sizes* and take screenshots, but
  cannot drive fold/unfold. Hinge transitions are tested at rung 1 through the mocked
  `hinge` context, which was already the plan.
- **UNVERIFIED (PROMPT-A, low):** whether the Duo simulator renders `CameraCaptureAccessory`
  content at all without a real capture session. Until someone with a Mac reports it, rung 3
  proves layouts on the inner display and rung 4 (the in-app "outer preview" panel) proves the
  accessory *view*. Rung 5 (testers with a Duo) remains the first real accessory evidence.
- **Kimi finding 4 (accepted) applies here:** SDK-headers presence (`-showsdks` lists
  `iphoneos27.1`) and simulator-runtime + Duo device-type presence (`simctl list`) are
  **separate facts** on the image and can land on different days. Rung 2 and rung 3 get
  separate printed checks.
- **Kimi finding 1 (accepted, narrowed):** when 27.1 lands, run XCTest on **both** a 27.1 and
  a 27.0 simulator runtime so the `#available(iOS 27.1, *)` fallback branch is executed, not
  assumed.
- **Kimi finding 2 (accepted):** rung 6 overclaims; App Review exercises a happy path, and
  there is no crash telemetry because nothing leaves the device. Softened.
- **UNVERIFIED (PROMPT-A):** whether App Review tests on Duo hardware at all; whether any
  device farm has a Duo. Neither changes the ladder.
- **ESTABLISHED (PROMPT-A, historical pattern; consistent with Apple policy):** TestFlight
  *external* distribution rejects builds compiled with a beta SDK until the RC. Rung 5 is
  therefore gated on the 27.1 RC, which Apple has historically tied to hardware availability
  — so rung 5 lands on or about 10-23, exactly as §5 says. No change, but it is now a
  *reason* rather than an assumption.
- **Kimi finding 5 (accepted, minor):** rung 5 has no recruitment path. PROMPT-A §5 supplies
  one: public TestFlight link posted to developer Discords, X and Reddit with a request for a
  10-second clip in exchange for access. Week-3 task, one line.

**Changes:** §5 table rows 2, 3, 6; a recruitment line under rung 5; pivot paragraph.

## Q5. Submission timing, ASC metadata

- **INFERRED (PROMPT-A §3, from 16.1 / 18.1 precedent):** App Store acceptance of 27.1-SDK
  builds opens "the third week of October," i.e. around 10-23. Combined with Q2, a 27.1 build
  is not submittable by 10-16 on any path Perry controls. The 10-16 submission is the 27.0
  build; the Duo build is 1.1. **This is now the plan of record, not the fallback.**
- **ESTABLISHED as of 2026-09-18 (PROMPT-A §3, forum-sourced):** Duo screenshot specs are
  published (outer 1398×2034 pt, inner 2007×2853 pt) but ASC has no Duo slot in the device
  selector and the API's `ScreenshotDisplayType` has no Duo case. Metadata prep can start;
  upload waits on Apple. Matches §1's last row; adds the dimensions.

**Changes:** §1 ASC row (dimensions); §9 week-4 gate wording ("27.0 build by 10-16; 27.1
build as 1.1 when both the runner and ASC accept it").

## Q6. Featuring and developer relations

- **ESTABLISHED (Apple's featuring page via PROMPT-A):** nomination through App Store
  Connect, ≥2 weeks lead, prefers freemium apps and polished previews. §6 already says this.
- **INFERRED (PROMPT-A §4):** online "iPhone Duo Photos & Camera" / SwiftUI / UIKit Q&A
  sessions on **2026-09-23**, App Review appointments 09-22 → 09-25, Paris workshop 09-28.
  Paris is irrelevant. The 09-23 online Q&A is the one place a question about accessory
  behaviour on interruption (Q1's unknowns) could be put to an Apple engineer, and it is two
  days out and the day before Perry's slides deadline. **Operator option, not an obligation;
  recorded here so it is a choice and not a discovery on 09-24.**

**Changes:** none to §1/4/5; one line in §7 (operator acts).

## Q7. Product research (PROMPT-B) → §2 and the week-1 spec, not §1/4/5

These are ESTABLISHED at the level PROMPT-B could establish them (competitor reviews, statute
text, Library of Congress pages) and they are week-1 build inputs. They are listed here so the
week-1 spec inherits them; §2 gets one paragraph pointing here rather than absorbing them.

| Rule | Basis | Where it lands |
|---|---|---|
| **Pause** is mandatory; a stopped session must resume, never restart | StoryCorps app reviews: no pause → lost recordings | State machine: `recording → paused → recording` is a first-class transition |
| **Countdown only to start** (3-2-1), then a static tally dot and a **count-up** timer; never a countdown to the end | Broadcast practice; StoryCorps review quoting panic at a 40-min timer | Outer view + inner view; no max-length UI at all |
| **Clip cap 10 min** per question, encourage short clips | Oral-history practice: elderly narrators fatigue at 30–45 min; file size | Capture service: soft stop at 10:00 with "keep going?" on the *inner* display only |
| **Next-question preview** small at the bottom of the outer view | Cognitive-load argument (PROMPT-B §6) | Outer view; Kimi layout review target |
| Outer type: **48–60 pt**, 4–6 words per line, ≥7:1 contrast, black background | Visual-angle arithmetic for 1–2 m; WCAG AAA | Outer view. **Atkinson Hyperlegible** is recommended; it is OFL-licensed and bundling a font is trivial, but it is a Kimi-review question, not a v1 requirement — SF Pro heavy is the fallback |
| **Write every question ourselves.** StoryCorps "Great Questions" are copyrighted / CC-NC; do not ship them. VHP (Library of Congress) questions are **public domain** and may ship verbatim in a veterans deck | Copyright status per PROMPT-B §2 | Decks: original copy for the five v1 decks; a VHP-sourced veterans deck is a free sixth deck if there is time |
| **Consent:** first outer prompt is a read-aloud line — "I understand this is being recorded, and I am ready to begin." — plus the persistent Recording indicator | Cal. Penal Code §632 "confidential communication" test; one-party federal baseline | Consent card (inner) + first outer card; this is the plan's consent feature made concrete |
| **General audience** category, not Kids; COPPA does not apply (no online collection); GDPR household exemption | PROMPT-B §3 | ASC record (Perry); privacy policy text |
| `PrivacyInfo.xcprivacy` declares camera/mic access; labels say local-only | Apple requirement | Scaffold, day one (already in the plan) |
| **Free download + one-time unlock** rather than paid-up-front or subscription; StoreKit 2 verifies on-device with no server | Featuring preference; competitor resentment of lock-in | **Perry decision, deferred.** v1 as planned is free with all decks; IAP is a 1.x question. Recorded so the deck model is designed with an `isIncluded` bit from the start |
| **Name.** PROMPT-B says abandon "StoryCue" (crowded "Story-" prefix; "cue" in teleprompter trademarks) and offers DuoTale, Prompted, Heirloom Duo, Recollect, OuterStory | **UNVERIFIED — the report says its search was simulated** | Name is locked "for now" (Perry, 2026-09-18) and a rename before the ASC record is free. Perry call; no evidence weight either way |

## §S. Sol plan review (2026-09-21)

Raw body: `docs/reviews/SOL-PLAN-REVIEW-2026-09-21.md` (943 s, `return_code 0`, cites
file:line in the supplied files, web search against Apple DocC). It agrees with Kimi's
accepted verdicts 1, 2, 4 and did not repeat them. Six findings; verdicts here.

| # | Sol | Verdict | What it changes |
|---|---|---|---|
| 1 | **Blocking.** The gate is underspecified: `#available` is runtime-only and cannot resolve 27.1 symbols against a 27.0 SDK; `#if DUO_SDK` compiles them but gives no runtime protection. `.sceneAccessory` is 27.0 but `CameraCaptureAccessory` is 27.1, so the *whole accessory expression* must be compile-gated. `canImport(SwiftUI/AVKit)` cannot detect the surface (the modules exist in 27.0). Passing `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DUO_SDK` on the command line **replaces** inherited conditions (`DEBUG`) and hits every target incl. XCTest. Probe and build must share one `DEVELOPER_DIR`. | **ACCEPT, in full.** | §4.2 rewritten: one selected Xcode for both `xcrun --sdk iphoneos --show-sdk-version` and the build; the workflow passes a *custom* setting (`STORYCUE_DUO_CONDITIONS=DUO_SDK`) and `project.yml` expands it as `$(inherited) $(STORYCUE_DUO_CONDITIONS)` **only** on the app target and a dedicated `StoryCueDuoTests` target; declarations `@available(iOS 27.1, *)`, call sites `if #available`; `xcodebuild -showBuildSettings` printed per target. At ≥27.1 the workflow runs two lanes, flag off and flag on — which also delivers Kimi finding 1 (both runtimes). |
| 2 | **Blocking.** "Fold → pause → resume" is unsafe for a file that is being written. Capture-session state, file-writing state, accessory availability and scene state are independent. On any discontinuity (fold, `onAvailabilityChange(false)`, direction-coordinator change, call/audio interruption, resign-active/background, thermal shutdown, runtime error, media-services reset) the correct move is `stopRecording()` → `finishing` → wait for `fileOutput(_:didFinishRecordingTo:from:error:)`, keep the file even on error (`AVError.recordingSuccessfullyFinished`), never reconfigure the session before that callback, never resume silently; durable temp-file ledger for crash recovery. | **ACCEPT, in full.** This is the finding that changes the product model. | §1 hinge row, §2 ("a clip is a sequence of physical segments"), §4.5 (the event table is the state-machine test list). Reconciles with PROMPT-B's *pause* rule: the user-facing Pause finishes the segment; Resume starts a new one; export stitches. Week-1 spec inherits Sol's event table verbatim. |
| 3 | **Blocking.** Rung 1 (mock) proves reducer logic only; the plan calls the pivot build "fully tested" with nothing having exercised permissions, A/V sync, codecs, file finalization, low storage, interruptions, rotation or export. The constraint is no Duo and no Mac, **not** no iPhone — Perry carries an iPhone 16 Pro. Also "eyeball a SwiftUI preview in Xcode" is impossible without a Mac. | **ACCEPT.** | New §5 rung **4b**: internal TestFlight on Perry's iPhone 16 Pro before submission, with Sol's checklist (permission grant/deny/revoke; repeated clips; background / incoming call / rotation / termination; low-storage and orphan-temp recovery; Photos + Files export then playback). §4.5: the outer-preview mode produces `simctl` screenshot artifacts + snapshot assertions in CI instead of an Xcode preview. "Fully tested" in the pivot text now means rungs 1 + 4b. |
| 4 | **Should-fix.** Mechanism is right but "only" is too strong (UIKit `UISceneAccessory.cameraCapture(sceneConfiguration:)` is the same mechanism) and touch is **documented as interactive**, contrary to the plan's "unconfirmed" and the research's "strictly non-interactive." Alternatives (external-display accessory, new `UIWindowScene`, mirroring/widgets/Live Activities) do not fit the topology. | **ACCEPT**, verified at first hand (Q1). | §1 accessory row rewritten. v1 stays display-only (design choice, stated as such). |
| 5 | **Should-fix.** Rung 5 (launch-day testers) is post-launch validation; a 10-s clip does not prove the outer display showed anything. Adds: seek pre-submission hardware; ask testers for a *second-device* video of both displays; ship a privacy-safe **diagnostic export** (timestamps for scene phase, hinge state, accessory availability, interruptions/runtime errors, device descriptor, file-output completion); treat posture automation as unproven; recompile against each 27.1 beta/RC. | **ACCEPT** the second-device video, the diagnostic export (local file, user-initiated share — consistent with "nothing leaves the device"), and an explicit residual-risk line. **DECLINE** "seek a borrowed/rented device or Apple lab" as a plan action — hardware is a closed decision (Perry, 2026-09-18); rental stays "one look" in §5. "Recompile per 27.1 beta" is subsumed by the runner gate (there is nowhere else to compile). | §5 rung 5 text; "what the listing may claim" gains the residual-risk sentence; diagnostic export is a week-2 task under the gate. |
| 6 | **Should-fix.** `run_number` is a valid `CFBundleVersion` but re-runs repeat it and a renamed workflow restarts it; the .ipa read-back verifies **packaging**, not uniqueness in ASC — disagrees with Kimi review line 47 ("catches both"). Recommends `run_number.run_attempt`, a concurrency group, an ASC pre-query, stable workflow identity. | **ACCEPT** `run_number.run_attempt`, the concurrency group, stable identity, and the correction to the Kimi adjudication (Sol is right: read-back proves the number that shipped, not that ASC lacks it). **DEFER** the ASC pre-query to `ai/IDEAS.md` — it needs an authenticated API call in the deploy job for a collision that `run_attempt` + "never re-run past upload" already prevent for a solo dev. | §4.4 rewritten; `deploy.yml` design. |

Sol's "positive practices worth preserving" list (baseline non-Duo product, compile+runtime
gating, evidence ladder, mocked reducer tests, artifact-level .ipa check, honesty about the
simulator) is the plan's spine and is unchanged.

## Declined, in writing

1. PROMPT-A: self-hosted / rented Mac as mandatory infrastructure — constraint conflict (Q2).
2. PROMPT-A: "focus purely on abstract logic for the next one to two weeks" pending a Duo
   simulator — moot; there is no Mac to run one, and week 1 is the recorder regardless.
3. PROMPT-B §7 rename — no evidence (simulated search); Perry's call, not a research finding.
4. Kimi finding 3 as stated (`run_number` shared across workflows) — wrong per GitHub docs;
   the replacement (never re-run a deploy past upload; renaming the workflow resets the
   counter; keep the .ipa read-back) is a `deploy.yml` design rule — **with Sol's correction**
   that the read-back proves packaging, not uniqueness.
5. Sol 5's "seek a rented device / Apple lab" as a plan step — closed decision.
6. Sol 6's App Store Connect pre-query — deferred to `ai/IDEAS.md`, not rejected.

## What changes in PLAN.md (applied in this pass, 2026-09-21)

| Section | Edit |
|---|---|
| §1 | Accessory row → interactive per DocC, v1 display-only by choice, UIKit spelling, two views/two coordinators (Sol 4, Q1); hinge row → finish-the-segment (Sol 2); camera row (Q3); Xcode 27.1 row → component-download nuance + "moot" (Q2); ASC row → dimensions (Q5) |
| §2 | "A clip is a sequence of physical segments" (Sol 2) + one paragraph pointing at Q7's table as the week-1 product rules |
| §4.1 | Re-check date 2026-09-21, unchanged |
| §4.2 | Rewritten per Sol 1: single `DEVELOPER_DIR`, custom-setting indirection scoped to two targets, `$(inherited)`, `@available` + `#available`, two lanes at ≥27.1; two printed checks (SDK headers; simulator runtime + Duo device type) — Kimi 4 |
| §4.3 | PROMPT-A's cost facts; still last resort |
| §4.4 | `run_number.run_attempt`, concurrency group, stable workflow name, never re-run past upload (Kimi 3 replacement + Sol 6); `manageAppVersionAndBuildNumber=false` in ExportOptions (the Wilderness 409 root cause); read-back = packaging check only |
| §4.5 | Sol 2's event table is the test list; both-runtimes test when 27.1 lands (Kimi 1); outer preview → CI screenshot artifacts, not an Xcode preview (Sol 3) |
| §5 | Rung 2/3 split (Kimi 4); rung 3 scope (no headless posture); new rung 4b = Perry's iPhone 16 Pro (Sol 3); rung 5 → second-device video + recruitment line (Sol 5, Kimi 5); rung 6 softened (Kimi 2); residual-risk sentence in the claims paragraph; pivot = expected path, 27.0 build runs on Duo |
| §7 | 09-23 online Q&A as an operator option |
| §8 | Sol row 1 marked done with the review file |
| §9 | Week 3 gains rung 4b; week-4 gate: 27.0 build by 10-16; 1.1 when runner + ASC accept 27.1 |
