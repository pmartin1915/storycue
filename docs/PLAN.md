# iPhone Duo — family story recorder (working name "StoryCue") — plan

_Written 2026-09-18 (Fable session, remote). Perry chose this on 2026-09-18 over two
alternatives, which are deferred in `dev-ops/ai/IDEAS.md` (2026-09-18 entry: fold-to-reveal
flashcards; hinge instrument). This file is the plan and the decision record.

This copy, in `DevProjects/storycue/docs/PLAN.md`, is canonical since 2026-09-19. It was
seeded by hand from the dev-ops branch (`git show` + `cmp`, per `ai/STATE.md`) — the
`bootstrap-storycue.ps1` script was never executed. The dev-ops original,
`dev-ops/IPHONE-DUO-PLAN-2026-09-18.md`, is now the historical record; edit this copy._

_**Edited 2026-09-21 in one coordinated pass** from `docs/research/SYNTHESIS-2026-09.md`,
which folds the two Gemini reports, the four Tech Talk transcripts, Kimi's review
(`docs/reviews/PLAN-REVIEW-2026-09-18.md`) and Sol's review
(`docs/reviews/SOL-PLAN-REVIEW-2026-09-21.md`). Every dated "(Sol N)" / "(Kimi N)" tag below
points at a verdict in that synthesis; read it before re-litigating one._

## 0. The decision, and the one-line reason

Build a native iOS app for iPhone Duo where **the person being filmed sees the
interview question on the outer display** while the person filming holds the recording
UI on the inner display. Question decks for grandparents, parents, kids, couples.
Launch window is the Duo ship date, **2026-10-23**, five weeks out; the natural first
audience is families at Thanksgiving (2026-11-26).

Why this over the others: it is the only idea of the three where the second screen
creates a *new social interaction* rather than a nicer layout, and it is timed to a
holiday that is exactly when people want to record grandma. It is also the one that
needs hardware to finish (§5), which is the plan's biggest risk and is stated up front.

## 1. What the platform actually allows (measured 2026-09-18 from Apple's Tech Talks + press; re-measured 2026-09-21 from the transcripts and Apple DocC)

These constraints decide the design. Do not plan against a Duo that does more than this.

