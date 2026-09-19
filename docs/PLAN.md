# iPhone Duo — family story recorder (working name "StoryCue") — plan

_Written 2026-09-18 (Fable session, remote). Perry chose this on 2026-09-18 over two
alternatives, which are deferred in `dev-ops/ai/IDEAS.md` (2026-09-18 entry: fold-to-reveal
flashcards; hinge instrument). This file is the plan and the decision record.

This copy, in `DevProjects/storycue/docs/PLAN.md`, is canonical since 2026-09-19. It was
seeded by hand from the dev-ops branch (`git show` + `cmp`, per `ai/STATE.md`) — the
`bootstrap-storycue.ps1` script was never executed. The dev-ops original,
`dev-ops/IPHONE-DUO-PLAN-2026-09-18.md`, is now the historical record; edit this copy._

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

## 1. What the platform actually allows (measured 2026-09-18 from Apple's Tech Talks + press)

These constraints decide the design. Do not plan against a Duo that does more than this.

| Fact | Consequence for us |
|---|---|
| Inner display 7.6", outer 5.4", same aspect ratio, both up to 3,000 nits | Outer display is a normal phone-sized canvas; large type at arm's length is feasible |
| **The outer display cannot create new scenes.** New windows only on the inner display | A third-party app cannot freely draw on both screens |
| **`CameraCaptureAccessory`** is the sanctioned way to pair UI on the outer display with the main UI on the inner display. Registered with the SwiftUI `sceneAccessory` modifier; it exposes a bindable `isEnabled`, and `onAvailabilityChange` reports when the device state makes it unavailable (e.g. closed). Available only while the app is **full screen on the inner display with an active camera session**. Apple's own example is a teleprompter (Tech Talk 111464, read 2026-09-18) | This is our whole mechanism. The app IS a camera app, by necessity, not by choice. If the camera session stops, the outer display content goes away. **Whether the subject can TOUCH the outer display content is unconfirmed** — Apple's example toggles the accessory from a toolbar on the *inner* UI; prompt A asks. Design the outer view as display-only until proven otherwise |
| SwiftUI `onHingeChange { previous, context in … }` / UIKit `UIHingeInteraction`: `context.hinge?.status` is `.closed`, `.partiallyOpen` or `.fullyOpen`, `hinge.angle` is continuous, and **`context.hinge == nil` means no hinge** (every other iPhone) | Fold → pause recording, preserve state, resume on open. The angle is for effects, not layout. The nil case IS the non-Duo fallback path, so it must be handled, not assumed away |
| Reserved regions via `GeometryProxy.reservedRegion`: *division* regions (the hinge line) and *occlusion* regions (under-display FaceTime camera) | Tabletop posture layout: keep controls out of the hinge line |
| Size classes per display; `NavigationSplitView` collapses when closed | Standard adaptive layout handles closed/open; nothing exotic needed for the library screens |
| iOS 27.1 SDK rebuild enables edge-to-edge content and vertical tab bars | Nice-to-have, not v1 |
| **Xcode 27.1 beta released 2026-09-18** with Device Hub (open/close/rotate/partial fold in the simulator) | We can build and posture-test today. **The simulator has no camera**, so the accessory path cannot be exercised end to end without hardware |
| App Store Connect: Duo screenshot/app-preview specs added; **asset upload "later this year"** | Metadata prep can start; actual Duo screenshots upload when ASC opens it |
| Price $1,999+; ships 2026-10-23 | Tiny install base at launch; the "catch fire" vector is Apple featuring + a shareable clip, not organic installs (§6) |

Sources are listed at the bottom. Where a fact above is second-hand (press summary of a
Tech Talk), the Gemini research prompt in §8 asks for the primary API surface.

## 2. The app

**Loop.** Choose a deck → open the phone → filmer holds the inner display (live preview,
current question, timer, next/skip) → subject sees on the outer display: the question in
very large type, a gentle "recording" indicator, and a 3-2-1 countdown when the filmer
taps record → clip saved → next question. A *session* is the ordered set of clips; it can
be exported to Photos or Files as clips or as one stitched file, and shared.

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
   each week's gate; it is the single fact the timeline hangs on.
