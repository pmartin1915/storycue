# Gemini Deep Research prompt — shipping an iPhone Duo app from GitHub Actions, solo, no Mac

> **Paste everything between the rules into Gemini Deep Research.** Gemini doesn't have file access; the prompt is fully self-contained. Drop the report back beside this file as `deep-research-iphone-duo-ship-path-REPORT.md`; a Claude session adjudicates it into a synthesis.

---

## Background

I am a solo iOS developer. I already ship two App Store apps from GitHub Actions macOS
runners with no Mac of my own: an XcodeGen `project.yml` Swift app built and tested on a
hosted runner, signed with a distribution certificate + provisioning profile held in
repository secrets, and uploaded with `xcrun altool` on a version tag. I do not own an
iPhone Duo and Apple's Duo ships 2026-10-23.

I am building a small native SwiftUI app for iPhone Duo whose entire point is the
**subject-facing outer display**: while I film someone with the phone open, the person in
front of the lens reads an interview question off the outer display. From Apple's
September 2026 Tech Talks I understand this is done with a scene accessory called
`CameraCaptureAccessory`, which pairs supplementary UI on the outer display while the main
UI is full screen on the inner display with an active camera session, and that the outer
display cannot otherwise host new scenes. I also understand there is a hinge API
(`onHingeChange` in SwiftUI, `UIHingeInteraction` in UIKit) with discrete states and a
continuous angle, and "reserved regions" (division = hinge line, occlusion = under-display
camera) queried from a `GeometryProxy`.

Today is 2026-09-18. Xcode 27.1 beta was released today. GitHub's hosted Xcode 27 runner
image carried only the iOS 27.0 SDK in its 2026-09-12 update.

## What I need you to research

Answer each numbered question separately. For every claim give the date and the primary
source (Apple documentation, Apple developer forums, Apple Tech Talk transcript, GitHub
changelog or `actions/runner-images` release notes, reputable developer blogs). Say
"unknown as of <date>" rather than guessing. Mark each answer High / Medium / Low
confidence.

### 1. The exact `CameraCaptureAccessory` surface
- Declaration, initialiser, and how it is attached in SwiftUI and in UIKit.
- Preconditions and what ends it: does it survive the app going to the background, the
  phone being partially folded, an incoming call, the camera session being interrupted?
- Is the outer-display content **interactive** (can the subject tap it) or display-only?
- Outer display size in points, safe areas, whether Dynamic Type applies.
- Any App Review guideline or HIG rule about what may be shown there (e.g. must relate to
  capture, no unrelated ads, teleprompter is explicitly blessed).
- Whether there are OTHER scene accessory types besides camera capture, and what they are.

### 2. Xcode 27.1 on GitHub-hosted runners
- Current SDK list of the `xcode-27` / macOS 27 runner image and its runner label(s).
- GitHub's historical lag between an Xcode point-release beta/RC and its appearance in
  the hosted image (use Xcode 26.1, 25.1, 16.1 as data points). Estimate when 27.1 lands.
- Workarounds and their real costs: installing Xcode 27.1 on a hosted runner at job time
  (`xcodes`, `xcode-install`, direct download with an Apple ID session; authentication
  requirements, download size, time, whether it fits in a 6-hour job); renting a Mac (list
  current monthly prices for MacStadium, MacinCloud, Scaleway, AWS EC2 Mac, Hetzner,
  Cirrus Runners); a used Mac mini as a self-hosted runner.
- Whether a `#if` compile flag plus `#available(iOS 27.1, *)` gating strategy is what
  Apple recommends for adopting a point-release SDK while CI is on the previous one.

### 3. Submission timing for iOS 27.1-SDK builds
- When Apple historically opened App Store and TestFlight acceptance for point-release
  SDK builds relative to the hardware ship date (use iOS 26.1 / 18.1 / 17.1 as data points).
- Whether TestFlight accepts builds made with a *beta* 27.1 SDK today.
- App Store Connect status for iPhone Duo screenshots and app previews: specs, upload
  availability date if announced, required or optional.
- Anything in the Xcode 27.1 beta release notes that constrains Duo submissions.

### 4. Getting featured at a hardware launch
- How Apple assembles launch collections for a new hardware surface; the App Store
  Connect "Featuring Nominations" mechanism (fields, lead time, what editors say helps).
- Case studies: indie apps featured at the Vision Pro launch (Feb 2024), Dynamic Island
  (Sept 2022), Action button (2023), Apple Watch Ultra, iPad Pro M4. What did they have
  in common (size of team, time to ship, use of the new API, video)?
- Any Apple developer-relations channel specifically for Duo launch apps (workshops,
  labs, "made for Duo" page, developer newsletter calls for submissions).

### 5. Testing without hardware
- Exactly what Xcode 27.1's Device Hub / Duo simulator can and cannot do: posture
  changes, hinge angle, outer display rendering, **camera capture** (I believe no).
- Any Apple loaner, compatibility-lab, or developer-hardware program for Duo.
- Third-party device farms with Duo units announced (AWS Device Farm, BrowserStack,
  Firebase Test Lab, Sauce Labs): dates and prices.
- **Headless simulator control:** can `xcrun simctl`, XCTest or `XCUIDevice` change the
  Duo simulator's posture (closed / partially open / fully open), set a hinge angle, and
  switch between the inner and outer display without a human clicking Device Hub? I need
  this for CI UI tests and for generating App Store screenshots on a hosted runner.
- Does the Duo simulator render `CameraCaptureAccessory` content on the simulated outer
  display at all when there is no real capture session?
- **Recruiting testers who own the hardware:** how indie developers found external
  TestFlight testers on launch day for Vision Pro (Feb 2024) and other new devices —
  communities, wording, what they asked testers to send back — and whether Apple's App
  Review actually exercises new-hardware paths on the device.
- I am NOT buying a Duo. Given that, rank the above by how much confidence each buys.

### 6. What happened at previous foldable launches
- Samsung Galaxy Fold/Flip (Flex mode) and Microsoft Surface Duo: which third-party apps
  gained traction from the new form factor, which "dual-screen" apps failed and why, and
  what the platform holders did that did or did not help developers.
- Specifically: any prior app that showed prompts/teleprompter content to the *subject*
  on a foldable's cover screen, and how it was received.

## Output format

A report with one section per question above, a one-page executive summary at the top
with the five facts that most change a five-week plan, a table of every date you found
(event, date, source), and a final "what I could not find" list. Prefer primary sources;
when you cite a blog, say whether it quotes Apple directly.