| Fact | Consequence for us |
|---|---|
| Inner display 7.6", outer 5.4", same aspect ratio, both up to 3,000 nits | Outer display is a normal phone-sized canvas; large type at arm's length is feasible |
| **The outer display cannot create new scenes.** New windows only on the inner display | A third-party app cannot freely draw on both screens |
| **`CameraCaptureAccessory`** is the sanctioned way to pair UI on the outer display with the main UI on the inner display. Registered with the SwiftUI `sceneAccessory` modifier; it exposes a bindable `isEnabled`, and `onAvailabilityChange` reports when the device state makes it unavailable (e.g. closed). Available only while the app is **full screen on the inner display with an active camera session**. Apple's own example is a teleprompter (Tech Talk 111464, read 2026-09-18) | This is our whole mechanism (UIKit spelling: `UISceneAccessory.cameraCapture`; nothing else fits the topology — Sol 4). The app IS a camera app, by necessity, not by choice. If the camera session stops, the outer display content goes away. **Touch: Apple's DocC for `CameraCaptureAccessory` (iOS 27.1 beta, read 2026-09-21) says "unlike `ExternalNonInteractiveAccessory`, the content can be interactive."** The "strictly non-interactive" line in PROMPT-A quoted the external-display article, not this API. **v1 is display-only by decision, not by platform limit:** nothing Perry owns can verify hit-testing on the outer panel before launch. When both displays are live the app owns **two views, one per display, each with its own `AVCaptureDeviceDirectionCoordinator`** (111465 4:49) |
| SwiftUI `onHingeChange { previous, context in … }` / UIKit `UIHingeInteraction`: `context.hinge?.status` is `.closed`, `.partiallyOpen` or `.fullyOpen`, `hinge.angle` is continuous, and **`context.hinge == nil` means no hinge** (every other iPhone) | Fold → **finish the current segment**: stop the file output, wait for `fileOutput(_:didFinishRecordingTo:from:error:)`, keep the file even on error; never pause-and-resume one file, never reconfigure the session before that callback (Sol 2). Reopen → a new segment on the filmer's tap. The angle is for effects, not layout. The nil case IS the non-Duo fallback path, so it must be handled, not assumed away |
| Reserved regions via `GeometryProxy.reservedRegion`: *division* regions (the hinge line) and *occlusion* regions (under-display FaceTime camera) | Tabletop posture layout: keep controls out of the hinge line |
| Size classes per display; `NavigationSplitView` collapses when closed | Standard adaptive layout handles closed/open; nothing exotic needed for the library screens |
| **Cameras (111465):** two square ultrawide front cameras, outer (4K/120) and inner (under-display, 1080p/60). Discovery with `.front` returns a **Virtual Front Camera** that auto-switches on open/close, common capabilities only. Individual inner/outer device types exist on the **27.1 SDK**; an app that uses them must switch on fold via **`AVCaptureDeviceDirectionCoordinator`** (AVKit, main-actor, per `UIView`), whose handler hands an `AVCaptureDeviceDescriptor` to the capture actor. Rear cameras read as "forward-facing" from the outer view when the phone is flipped open. Adopt the rotation coordinator; it updates when the app changes displays | v1 (27.0 SDK) uses the Virtual Front Camera for selfie mode and the rear camera for filmer-holds-inner; the coordinator is Duo-path (week 2) and its handler is one more "camera may reconfigure mid-clip" event the state machine must model. `CaptureService` abstracts *which camera and why*, not just start/stop |
| iOS 27.1 SDK rebuild enables edge-to-edge content and vertical tab bars | Nice-to-have, not v1 |
| **Xcode 27.1 beta released 2026-09-18** with Device Hub (open/close/rotate/partial fold in the simulator). The Duo simulator appears only after the iOS 27.1 beta simulator runtime is (re)downloaded from Settings → Components (Apple forum 847137, accepted answer); PROMPT-A's "Duo support later this month" was quoting the **27.2** beta notes | **Moot for us**: there is no Mac. The only compiler in the plan is the hosted runner (§4.1). **The simulator has no camera** anyway, so the accessory path cannot be exercised end to end without hardware |
| **A 27.0-SDK build runs on iPhone Duo** (111461 0:30): closed, it uses the screen left of the status bar/camera; open, it is "a familiar size and aspect ratio" | The pivot build (§5) installs and works on every Duo sold on 10-23; it just does not use the outer display |
| App Store Connect: Duo screenshot specs published — outer **1398×2034 pt**, inner **2007×2853 pt** — but as of 2026-09-18 the device selector has no Duo entry and the API's `ScreenshotDisplayType` has no Duo case; **asset upload "later this year"** | Metadata prep can start; actual Duo screenshots upload when ASC opens it |
| Price $1,999+; ships 2026-10-23 | Tiny install base at launch; the "catch fire" vector is Apple featuring + a shareable clip, not organic installs (§6) |

Sources are listed at the bottom. Where a fact above is second-hand (press summary of a
Tech Talk), the Gemini research prompt in §8 asks for the primary API surface.

## 2. The app

**Loop.** Choose a deck → open the phone → filmer holds the inner display (live preview,
current question, timer, next/skip) → subject sees on the outer display: the question in
very large type, a gentle "recording" indicator, and a 3-2-1 countdown when the filmer
taps record → clip saved → next question. A *session* is the ordered set of clips; it can
be exported to Photos or Files as clips or as one stitched file, and shared.

**A clip is a sequence of physical segments (Sol 2, 2026-09-21).** Any discontinuity —
fold, accessory withdrawn, incoming call, backgrounding, thermal shutdown, capture
interruption, camera reconfiguration — *finishes* the segment being written and waits for
AVFoundation's finish callback; the file is kept even when the callback reports an error.
The filmer's **Pause** does the same thing on purpose; **Resume** starts a new segment. Nothing
ever resumes writing to a half-finished file, and nothing resumes recording without a tap.
Export stitches segments into the clip. This is what makes "no lost moments" true rather
than hoped.