2. **Duo SDK gate, so CI is green today and complete later.** A workflow step runs
   `xcodebuild -showsdks` and, if `iphoneos27.1` is present, adds `DUO_SDK` to
   `SWIFT_ACTIVE_COMPILATION_CONDITIONS`. All Duo-specific code sits under `#if DUO_SDK`
   *and* `if #available(iOS 27.1, *)`. On the 27.0 image the app compiles and tests as a
   plain recorder; when GitHub adds 27.1 the same workflow builds the full app with no
   edit. The step prints which path it took so a green run cannot be mistaken for the
   Duo build.
3. **Last resort if 27.1 never lands on hosted runners before ~Oct 16:** install Xcode
   27.1 on the runner with `xcodes` (needs Apple ID credentials in secrets and a ~10 GB
   download per run, uncacheable) or rent a Mac. Both are spend or friction; decide only if
   forced. Prompt A in §8 asks Gemini for current options and prices.
4. **Build number.** Shortless hard-codes `CURRENT_PROJECT_VERSION: "14"`, which is the
   duplicate-build trap Wilderness hit (its 1.7.0 archive shipped the wrong number and
   Apple 409'd). Pass `CURRENT_PROJECT_VERSION=${{ github.run_number }}` to `xcodebuild`
   and keep Wilderness's *verify the exported .ipa* step, which reads the number back from
   the artifact that ships rather than the archive.
5. **Tests in CI.** XCTest on the simulator covers the session state machine (deck index,
   timer, hinge transitions, export manifest) with no camera. The accessory view gets a
   SwiftUI preview so it can be eyeballed in Xcode even where it cannot run.

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
| 1 | XCTest on a **mocked capture service** (protocol over `AVCaptureSession`) | The session state machine: deck × recording × hinge × app lifecycle × export manifest | **Today**, on `macos-27` |
| 2 | Compile with `DUO_SDK` on | The accessory, hinge and reserved-region code type-checks against the real 27.1 SDK | When the runner README lists `iphoneos27.1` — check weekly |
| 3 | XCTest UI tests on the **Duo simulator** in CI, driving posture if `simctl` allows it (prompt A §5 asks) | Layouts on both display sizes; the `hinge == nil` vs non-nil branches; **Duo screenshots for ASC** via `simctl io screenshot` | Same trigger as rung 2 |
| 4 | An **"outer preview" debug mode**: the accessory view rendered in a panel on any device or simulator | The subject-facing layout: type size, contrast, countdown, "Recording" cue — the Kimi review target | Today |
| 5 | **TestFlight external testers who own a Duo**, recruited with a public link on 10-23 | The real pairing: accessory appears, survives fold/unfold, session drop behaviour. Ask each tester for a 10-second clip — that clip is also the marketing asset §6 needs | Launch day |
| 6 | App Review itself runs the build on devices | A crash in the accessory path gets caught before users do | At submission |

**What the listing may claim** is bounded by the highest rung passed at submission:
rungs 1–4 support "designed for iPhone Duo" with simulator-made screenshots; the
outer-display story in words, not a faked photo of a Duo showing it. Nothing in the copy
says "tested on" until rung 5 has happened.

**Pivot condition, decided in advance so it is not decided in a panic:** if on
**2026-10-10** the runner image still has no 27.1 SDK, the Duo path cannot compile before
the 10-16 submission. Default action: ship **1.0 as the single-screen recorder** (fully
tested, useful on every iPhone, no Duo claims) on 10-16, and ship the Duo path as **1.1**
the week 27.1 lands. The alternative — lead with the fold-to-reveal flashcards idea from
`ai/IDEAS.md`, which needs no camera — is a Perry call on that date, not a default.

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
| **Sol** (`pal clink cli_name=codex role=codereviewer`) | Review THIS plan as an architecture decision before code exists | "Review IPHONE-DUO-PLAN-2026-09-18.md §1–§5 as a senior iOS engineer. Is CameraCaptureAccessory the right and only mechanism for a subject-facing prompt on iPhone Duo? What in the SDK gate (§4.2) will bite? What is missing from the hardware-risk section? Be concrete; cite the API by name." |
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
| 3 | 10-06 → 10-12 | Polish, App Store metadata, privacy policy live, first TestFlight build, featuring nomination | TestFlight build installs on Perry's iPhone |
| 4 | 10-13 → 10-19 | Fix from TestFlight; **submit by 10-16** with a 27.1 RC build if Apple has opened 27.1 submissions, else the moment it opens | "Waiting for Review" |
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