**Product rules from research** — pause, count-*up* not countdown, 10-minute segment cap,
next-question preview, 48–60 pt outer type at 4–6 words a line, original question copy (VHP
public-domain veterans questions may ship verbatim; StoryCorps's may not), the read-aloud
consent line, general-audience category — are tabulated in `docs/research/SYNTHESIS-2026-09.md`
Q7 and are the week-1 spec's inputs. They are not repeated here.

**Decks (v1).** Grandparents · Parents · Kids ask the grownups · Couples · Holiday table
(round-robin). Copy is the product; it gets a research pass (§8, prompt B) and a Kimi
readability pass, and every question must produce a *story*, not a fact.

**Fallbacks that keep the app honest on every iPhone.** On a non-Duo iPhone the
question shows on the same screen ("pass the phone" or "read it aloud" mode). On a Duo
with the phone closed, the app is a normal single-screen recorder. The Duo path is an
enhancement gated by `#available(iOS 27.1, *)` and a compile flag (§4), never a
requirement.

**Non-goals for v1** (each is a later version, not a maybe): accounts, cloud, sync,
transcription, AI anything, printed books, Android, sharing to social from inside the
app. Nothing leaves the device. This is also what keeps the Money Rule trivially true:
no server, no paid API, no per-user cost.

**Consent is a feature, not a legal footnote.** Session start shows a one-screen "everyone
on camera agrees to be recorded" card; the outer display shows "Recording" whenever the
session is live. Wilderness's rule applies here too: the privacy policy is verified
against the code before every release (Wilderness DECISIONS 2026-08-04), and the policy
is published on martinapps.dev like the others.

## 3. Why native Swift, not the Tauri pattern

Wilderness and Burn Wizard ship as Tauri 2 wrappers around a web app. That pattern
cannot reach `CameraCaptureAccessory`, hinge state or reserved regions from inside a
WKWebView, and a Rust/JS bridge for them would be more work than the app. **Shortless**
is the template instead: pure Swift, `project.yml` (XcodeGen), a `build.yml` that
compiles and runs XCTest on a macOS runner, a `deploy.yml` that signs with a P12 +
provisioning profile from secrets and uploads with `xcrun altool` on a `v*` tag. Perry
already has a distribution certificate and an App Store Connect API key in that
pipeline; the new app needs its own App ID, profile and ASC record (§7), nothing else new.

Identifiers, **confirmed by Perry 2026-09-18** ("same or similar to Shortless's"): bundle id
`dev.pmartin1915.storycue`, repo `pmartin1915/storycue`, Team ID and signing pattern as in
Shortless's `project.yml`. Name "StoryCue" is fine *for now*; prompt B §7 runs the conflict
check and proposes alternatives, and a rename before the ASC record is created is free.

## 4. Build pipeline — what changes from Shortless

1. **Runner: `runs-on: macos-27`.** Shortless pins `macos-14` (Xcode 15-era, will not
   build iOS 27 code). Wilderness moved to `macos-26` (Xcode 26) because App Store Connect
   rejects older SDKs. GitHub's Xcode 27 image is labelled **`macos-27`** (public preview
   2026-07-16; on macOS 27 since 2026-09-10). **Read from its README on 2026-09-18:** one
   Xcode, 27.0 RC (build 27A266a); SDKs `iphoneos27.0` and `iphonesimulator27.0` only; the
   27.0 simulator runtime lists iPhone 17/17e/18 Pro/18 Pro Max/Air and **no Duo**. So as
   of today the hosted runner can neither compile the Duo APIs nor posture-test — Device
   Hub testing is local-Xcode-only until the image adds 27.1. Re-check the README before
   each week's gate; it is the single fact the timeline hangs on. **Re-read 2026-09-21:
   unchanged** (image `20260912.0186.1`, Xcode 27.0 27A266a, `iphoneos27.0` only, simulator
   list iPhone 17 / 17e / 18 Pro / 18 Pro Max / Air, no Duo). Also on the image: `xcbeautify`
   3.2.1 and `xcodes` 2.0.3; **not** on it: `xcodegen`, `xcpretty` (Shortless's `build.yml`
   piped into `xcpretty` — that line would fail here).
2. **Duo SDK gate, so CI is green today and complete later** (rewritten per Sol 1,
   2026-09-21). The trap: `if #available(iOS 27.1, *)` is a *runtime* guard and cannot make
   a 27.0 SDK resolve 27.1 symbols; `#if DUO_SDK` compiles them but protects nothing at
   runtime; and `.sceneAccessory` exists on 27.0 while `CameraCaptureAccessory` is 27.1, so
   the **whole accessory expression** must be compile-gated, not just its body. Rules:
   - One Xcode is selected first and used for **both** the probe (`xcrun --sdk iphoneos
     --show-sdk-version`) and the build — never `-showsdks` on one `DEVELOPER_DIR` and
     `xcodebuild` on another.
   - The workflow never sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS` on the command line (that
     *replaces* the inherited `DEBUG` and hits every target including XCTest). It passes a
     custom setting, `STORYCUE_DUO_CONDITIONS=DUO_SDK`, and `project.yml` expands
     `SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) $(STORYCUE_DUO_CONDITIONS)"` on
     exactly two targets: the app and a dedicated `StoryCueDuoTests` bundle. The baseline
     `StoryCueTests` never sees the flag.
   - Every 27.1 symbol reference is inside `#if DUO_SDK`; every declaration that uses one is
     `@available(iOS 27.1, *)`; every call site is `if #available(iOS 27.1, *)`. Below 27.1 the
     app compiles against a no-op Duo adapter (the `hinge == nil` path).
   - The step prints the SDK version it found, whether the flag was set, and
     `xcodebuild -showBuildSettings` for each target's compilation conditions, so a green run
     cannot be mistaken for the Duo build. It prints **two separate facts** (Kimi 4): SDK
     headers present (`--show-sdk-version` ≥ 27.1) and Duo simulator present (`xcrun simctl
     list devicetypes` contains "Duo"), because they land on the image independently.
   - When the SDK is ≥ 27.1 the workflow runs **two lanes**: baseline (flag off, 27.0
     runtime if still installed) and Duo (flag on). That is also how Kimi 1's
     both-runtimes test is delivered.
3. **Last resort if 27.1 never lands on hosted runners before ~Oct 16:** install Xcode
   27.1 on the runner with `xcodes` (Apple ID credentials in secrets; PROMPT-A measures it at
   ~35 GB uncompressed per job, un-cacheable, "operationally prohibitive") or rent a Mac (EC2
   Mac has a 24-hour minimum; MacStadium/Scaleway/Hetzner/Cirrus exist; prices unmeasured).
   Both are spend or friction; decide only if forced. **The pivot in §5 is the expected
   path, not the exception.**
4. **Build number** (Kimi 3 replacement + Sol 6). Shortless hard-codes
   `CURRENT_PROJECT_VERSION: "14"`, which is the duplicate-build trap Wilderness hit (its
   1.7.0 archive shipped the wrong number and Apple 409'd). GitHub's `run_number` is unique
   *per workflow* and monotone, but unchanged on a re-run and reset if the workflow file is
   renamed. So: `CURRENT_PROJECT_VERSION=${{ github.run_number }}.${{ github.run_attempt }}`
   passed to `xcodebuild`; a `concurrency` group so deploys serialize; the workflow file
   name never changes; and a deploy is **never re-run** past the upload step. ExportOptions
   carries `manageAppVersionAndBuildNumber=false`, without which export re-derives the
   number from the project and discards the override — that was Wilderness's actual root
   cause. Keep Wilderness's *verify the exported .ipa* step — it proves the number that
   **shipped**, which is a packaging check, **not** proof that ASC lacks it (Sol 6 corrects
   the Kimi adjudication's "catches both"). An ASC pre-query is deferred to `ai/IDEAS.md`.
5. **Tests in CI.** XCTest on the simulator covers the session state machine with no
   camera: deck index, timer, export manifest, and **every row of Sol 2's event table**
   (fold/accessory-withdrawn, audio/capture interruption, resign-active/background, thermal
   shutdown, runtime error / media-services reset, direction-coordinator change) as a
   transition that ends in `finishing` and then either `segmentSaved` or `segmentFailed(kept)`,
   never in a resumed write. The "outer preview" debug mode (§5 rung 4) is exercised by a UI
   test that writes `simctl` screenshots as CI artifacts with snapshot assertions — there is no
   Mac to eyeball an Xcode preview on (Sol 3).

## 5. No hardware — how the Duo path still ships (decided 2026-09-18: no Duo will be bought)

The constraint stack, in full: **no Duo, no Mac** (both of Perry's machines are Windows),
and the hosted `macos-27` runner has **no 27.1 SDK and no Duo simulator** as of today. So
right now nothing Duo-specific can compile anywhere Perry controls. When GitHub adds 27.1
to the image, Duo code compiles and the Duo simulator can run headless in CI — but a
simulator never has a camera, so `CameraCaptureAccessory` cannot be exercised end to end
by anything we own. The plan does not pretend otherwise; it climbs a ladder where each
rung states what it proves.

| Rung | What runs | What it proves | Available |
|---|---|---|---|
| 1 | XCTest on a **mocked capture service** (protocol over `AVCaptureSession`) | The session state machine: deck × recording × segment finalization × hinge × app lifecycle × export manifest (§4.5). **Reducer logic only** — not permissions, A/V sync, codecs, file finalization or export (Sol 3) | **Today**, on `macos-27` |
| 2 | Compile with `DUO_SDK` on, **both lanes** (flag off on the 27.0 runtime if still present, flag on) | The accessory, hinge and reserved-region code type-checks against the real 27.1 SDK, and the `#available` fallback branch is *executed*, not assumed (Kimi 1) | When `xcrun --sdk iphoneos --show-sdk-version` on the runner ≥ 27.1 — its own printed check (Kimi 4) |
| 3 | XCTest UI tests on the **Duo simulator** in CI | Layouts on both display sizes; the `hinge == nil` vs non-nil branches; **Duo screenshots for ASC** via `simctl io screenshot`. **Not posture:** `simctl` has no documented posture/hinge command (PROMPT-A §5); a debug angle injection tests the app's branch, not `onHingeChange` delivery. Whether the simulator renders accessory content without a capture session is UNVERIFIED | When `simctl list devicetypes` on the runner names a Duo — a *separate* printed check from rung 2 (Kimi 4) |
| 4 | An **"outer preview" debug mode**: the accessory view rendered in a panel on any device or simulator, captured as CI screenshot artifacts | The subject-facing layout: type size, contrast, countdown, "Recording" cue — the Kimi review target | Today |
| **4b** | **Internal TestFlight on Perry's iPhone 16 Pro** before submission (Sol 3) | The real recorder: camera/mic permission grant, deny and revoke; repeated clips; backgrounding, an incoming call, rotation and termination mid-clip; low-storage / file-output failure and orphan-segment recovery on relaunch; Photos and Files export followed by playback of the exported file | Week 3, once the ASC record and profile exist (§7) |
| 5 | **TestFlight external testers who own a Duo**, recruited with a public link on 10-23 (developer Discords, X, Reddit — PROMPT-A §5; Kimi 5) | The real pairing: accessory appears, survives fold/unfold, session drop behaviour. Ask each tester for (a) a 10-second clip — also the marketing asset §6 needs — and (b) a **second-device video showing both displays**, because the clip alone does not prove the outer display showed anything (Sol 5). Ship a **privacy-safe diagnostic export** (local text file, shared only by the user: timestamps for scene phase, hinge state, accessory availability, interruptions, device descriptor, file-output completion) so a tester's report carries data | Launch day — TestFlight *external* builds need the 27.1 RC, which Apple has historically tied to hardware availability |
| 6 | App Review runs the build | A crash on launch or in the reviewer's happy path gets caught before users do — **and no more than that**: nothing says a reviewer folds, unfolds or drops a session, and with nothing leaving the device there is no crash telemetry either (Kimi 2) | At submission |

**What the listing may claim** is bounded by the highest rung passed at submission:
rungs 1–4b support "designed for iPhone Duo" with simulator-made screenshots; the
outer-display story in words, not a faked photo of a Duo showing it. Nothing in the copy
says "tested on" until rung 5 has happened. **State the residual risk plainly in the
handoff at submission:** if no rung-5 evidence exists, outer-display presentation on real
hardware is an unverified launch risk, and the 1.1 release notes are where it gets closed.

**Pivot condition, decided in advance so it is not decided in a panic:** if on
**2026-10-10** the runner image still has no 27.1 SDK, the Duo path cannot compile before
the 10-16 submission. Default action: ship **1.0 as the single-screen recorder** (tested at
rungs 1 and 4b, useful on every iPhone, **installs and works on a Duo** per 111461 — just
without the outer display, no Duo claims) on 10-16, and ship the Duo path as **1.1** the
week 27.1 lands on the runner *and* ASC accepts 27.1 builds. **As of 2026-09-21 this is the
expected path** (PROMPT-A puts 27.1 on hosted runners in late Oct / early Nov, and 27.1-SDK
submissions opening ~10-23). The alternative — lead with the fold-to-reveal flashcards idea
from `ai/IDEAS.md`, which needs no camera — is a Perry call on that date, not a default.

The old option of buying a Duo is closed (Perry, 2026-09-18). Renting one or a device farm
slot is still worth one look (prompt A §5) but nothing here depends on it.

## 6. How it "catches fire", and what that costs

Not installs. Apple curates a launch collection for every new hardware surface and has a
long habit of featuring small indie apps that use a new API cleanly (Dynamic Island,
Action button, Vision Pro all had this). Two levers a solo dev can pull:

1. **Featuring nomination in App Store Connect**, filed ~2 weeks before launch with the
   Duo angle stated in one sentence and a 15-second clip. Prompt A asks what got indie
   apps featured at prior hardware launches.
2. **One 10-second video** that only makes sense on this hardware: grandmother reading a
   question off the back of the phone, laughing, answering. That clip is the marketing
   plan. It needs a Duo to shoot, which is another reason §5 matters.

Timing lever: Thanksgiving is 34 days after launch. "Record your family this Thanksgiving"
is the whole pitch and StoryCorps already runs a Thanksgiving campaign every year, which
means the audience is primed and the phrase is searchable.

## 7. Operator acts — only Perry can do these

In the order they block things:

1. **Repo.** Name confirmed as "StoryCue" for now (Perry, 2026-09-18). Create
   `pmartin1915/storycue` (private, like the others) — a thirty-second click, or tell a
   session to attempt it through the GitHub connector. Everything in week 1 waits on this.
2. **Hardware decision: DECIDED, no Duo** (Perry, 2026-09-18). §5 is the consequence. The
   remaining dated decision is the 10-10 pivot check in §5.
3. **Apple Developer Portal:** register the App ID; create an App Store provisioning
   profile for it (the existing distribution certificate should still be valid — check
   its expiry); create the ASC app record. Same steps as `shortless-ios/CI_SETUP.md`
   §1, §5, minus the app groups and extensions.
4. **GitHub secrets** on the new repo: the same six as Shortless plus one profile. The
   certificate and API-key secrets can be copied from Shortless's repo settings.
5. **Gemini Deep Research:** run the two prompts in `docs/research/` (§8) and drop the
   reports beside them; this session or the next adjudicates into a synthesis file, the
   way `LEGIBILITY-SYNTHESIS-2026-08.md` did.
6. Later: privacy policy page on martinapps.dev; featuring nomination; Duo screenshots
   when ASC opens the slot.
7. **Optional, 2026-09-23:** Apple's online "iPhone Duo Photos & Camera" / SwiftUI Q&A
   sessions (PROMPT-A §4; App Review appointments run 09-22 → 09-25). The one place to put
   §1's open questions (accessory behaviour at `.partiallyOpen`, on an incoming call, on
   thermal shutdown) to an Apple engineer before code exists. It is the day before the
   slides deadline; a choice, not a task.

Nothing in the registry or `config/deadlines.json` is edited by this plan. The registry
must not name a path that does not exist (PORTFOLIO.md, 2026-08-26), so the row is added
when the repo is cloned onto a machine. Two deadline rows are proposed for Perry to
promote by hand, per that file's contract: `duo-submit` 2026-10-16 and `duo-launch`
2026-10-23. Note the collisions already in that file: slides 09-28, talk 10-01, CCTS
pre-app 10-19. Weeks 1 and 4 below assume Perry does operator acts only.

## 8. Research and review lanes

**Gemini Deep Research** (Perry runs; prompts are self-contained, no repo content):

- `docs/research/PROMPT-A-ship-path.md` — the platform and the ship
  path: exact accessory API surface, Xcode 27.1 on hosted runners, submission timing for
  27.1-SDK builds, featuring mechanics, testing without hardware, what happened at prior
  foldable launches.
- `docs/research/PROMPT-B-product.md` — the product: competitor
  landscape and pricing, what makes an interview question produce a story, question-set
  licensing, recording-consent law, kids-in-frame rules, holiday campaign patterns,
  readability for elderly subjects.

**PAL lanes when the laptop is back** (route by stakes per `~/.claude/WORKFLOW.md`):

| Lane | Task | Prompt to paste |
|---|---|---|
| **Sol** (`pal clink cli_name=codex role=codereviewer`) | Review THIS plan as an architecture decision before code exists — **DONE 2026-09-21**, `docs/reviews/SOL-PLAN-REVIEW-2026-09-21.md`, adjudicated in `docs/research/SYNTHESIS-2026-09.md` §S | (historical) "Review IPHONE-DUO-PLAN-2026-09-18.md §1–§5 as a senior iOS engineer. Is CameraCaptureAccessory the right and only mechanism for a subject-facing prompt on iPhone Duo? What in the SDK gate (§4.2) will bite? What is missing from the hardware-risk section? Be concrete; cite the API by name." |
| **Sol** | Every diff touching the Duo path (accessory, hinge, export) — Substantive tier, Sol required | "Code review, iOS 27.1 SDK, SwiftUI. Focus: camera session lifecycle across fold/unfold, accessory presentation when the session drops, data loss on backgrounding mid-clip." |
| **Kimi** (`pal clink cli_name=kimi`) | Outer-display layout review: 5.4" at arm's length, elderly readers | "You are reviewing a SwiftUI view shown to a person 1–2 m away on a 5.4-inch phone display. Judge type size, contrast, line length, and whether a 75-year-old can read it without glasses. Propose exact Dynamic Type sizes." |
| **Kimi** | Edge cases of the session state machine | "Enumerate every transition in this state machine (deck × recording × hinge × app lifecycle) and name the ones the tests do not cover." |
| `glm-4-flash` / `gemini-2.5-flash` | Routine: deck copy tone, unit-test scaffolds | — |

## 9. Timeline (five weeks; Claude sessions do the code, Perry does §7)

| Week | Dates | Deliverable | Gate |
|---|---|---|---|
| 0 | 09-18 → 09-21 | Name, repo, research prompts out, App ID + profile + secrets | Repo exists with CI green on an empty XcodeGen app |
| 1 | 09-22 → 09-28 | Single-screen recorder: decks, AVFoundation capture, session library, export. XCTest on the state machine | `build.yml` green on the 27.0 image; Sol review of the recorder |
| 2 | 09-29 → 10-05 | Duo path under the gate: accessory view, hinge handling, tabletop layout with reserved regions; Device Hub posture testing | Sol review of the Duo diff; Kimi layout pass |
| 3 | 10-06 → 10-12 | Polish, App Store metadata, privacy policy live, first TestFlight build, featuring nomination, **rung 4b checklist on Perry's iPhone 16 Pro** (§5) | TestFlight build installs on Perry's iPhone **and the rung-4b checklist passes** |
| 4 | 10-13 → 10-19 | Fix from TestFlight; **submit the 27.0-SDK build by 10-16** (the expected path, §5). A 27.1 build ships as 1.1 when the runner has the SDK *and* ASC accepts 27.1 builds (historically ~hardware day) | "Waiting for Review" |
| 5 | 10-20 → 10-26 | Launch 10-23; hardware test same day if a Duo exists; 1.0.1 | — |

The week-4 gate depends on Apple: submissions for iOS 27.0-SDK builds are open now, and
27.1-SDK acceptance is presumably tied to the 27.1 RC near ship date. That date is
unknown as of this writing and is the first thing prompt A should pin down.

## Sources (read 2026-09-18)

- Apple Developer Tech Talks: *Prepare your app for iPhone Duo* (111461), *Strike a pose
  with adaptive layouts on iPhone Duo* (111463), *Leverage multiple displays and scenes on
  iPhone Duo* (111464), *Build a great camera experience for iPhone Duo* (111465)
- Apple Newsroom, 2026-09-09: *Apple unveils iPhone Duo*
- 9to5Mac, 2026-09-18: *Apple releases Xcode 27.1 beta, enabling iPhone Duo app development*
- Apple Developer News: *App Store submissions now open for the latest OS releases*;
  App Store Connect release notes (Duo screenshot specs; asset upload later this year)
- The Register, 2026-09-15: *Apple iPhone Duo makes developers think in folds*
- Swiftjective-C: *iPhone Duo: First Developer Good-to-Knows*
- Mac Observer: *iPhone Duo's Outer Display: What Third-Party Apps Can Do There*
- GitHub Changelog: *Xcode 27 runner image now in public preview* (2026-07-16); *Xcode 27
  runner image now runs on macOS 27* (2026-09-10); `actions/runner-images`
  `images/macos/xcode-27-arm64-Readme.md` on `main`, fetched 2026-09-18 (label `macos-27`,
  Xcode 27.0 RC, iOS 27.0 SDK only)
- Engadget / Variety, 2026-09-09: price and availability
- Apple's developer newsletter to Perry, 2026-09-09 and 2026-09-18 (`developer@insideapple.apple.com`)
