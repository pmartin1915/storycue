# Reviewer prompt (identical for Sonnet, Kimi, Sol; ASCII only)

You are doing QA on a newer iPhone app so it can match the polish of the same author's older apps.
You are one of three independent reviewers. You will not see the others' work.

Below are: the rubric, the target app's source excerpts, and the veteran apps' counterparts.
Use ONLY what is in this packet. Do not invent files, lines or quotes. If a screen is not in the packet, say "not in packet".

Task: score each rubric dimension 0-4, then list findings in this exact shape:

FINDING <n>
- dimension: <1-8>
- severity: blocker | should | polish
- target: <path>:<line>  quote: "<exact text from the packet>"
- veteran counterpart: <path>:<line>  quote: "<exact text>"
- evidence: <quote from a fetched Apple doc with URL, or the failure you can show from the code>
- fix: <concrete change, 1-4 sentences>

Rules: prefer 8-15 strong findings over 40 weak ones. Say what the target already does well in two lines at the end.
Do not propose new features. Do not touch store listings, billing or clinical content.

ADDITIONAL TASK (Perry, 2026-11-09): after the findings, list up to 5 VETERAN FEATURES WORTH BORROWING into this app, in this shape:
VETERAN FEATURE <n>
- what: <one line, in plain words>
- veteran: <path>:<line>  quote: "<exact text from the veteran excerpts below>"
- where it would go in the target: <screen/file>
- why it fits this app: <one line>
These are the only place new behaviour may be proposed; Perry picks which to build.

Dimension 9 (Android parity) is N/A: this app is iOS-only. Score dimensions 1-8.

=== RUBRIC ===
# comeup rubric (score each dimension 0-4: 0 broken, 2 acceptable, 4 matches the veteran bar)

Every finding must carry: file:line in the TARGET, the veteran file:line that does it right, evidence
(quoted code, or a fetched Apple doc URL), severity (blocker / should / polish), and a concrete fix.
No finding without a quote that exists in the packet. If you cannot cite it, do not report it.

1. **Motion and fluidity.** Transitions, spring animations, matched geometry, haptics on meaningful actions, no dead taps, no layout jumps, Reduce Motion respected.
2. **State clarity.** Every screen shows loading, saving, empty, success and error. Buttons disable while work is in flight. No silent failure. Single-flight on taps that start work.
3. **Input and recording robustness.** Interruptions (call, route change, backgrounding), permissions denied or revoked, low storage, rapid repeated taps, resume after kill.
4. **Accessibility.** Dynamic Type through the largest sizes, VoiceOver labels/hints/order, contrast (HOUSE-STYLE numbers), hit targets >= 44 pt, Reduce Motion and Bold Text.
5. **Visual system.** HOUSE-STYLE rules 1-26: palette tokens, mark use, spacing, type scale, no off-brand one-offs.
6. **Performance.** Cold launch, first-frame work on the main thread, scroll cost of long lists, image and audio memory.
7. **Copy.** Plain, specific, consistent voice; error text says what happened and what to do; no jargon.
8. **Layout resilience.** iPhone sizes and the foldable-hazard list in APPLE-IPHONE-DUO-PREP (UIScreen.main, portrait lock, full-screen flags).
9. **Android parity (Play apps only).** Same flows on the Android build: back gesture/button behaviour, system bars and edge-to-edge insets, Material touch targets (48 dp), font scale to 200%, TalkBack labels, no iOS-only affordance left dead (swipe-back, haptics silently missing), and the Android screenshot matches the iOS one in state and copy. Score N/A for iOS-only apps.

Output a score table first, then findings ordered blocker -> polish.

=== BAR ===
Perry 2026-11-04: bar is BoardBound and burn-wizard; from Wilderness Survival he likes motion and transitions, haptics, state clarity, visual polish.
NOTE: veterans are web/React Native (Tauri/Expo); the target is SwiftUI. Cite the veteran BEHAVIOR and file:line; express fixes in SwiftUI/UIKit.
NOTE: this app (store name Tellfolk, repo storycue) is the reference implementation of the house style (HOUSE-STYLE "Rollout order" item 1). It is a video-interview recorder: pick a question deck, read a consent line, record answers question by question over the camera, then play back, export, delete.

=== MEASURED PROBES (counted by Opus 2026-11-09; not opinion) ===
| # | Probe | Result | Score 0-3 |
|---|---|---|---|
| M1 CI | gh run list, last 20 | 19 success/cancelled, 1 failure (screenshots on a since-merged PR); build.yml runs on PRs; main is NOT branch-protected | 2 |
| M2 Test floor | 25 unit test files + 1 UI test file, 272 test functions | no coverage threshold in CI | 2 |
| M3 Release gate | deploy.yml + .github/scripts/select-xcode.sh allowlist gate (fails closed on unapproved Xcode) | no written release runbook/preflight script | 2 |
| M4 Crash reporting | grep Sentry/Crashlytics/MetricKit/MXMetricManager | none (Apple Organizer only) | 0 |
| M5 Failure UX | notAuthorized/unavailable overlays, playbackUnavailable, export failed message, sessionGone | each failure path has text | 3 |
| M6 Accessibility | StyleLintTests (no fixed font sizes, no literal radii/colors/animations, accent contrast), AX5 + dark screenshot runs | contrast test in CI; no automated VoiceOver audit (performAccessibilityAudit) | 2 |
| M7 Fluidity | grep XCTApplicationLaunchMetric/XCTHitchMetric/measure( | none; no baseline | 0 |
| M8 Harness | StoryCueUITests/ScreenshotTests: AppStore, dark, AX5 runs on a seeded demo | drives screens; review steps are continue-on-error so a failing review test shows green | 1 |
| M9 Docs spine | ai/STATE.md yes; DECISIONS.md no; CLAUDE.md/AGENTS.md no | | 1 |
| M10 Money | no payments in 1.0 | N/A | - |
| M11 Review readiness | PrivacyInfo.xcprivacy present; no accounts; no IAP; portrait-locked (project.yml UISupportedInterfaceOrientations: Portrait only) | clean | 3 |

=== HOUSE-STYLE (brand/HOUSE-STYLE.md, rules section) ===
## The rules

Each rule has one check that someone can actually run. "Native" is the SwiftUI way. The other
columns get filled in after the Gemini adjudication.

| # | Rule | Check | SwiftUI | Expo | Tauri |
|---|---|---|---|---|---|
| 1 | **System text styles. Weight, not size, makes the hierarchy.** About 4 styles a screen *(soft count)*. | No fixed font sizes outside the tokens file. | `.font(.body)`, `.headline`; never `.system(size:)` | Own `Text` wrapper; `allowFontScaling` (default true); size from tokens, not literals | CSS `font: -apple-system-body` and sibling keywords (headline, subheadline, caption1); no web fonts; needs reload on text-size change (unverified inside Tauri) |
| 2 | **One accent: the product line's** (`BRAND.md` table). Everything else is neutral. Use it only on tappable or wayfinding items *(soft)*. | Count accent uses per screen; none on decoration. | `AccentColor` asset, `.tint` | Theme module, accent only on pressables | Tailwind preset with CSS variables |
| 3 | **Contrast 4.5:1 for text, 3:1 for large text and controls. Never color alone.** | Contrast tool, plus a grayscale screenshot in light and dark. | Accessibility Inspector | Theme tokens plus contrast tool; Increase Contrast hook for iOS: unverified | Tokens plus tool; `@media (prefers-contrast: more)` works (Safari 14.1+) |
| 4 | **Tap targets at least 44 pt; 48 pt or more on time-pressured screens.** | Every control passes a hit test. | `.frame(minWidth:44,minHeight:44).contentShape(Rectangle())` | `minHeight/minWidth: 44` plus `hitSlop` | `min-h-[44px] min-w-[44px]` (equivalence not fetched, test on device) |
| 5 | **Shared spacing and radius tokens:** multiples of 4/8, a few radii *(soft)*. | Grep for padding and radius literals outside the tokens file. | `Tokens.swift` | Style Dictionary v4 to a JS theme object | Style Dictionary v4 to CSS variables for Tailwind |
| 6 | **System chrome: stock bars, tabs and sheets. No opaque fake bars.** Content over a camera feed may use a deliberate dark card. | Look with Reduce Transparency and Increase Contrast on. | `NavigationStack`, `TabView` | Real: react-native-screens native stack (Expo Router) and `expo-router/unstable-native-tabs` (SDK 54 to 57, unstable) give iOS 26 Liquid Glass | Imitation only (`backdrop-filter`, static); no scroll-edge effect; native chrome around the WebView needs custom Swift (unverified) |
| 7 | **SF Symbols, weight-matched, monochrome by default** *(soft)*. Brand marks are the exception. | No mismatched icon weights. | `Label` | `expo-symbols` (unverified here) | Not possible in a WebView; imitation only with a weight-matched SVG set |
| 8 | **Short springs; nothing slow** (about 0.35 s, none over 0.5 s) *(soft)*. | Motion values come only from the tokens file. | `.spring(duration: 0.35)` | Reanimated `withSpring` with ~0.35 s config | Imitation: CSS `linear()` (Safari 17.2+) or a short ease; avoid JS animation libs |
| 9 | **Reduce Motion honored:** slides become fades. | Toggle it; nothing travels. | `accessibilityReduceMotion` | `ReducedMotionConfig` (System mode disables animations) plus `useReducedMotion` for explicit fades; the hook is not reactive | `@media (prefers-reduced-motion: reduce)` swaps slides for fades |
| 10 | **Haptics only for discrete, visible outcomes. Every haptic has a visible twin** *(soft)*. | List each haptic and its twin. | `.sensoryFeedback` | `expo-haptics` `impactAsync`, `notificationAsync`, `selectionAsync`; silent in Low Power Mode and while Camera is active | `@tauri-apps/plugin-haptics` `impactFeedback`, `notificationFeedback`, `selectionFeedback`; on-device test (latency unverified) |
| 11 | **One clear primary action per screen, in thumb reach** *(soft)*. A custom control such as a record ring can be that action. | A stranger names the action in one second. | `borderedProminent` in `.safeAreaInset(edge: .bottom)` | Bottom-anchored `Pressable` in the safe area (`react-native-safe-area-context`, unverified here) | Bottom bar with `env(safe-area-inset-bottom)`; set `viewport-fit=cover` |
| 12 | **Designed empty, error and missing-data states, each with one action.** | Every state previewed. | `ContentUnavailableView` | Imitation: own component per state (no stock equivalent) | Imitation: own component per state |
| 13 | **Undo where reversible. Where not, a confirm with a verb label** ("Delete Recording") *(soft)*. | No "Are you sure?" on recoverable actions. | `.confirmationDialog` | `Alert.alert` with a destructive button (unverified here) | `@tauri-apps/plugin-dialog` confirm on iOS: unverified; else an HTML dialog (imitation) |
| 14 | **Fast path to first value: no account wall before the core task** *(soft)*. | Time a cold launch to the first win. | -- | -- | -- |
| 15 | **Permissions primed in context:** one sentence and a "Not now" before the system dialog. | No system prompt before the user's own tap. | sheet, then request | In-app sheet, then the module's request call | In-app sheet, then the plugin's request call (per-plugin support unverified) |
| 16 | **One proportionate completion moment per flow.** No confetti near serious content *(soft)*. | Each flow ends exactly once. | success haptic + fade | `notificationAsync(Success)` plus a short fade | `notificationFeedback("success")` plus a short fade |
| 17 | **VoiceOver complete.** | Do the core task with your eyes closed. | `.accessibilityLabel`, `.combine` | `accessible`, `accessibilityLabel`/`Role`, group value plus unit in one element, JSX order matches reading order | Semantic HTML, labels, `aria-live` container rendered at load with only its text changed |
| 18 | **Text scales to the largest accessibility size without clipping.** | Check at AX5. | `@ScaledMetric`, scrolling containers | `allowFontScaling` on; do not cap with `maxFontSizeMultiplier` (see below); scroll or wrap instead | Font keywords plus wrapping or scrolling containers; check at AX5 on device |
| 19 | **No dark patterns.** The system rating API only, after a win; honest notifications; no fake urgency. | Grep for custom review prompts; read all decline copy. | `requestReview()` | `expo-store-review` for the system prompt (unverified here) | System rating prompt: no verified plugin; likely needs a custom Swift plugin (unverified) |

**Clinical apps** (the clinical line) add: calm, exact copy with no exclamation marks; units always
visible next to computed values; results set in a larger style with monospaced digits; and 48 pt
targets as the floor, not the stretch. From the Gemini check: a home screen of Favorites, Recent, then all tools, plus
search (MDCalc pattern; no keyboard auto-open); one US/SI unit toggle that changes everything; offline
by default; never cap text size to protect a layout (wrap or scroll so the unit stays visible at AX5);
value and unit as ONE VoiceOver element; never rely on haptics for a safety alert (iOS mutes them in Low
Power Mode and while the camera runs); on Tauri, re-invert clinical images only under
`@media (inverted-colors: inverted)`.

## Engagement rules 20-26 (adopted by Perry 2026-10-05)

From the engagement-mechanics Deep Research (`dev-ops/research/gemini-dr-engagement-mechanics-2026-10-REPORT.md`),
source-checked by Sonnet (52 claims: 30 verified, 10 overreach) and by Sol on the regulatory claims
(`...-ADJUDICATION.md`). Only claims both passes support were proposed; Perry adopted all seven on 2026-10-05. The aim is **habit-forming, not
addictive**: every mechanic below survives rule 19.

| # | Rule | Check | Applies to | Source |
|---|---|---|---|---|
| 20 | **Notifications: default interruption level only.** Time Sensitive only for something happening within the hour, never reminders or marketing. Critical never (needs Apple's entitlement). One notification per event, and none for an update a Live Activity is already showing. | List each notification and its level. | All | Apple HIG, Managing notifications |
| 21 | **Progress forgives.** A missed day never resets a count to zero and no copy frames a lapse as loss. Prefer "days studied" or progress toward a goal the user set. Family apps carry no streaks at all. | Miss a day on a test build; read every lapse string. | Clinical (exam prep), outdoor/life | Gentler Streak (Apple Watch App of the Year 2022) |
| 22 | **Cancel as easily as you subscribed.** No guilt copy, no extra confirmation screens, no fake-urgency or "most picked" badges. Price, period and renewal shown before the purchase tap. | Count taps from paywall to subscribed vs to cancel instructions; read decline copy. | Any app with a subscription | FTC v. ABCmouse (complaint allegation, settled); App Review 3.1.2 *(not yet source-checked)* |
| 23 | **Login only where accounts earn it** (extends rule 14). If an app creates accounts, it deletes them in-app. | Fresh install reaches the core task with no account; find the delete-account path. | All | App Review 5.1.1(v) |
| 24 | **Widgets show changing information or do not ship.** | Widget content differs across a day. | Outdoor/life, clinical *(soft)* | Apple HIG, Widgets |
| 25 | **Android builds: no docked bottom toolbar together with the bottom navigation bar.** | Screen review of each Android screen. | All (Android) | Material 3 toolbars *(page only partly readable)* |
| 26 | **Clinical results show their basis:** the inputs used, the formula or source with its date or version, next to the result. This is good practice and helps clinicians check the output. **It is not, by itself, an FDA determination**: whether a given calculator is non-device clinical decision support is a separate per-function question for Perry (and counsel). The FDA guidance was reissued in January 2026. | Every computed value shows inputs plus a source line. | Clinical | FDA CDS guidance (2026), criterion 4 |

**Not adopted, with reasons.** A parental gate for StoryCue or Retold: Apple requires gates only inside the Kids
Category, and neither app is in it (opting in later would bring them in). Variable rewards and coin mechanics:
they conflict with rule 19. Specific paywall layouts ("trial date without scrolling", "two-tap cancel"): the report
gave no source. Material 3 conventions applied on iOS: that was the report's own extrapolation.

**Known conflicts with 21 and 22, being fixed:** BoardBound's streak chip and "Start your streak today!", its 7-day
coin rewards, and the pulsing "Most picked" paywall tag (`dev-ops/audits/boardbound-house-style-2026-10-04.md`).


=== APPLE EVIDENCE (fetched 2026-11-09 from developer.apple.com DocC JSON; quote these, never recall) ===

SOURCE: https://developer.apple.com/design/human-interface-guidelines/playing-haptics

Depending on the platform and the device people are using, the system can play haptics in addition to visual and auditory feedback. For example, components like switches, sliders, and pickers automatically play haptic feedback on supported iPhone models; on Apple Watch, the Taptic Engine generates haptics for a number of built-in feedback patterns, which watchOS combines with an audible tone. On a Mac that's equipped with a Force Touch trackpad, an app can play haptics while people drag content or when they force click to change the speed of media controls.
In addition to built-in haptic capabilities, some external input devices can also play haptics. For example:
- In an iPadOS, macOS, tvOS, or visionOS app or game, game controllers can provide haptic feedback (for developer guidance, see playing-haptics-on-game-controllers).
- Apple Pencil Pro and some trackpads can provide haptic feedback when connected to certain iPad models. (For details on Apple Pencil features and compatibility, see .)
## Best practices
Use system-provided haptic patterns according to their documented meanings. People recognize standard haptics because the system plays them consistently on interactions with standard controls. If the documented use case for a pattern doesn't make sense in your app or game, avoid using the pattern to mean something else. Instead, use a generic pattern or create your own, where supported. For guidance, see playing-haptics#Custom-haptics.
Use haptics consistently throughout your app or game. It's important to build a clear, causal relationship between each haptic and the action that causes it so people learn to associate certain haptic patterns with certain experiences. If a haptic doesn't reinforce a cause-and-effect relationship, it can be confusing and seem gratuitous. For example, if your game plays a specific haptic pattern when a character fails to finish a mission, people associate that pattern with a negative outcome. If you use the same haptic pattern for a positive outcome like a level completion, people will be confused.
Prefer using haptics to complement other feedback in your app or game. When visual, auditory, and tactile feedback are in harmony -- as they generally are in the physical world -- the user experience is more coherent and can seem more natural. For example, you generally want to match the intensity and sharpness of a haptic with the intensity and sharpness of the animation it accompanies. You can also synchronize sound with haptics; for developer guidance, see delivering-rich-app-experiences-with-haptics.
Avoid overusing haptics. Sometimes a haptic can feel just right when it happens occasionally, but become tiresome when it plays frequently. Doing user testing can help you discover a balance that most people appreciate. Often, the best haptic experience is one that people may not be conscious of, but miss when it's turned off.
In most apps, prefer playing short haptics that complement discrete events. Although long-running haptics that accompany a gameplay flow can enhance the experience, long-running haptics in an app can dilute the meaning of the feedback and distract people from their task. On Apple Pencil Pro, for example, continuous or long-lasting haptics don't tend to clarify the writing or drawing experience and can even make holding the pencil less pleasant.
Make haptics optional. Let people turn off or mute haptics, and make sure people can still enjoy your app or game without them.
Be aware that playing haptics might impact other user experiences. By design, haptics produce enough physical force for people to feel the vibration. Ensure that haptic vibrations don't disrupt experiences involving device features like the camera, gyroscope, or microphone.
## Custom haptics
Games often use custom haptics to enhance gameplay. Although it's less common, nongame apps might also use custom haptics to provide a richer, more delightful experience.
You can design custom haptic patterns that vary dynamically, based on user input or context. For example, the impact players feel when a game character jumps from a tree can be stronger than when the character jumps in place, and substantial experiences -- like a collision or a hit -- can feel very different from subtle experiences like the approach of footsteps or a looming danger.
There are two basic building blocks you can use to generate custom haptic patterns.
- Transient events are brief and compact, often feeling like taps or impulses. The experience of tapping the Flashlight button on the Home Screen is an example of a transient event.
- Continuous events feel like sustained vibrations, such as the experience of the lasers effect in a message.
Regardless of the type of haptic event you use to generate a custom haptic, you can also control its sharpness and intensity. You can think of sharpness as a way to abstract a haptic experience into the waveform that produces the corresponding physical sensations. Specifying sharpness lets you relay to the system your intent for the experience. For example, you might use sharpness values to convey an experience that's soft, rounded, or organic, or one that's crisp, precise, or mechanical. As the term implies, intensity means the strength of the haptic.
By combining transient and continuous events, varying sharpness and intensity, and including optional audio content, you can create a wide range of different haptic experiences. For developer guidance, see CoreHaptics.
## Platform considerations
## iOS
On supported iPhone models, you can add haptics to your experience in the following ways:
- Use standard UI components -- like toggles, sliders, and pickers -- that play Apple-designed system haptics by default.
- When it makes sense, use a feedback generator to play one of several predefined haptic patterns in the categories of playing-haptics#Notification, playing-haptics#Impact, and playing-haptics#Selection (for developer guidance, see UIFeedbackGenerator).
## Notification
Notification haptics provide feedback about the outcome of a task or action, such as depositing a check or unlocking a vehicle.
## Impact
Impact haptics provide a physical metaphor you can use to complement a visual experience. For example, people might feel a tap when a view snaps into place or a thud when two heavy objects collide.
## Selection
Selection haptics provide feedback while the values of a UI element are changing.
## macOS
When a Magic Trackpad is available, your app can provide one of the three following haptic patterns in response to a drag operation or force click.
For developer guidance, see NSHapticFeedbackPerformer.
## watchOS
Apple Watch Series 4 and later provides haptic feedback for the Digital Crown, which gives people a more tactile experience as they scroll through content. By default, the system provides linear haptic detents that people can feel as they rotate the Digital Crown. Some system controls, like table views, provide detents as new items scroll onto the screen. For developer guidance, see WKHapticType.
watchOS defines the following set of haptics, each of which conveys a specific meaning to people.
## Resources
## Related
feedback
gestures
## Developer documentation
CoreHaptics
## Videos
## Change log
SOURCE: https://developer.apple.com/design/human-interface-guidelines/motion

Many system components automatically include motion, letting you offer familiar and consistent experiences throughout your app or game. System components might also adjust their motion in response to factors like accessibility settings or different input methods. For example, the movement of materials#Liquid-Glass responds to direct touch interaction with greater emphasis to reinforce the feeling of a tactile experience, but produces a more subdued effect when a person interacts using a trackpad.
If you design custom motion, follow the guidelines below.
## Best practices
Add motion purposefully, supporting the experience without overshadowing it. Don't add motion for the sake of adding motion. Gratuitous or excessive animation can distract people and may make them feel disconnected or physically uncomfortable.
Make motion optional. Not everyone can or wants to experience the motion in your app or game, so it's essential to avoid using it as the only way to communicate important information. To help everyone enjoy your app or game, supplement visual feedback by also using alternatives like playing-haptics and playing-audio to communicate.
## Providing feedback
Strive for realistic feedback motion that follows people's gestures and expectations. In nongame apps, accurate, realistic motion can help people understand how something works, but feedback motion that doesn't make sense can make them feel disoriented. For example, if someone reveals a view by sliding it down from the top, they don't expect to dismiss the view by sliding it to the side.
Aim for brevity and precision in feedback animations. When animated feedback is brief and precise, it tends to feel lightweight and unobtrusive, and it can often convey information more effectively than prominent animation. For example, when a game displays a succinct animation that's precisely tied to a successful action, players can instantly get the message without being distracted from their gameplay. Another example is in visionOS: When people tap a panorama in Photos, it quickly and smoothly expands to fill the space in front of them, helping them track the transition without making them wait to enjoy the content.
In apps, generally avoid adding motion to UI interactions that occur frequently. The system already provides subtle animations for interactions with standard interface elements. For a custom element, you generally want to avoid making people spend extra time paying attention to unnecessary motion every time they interact with it.
Let people cancel motion. As much as possible, don't make people wait for an animation to complete before they can do anything, especially if they have to experience the animation more than once.
Consider using animated symbols where it makes sense. When you use SF Symbols 5 or later, you can apply animations to SF Symbols or custom symbols. For guidance, see Animations.
## Leveraging platform capabilities
Make sure your game's motion looks great by default on each platform you support. In most games, maintaining a consistent frame rate of 30 to 60 fps typically results in a smooth, visually appealing experience. For each platform you support, use the device's graphics capabilities to enable default settings that let people enjoy your game without first having to change those settings.
Let people customize the visual experience of your game to optimize performance or battery life. For example, consider letting people switch between power modes when the system detects the presence of an external power source.
## Platform considerations
No additional considerations for iOS, iPadOS, macOS, or tvOS.
## visionOS
In addition to subtly communicating context, drawing attention to information, and enriching immersive experiences, motion in visionOS can combine with depth to provide essential feedback when people look at interactive elements. Because motion is likely to be a large part of your visionOS experience, it's crucial to avoid causing distraction, confusion, or discomfort.
As much as possible, avoid displaying motion at the edges of a person's field of view. People can be particularly sensitive to motion that occurs in their peripheral vision: in addition to being distracting, such motion can even cause discomfort because it can make people feel like they or their surroundings are moving. If you need to show an object moving in the periphery during an immersive experience, make sure the object's brightness level is similar to the rest of the visible content.
Help people remain comfortable when showing the movement of large virtual objects. If an object is large enough to fill a lot of the field of view, occluding most or all of passthrough, people can naturally perceive it as being part of their surroundings. To help people perceive the object's movement without making them think that they or their surroundings are moving, you can increase the object's translucency, helping people see through it, or lower its contrast to make its motion less noticeable.
NOTE: People can experience discomfort even when they're the ones moving a large virtual object, such as a window. Although adjusting translucency and contrast can help in this scenario, consider also keeping a window's size fairly small.
Consider using fades when you need to relocate an object. When an object moves from one location to another, people naturally watch the movement. If such movement doesn't communicate anything useful to people, you can fade the object out before moving it and fade it back in after it's in the new location.
In general, avoid letting people rotate a virtual world. When a virtual world rotates, the experience typically upsets people's sense of stability, even when they control the rotation and the movement is subtle. Instead, consider using instantaneous directional changes during a quick fade-out.
Consider giving people a stationary frame of reference. It can be easier for people to handle visual movement when it's contained within an area that doesn't move. In contrast, if the entire surrounding area appears to move -- for example, in a game that automatically moves a player through space -- people can feel unwell.
Avoid showing objects that oscillate in a sustained way. In particular, you want to avoid showing an oscillation that has a frequency of around 0.2 Hz because people can be very sensitive to this frequency. If you need to show objects oscillating, aim to keep the amplitude low and consider making the content translucent.
## watchOS
SwiftUI provides a powerful and streamlined way to add motion to your app. If you need to use WatchKit to animate layout and appearance changes -- or create animated image sequences -- see WKInterfaceImage.
NOTE: All layout- and appearance-based animations automatically include built-in easing that plays at the start and end of the animation. You can't turn off or customize easing.
## Resources
## Related
feedback

spatial-layout
immersive-experiences
## Developer documentation
animating-views-and-transitions -- SwiftUI
## Videos
## Change log
SOURCE: https://developer.apple.com/design/human-interface-guidelines/feedback

Providing clear, consistent feedback as people interact with your app or game can make it feel intuitive and encourage deeper exploration. Feedback can communicate several different things, such as:
- The current status of something
- The success or failure of an important task or action
- A warning about an action that can have negative consequences
- An opportunity to correct a mistake or problematic situation
The most effective feedback tends to match the significance of the information to the way it's delivered. For example, it often works well to display status information in a passive way so that people can view it when they need it. In contrast, a warning about possible data loss needs to interrupt people so they have a chance to avoid the problem.
## Best practices
Make sure all feedback is accessible. When you use multiple ways to provide feedback, you reach more people and give them the opportunity to receive the feedback in ways that work for them. For example, when you provide feedback using color, text, sound, and haptics, people can receive it whether they silence their device, look away from the screen, or use VoiceOver. (For guidance on providing haptic feedback, see playing-haptics.)
Consider integrating status feedback into your interface. When status feedback is available near the items it describes, people get important information without having to take action or leave their current context. For example, Mail in iOS and iPadOS describes the most recent update and displays the number of unread messages in the toolbar of the mailbox screen, making the information unobtrusive but easy for people to check when they're interested.
Use alerts to deliver critical -- and ideally actionable -- information. By design, alerts disrupt the current context, so you need to match the importance of the information to the level of interruption. Alerts can lose their impact if you use them too often or to deliver unimportant information. For guidance, see alerts.
Warn people when they initiate a task that can cause data loss that's unexpected and irreversible. In contrast, don't warn people when data loss is the expected result of their action. For example, the Finder doesn't warn people every time they throw away a file because deleting the file is the expected result.
When it makes sense, confirm that a significant action or task has completed. For example, people appreciate getting feedback that confirms a successful Apple Pay transaction. It's generally best to reserve this type of confirmation for activities that are sufficiently important -- because people typically expect their action or task to succeed, they only need to know when it doesn't.
Show people when a command can't be carried out and help them understand why. For example, if people request directions without specifying a destination, Maps tells them that it can't provide directions to and from the same location.
## Platform considerations
No additional considerations for iOS, iPadOS, macOS, tvOS, or visionOS.
## watchOS
Avoid displaying an indeterminate progress indicator -- such as a loading indicator -- in a watchOS app. An animated indicator can make people think they need to continue paying attention to the display, which isn't a good user experience. To provide a better experience, reassure people that they'll receive a notification when the process completes.
## Resources
## Related
playing-audio
playing-haptics
motion
## Developer documentation
animation-and-haptics -- UIKit
## Videos
SOURCE: https://developer.apple.com/design/human-interface-guidelines/loading

If your app or game loads assets, levels, or other content, design the behavior so it doesn't disrupt or negatively impact the user experience.
## Best practices
Show something as soon as possible. If you make people wait for loading to complete before displaying anything, they can interpret the lack of content as a problem with your app or game. Instead, consider showing placeholder text, graphics, or animations as content loads, replacing these elements as content becomes available.
Let people do other things in your app or game while they wait for content to load. Loading content in the background helps give people access to other actions. For example, a game could load content in the background while players learn about the next level or view an in-game menu. For developer guidance, see improving-the-player-experience-for-games-with-large-downloads.
If loading takes an unavoidably long time, give people something interesting to view while they wait. For example, you might provide gameplay hints, display tips, or introduce people to new features. Gauge the remaining loading time as accurately as possible to help you avoid giving people too little time to enjoy your placeholder content or having so much time that you need to repeat it.
Improve installation and launch time by downloading large assets in the background. Consider using the BackgroundAssets framework to schedule asset downloads -- like game level packs, 3D character models, and textures -- to occur immediately after installation, during updates, or at other nondisruptive times.
## Showing progress
Clearly communicate that content is loading and how long it might take to complete. Ideally, content displays instantly, but for situations where loading takes more than a moment or two, you can use system-provided components -- called progress indicators -- to show that loading is ongoing. In general, you use a determinate progress indicator when you know how long loading will take, and you use an indeterminate progress indicator when you don't. For guidance, see progress-indicators.
For games, consider creating a custom loading view. Standard progress indicators work well in most apps, but can sometimes feel out of place in a game. Consider designing a more engaging experience by using custom animations and elements that match the style of your game.
## Platform considerations
No additional considerations for iOS, iPadOS, macOS, tvOS, or visionOS.
## watchOS
As much as possible, avoid showing a loading indicator in your watchOS experience. People expect quick interactions with their Apple Watch, so aim to display content immediately. In situations where content needs a second or two to load, it's better to display a loading indicator than a blank screen.
## Resources
## Related
launching
progress-indicators
## Developer documentation
BackgroundAssets
## Videos
## Change log
SOURCE: https://developer.apple.com/design/human-interface-guidelines/accessibility

When you design for accessibility, you reach a larger audience and create a more inclusive experience. An accessible interface allows people to experience your app or game regardless of their capabilities or how they use their devices. Accessibility makes information and interactions available to everyone. An accessible interface is:
- Intuitive. Your interface uses familiar and consistent interactions that make tasks straightforward to perform.
- Perceivable. Your interface doesn't rely on any single method to convey information. People can access and interact with your content, whether they use sight, hearing, speech, or touch.
- Adaptable. Your interface adapts to how people want to use their device, whether by supporting system accessibility features or letting people personalize settings.
As you design your app, audit the accessibility of your interface. Use accessibility-inspector to highlight accessibility issues with your interface and to understand how your app represents itself to people using system accessibility features. You can also communicate how accessible your app is on the App Store using Accessibility Nutrition Labels. To learn more about how to evaluate and indicate accessibility feature support, see overview-of-accessibility-nutrition-labels in App Store Connect help.
## Vision

The people who use your interface may be blind, color blind, or have low vision or light sensitivity. They may also be in situations where lighting conditions and screen brightness affect their ability to interact with your interface.
Support larger text sizes. Make sure people can adjust the size of your text or icons to make them more legible, visible, and comfortable to read. Ideally, give people the option to enlarge text by at least 200 percent (or 140 percent in watchOS apps). Your interface can support font size enlargement either through custom UI, or by adopting Dynamic Type. Dynamic Type is a systemwide setting that lets people adjust the size of text for comfort and legibility. For more guidance, see typography#Supporting-Dynamic-Type.
Use recommended defaults for custom type sizes. Each platform has different default and minimum sizes for system-defined type styles to promote readability. If you're using custom type styles, follow the recommended defaults.
Bear in mind that font weight can also impact how easy text is to read. If you're using a custom font with a thin weight, aim for larger than the recommended sizes to increase legibility. For more guidance, see typography.
Strive to meet color contrast minimum standards. To ensure all information in your app is legible, it's important that there's enough contrast between foreground text and icons and background colors. Two popular standards of measure for color contrast are the  and the Accessible Perceptual Contrast Algorithm (APCA). Use standard contrast calculators to ensure your UI meets acceptable levels. accessibility-inspector uses the following values from WCAG Level AA as guidance in determining whether your app's colors have an acceptable contrast.
If your app doesn't provide this minimum contrast by default, ensure it at least provides a higher contrast color scheme when the system setting Increase Contrast is turned on. If your app supports dark-mode, make sure to check the minimum contrast in both light and dark appearances.
Prefer system-defined colors. These colors have their own accessible variants that automatically adapt when people adjust their color preferences, such as enabling Increase Contrast or toggling between the light and dark appearances. For guidance, see color.
Convey information with more than color alone. Some people have trouble differentiating between certain colors and shades. For example, people who are color blind may have particular difficulty with pairings such as red-green and blue-orange. Offer visual indicators, like distinct shapes or icons, in addition to color to help people perceive differences in function and changes in state. Consider allowing people to customize color schemes such as chart colors or game characters so they can personalize your interface in a way that's comfortable for them.
Describe your app's interface and content for VoiceOver. VoiceOver is a screen reader that lets people experience your app's interface without needing to see the screen. For more guidance, see voiceover.
## Hearing

The people who use your interface may be deaf or hard of hearing. They may also be in noisy or public environments.
Support text-based ways to enjoy audio and video. It's important that dialogue and crucial information about your app or game isn't communicated through audio alone. Depending on the context, give people different text-based ways to experience their media, and allow people to customize the visual presentation of that text:
- Captions give people the textual equivalent of audible information in video or audio-only content. Captions are great for scenarios like game cutscenes and video clips where text synchronizes live with the media.
- Subtitles allow people to read live onscreen dialogue in their preferred language. Subtitles are great for TV shows and movies.
- Audio descriptions are interspersed between natural pauses in the main audio of a video and supply spoken narration of important information that's presented only visually.
- Transcripts provide a complete textual description of a video, covering both audible and visual information. Transcripts are great for longer-form media like podcasts and audiobooks where people may want to review content as a whole or highlight the transcript as media is playing.
For developer guidance, see selecting-subtitles-and-alternative-audio-tracks.
Use haptics in addition to audio cues. If your interface conveys information through audio cues -- such as a success chime, error sound, or game feedback -- consider pairin

=== TARGET: STORYCUE / TELLFOLK (SwiftUI) source ===

--- storycue/StoryCue/StoryCueApp.swift ---
     1	import SwiftUI
     2	
     3	@main
     4	struct StoryCueApp: App {
     5	    #if DEBUG
     6	    // `-StoryCueDemo` (ScreenshotTests only) launches the seeded mock demo; everything else
     7	    // is production. The Release build compiles only the production line below.
     8	    private static let isDark: Bool = ProcessInfo.processInfo.arguments.contains("-StoryCueDark")
     9	    private static let isAX5: Bool = ProcessInfo.processInfo.arguments.contains("-StoryCueAX5")
    10	    @State private var model = ProcessInfo.processInfo.arguments.contains("-StoryCueDemo")
    11	        ? AppModel.demo()
    12	        : AppModel.production()
    13	    #else
    14	    @State private var model = AppModel.production()
    15	    #endif
    16	
    17	    var body: some Scene {
    18	        WindowGroup {
    19	            #if DEBUG
    20	            RootView(model: model)
    21	                .preferredColorScheme(Self.isDark ? .dark : nil)
    22	                .modifier(AccessibilitySizeModifier(isEnabled: Self.isAX5))
    23	                .task { await model.library.load() }
    24	            #else
    25	            RootView(model: model)
    26	                .task { await model.library.load() }
    27	            #endif
    28	        }
    29	    }
    30	}
    31	
    32	#if DEBUG
    33	private struct AccessibilitySizeModifier: ViewModifier {
    34	    let isEnabled: Bool
    35	
    36	    @ViewBuilder
    37	    func body(content: Content) -> some View {
    38	        if isEnabled {
    39	            content.dynamicTypeSize(.accessibility5)
    40	        } else {
    41	            content
    42	        }
    43	    }
    44	}
    45	#endif

--- storycue/StoryCue/DesignTokens.swift ---
     1	import SwiftUI
     2	
     3	enum DesignTokens {
     4	    enum Spacing {           // multiples of 4
     5	        static let xs: CGFloat = 4
     6	        static let s: CGFloat = 8
     7	        static let m: CGFloat = 12
     8	        static let l: CGFloat = 16
     9	        static let xl: CGFloat = 24
    10	    }
    11	    enum Radius {
    12	        static let card: CGFloat = 12      // cards, banners, callouts
    13	        static let tile: CGFloat = 10      // deck tiles
    14	    }
    15	    enum Motion {                          // nothing over 0.5 s
    16	        static let morph = Animation.spring(duration: 0.3)
    17	        static let fade = Animation.easeOut(duration: 0.2)
    18	    }
    19	    enum RecordButton {
    20	        static let outer: CGFloat = 72
    21	        static let ringWidth: CGFloat = 4
    22	        static let dot: CGFloat = 58
    23	        static let square: CGFloat = 28
    24	        static let squareRadius: CGFloat = 6
    25	    }
    26	    /// The serif trial (design review row 6). Revert to `.default` in this one line.
    27	    static let questionFontDesign: Font.Design = .serif
    28	    static let onAccent = Color("OnAccent")
    29	    /// Deck tiles: one terracotta family, never a rainbow (WW-0103 disagreement 4).
    30	    static let tileFill = Color.accentColor.opacity(0.15)
    31	    static let tileSymbol = Color.accentColor
    32	    static func deckSymbol(_ deckID: String) -> String {
    33	        switch deckID {
    34	        case "grandparents": "house"
    35	        case "parents": "figure.2.and.child.holdinghands"
    36	        case "kids": "questionmark.bubble"
    37	        case "couples": "heart"
    38	        case "holiday-table": "fork.knife"
    39	        default: "text.bubble"
    40	        }
    41	    }
    42	    /// Translucent black behind text over the camera (>= 7:1 white text over a white feed).
    43	    static let overCameraFill = Color.black.opacity(0.7)
    44	    /// The recording pill: darker than system red so white text clears 4.5:1.
    45	    static let recordingFill = Color(red: 0.78, green: 0.10, blue: 0.10)
    46	    #if DEBUG
    47	    static let demoBackdropTop = Color(red: 0.20, green: 0.13, blue: 0.09)
    48	    static let demoBackdropBottom = Color(red: 0.06, green: 0.04, blue: 0.03)
    49	    #endif
    50	}
    51	
    52	extension View {
    53	    /// The one filled primary action of a screen: full width, large, accent fill,
    54	    /// `OnAccent` label. Apply to a `Button` whose label is `Text`.
    55	    func primaryAction() -> some View {
    56	        self
    57	            .buttonStyle(.borderedProminent)
    58	            .controlSize(.large)
    59	            .foregroundStyle(DesignTokens.onAccent)
    60	    }
    61	}

--- storycue/StoryCue/Views/AnswerPlayerView.swift ---
     1	@preconcurrency import AVFoundation
     2	import AVKit
     3	import SwiftUI
     4	
     5	/// The answer the full-screen player is playing, identified by its question. `id` is the
     6	/// question ID, so a `fullScreenCover(item:)` presents exactly one player per answer.
     7	struct PlayableAnswer: Identifiable, Hashable {
     8	    let questionID: String
     9	    var id: String { questionID }
    10	}
    11	
    12	/// The system player: `AVPlayerViewController` with its own transport controls -- no custom
    13	/// chrome. Only wraps an existing player; it never creates or owns one.
    14	struct SystemPlayer: UIViewControllerRepresentable {
    15	    let player: AVPlayer
    16	
    17	    func makeUIViewController(context: Context) -> AVPlayerViewController {
    18	        let controller = AVPlayerViewController()
    19	        controller.player = player
    20	        return controller
    21	    }
    22	
    23	    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
    24	}
    25	
    26	/// Full-screen playback of one answer. Sources are the segment files export would use;
    27	/// `AVStitcher.makeComposition` builds the composition in memory -- playback never writes a
    28	/// file and never touches the segment directory. States: loading (`ProgressView`), playing
    29	/// (autoplayed once ready) and unavailable (`UICopy.playbackUnavailable`, when the build
    30	/// throws or nothing is readable). The question text sits in a dark material card at the
    31	/// top, over the video and above the system controls' hit area; after 3 seconds it shrinks
    32	/// to one line (instantly under Reduce Motion) and never fully disappears.
    33	struct AnswerPlayerView: View {
    34	    let sources: [URL]
    35	    let caption: String
    36	
    37	    @Environment(\.dismiss) private var dismiss
    38	    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    39	    @State private var player: AVPlayer?
    40	    @State private var isReady = false
    41	    @State private var isUnavailable = false
    42	    @State private var captionExpanded = true
    43	
    44	    var body: some View {
    45	        ZStack {
    46	            Color.black.ignoresSafeArea()
    47	            if let player {
    48	                SystemPlayer(player: player)
    49	                    .ignoresSafeArea()
    50	            }
    51	            VStack(spacing: 0) {
    52	                HStack(alignment: .top, spacing: 12) {
    53	                    captionCard
    54	                    Spacer(minLength: 0)
    55	                    Button(UICopy.done) { dismiss() }
    56	                        .font(.body)
    57	                        .frame(minWidth: 44, minHeight: 44)
    58	                        .background(.black.opacity(0.5), in: Capsule())
    59	                }
    60	                .padding()
    61	                Spacer()
    62	            }
    63	            if isUnavailable {
    64	                Text(UICopy.playbackUnavailable)
    65	                    .font(.body)
    66	                    .foregroundStyle(.secondary)
    67	                    .padding()
    68	            } else if !isReady {
    69	                ProgressView()
    70	            }
    71	        }
    72	        // `.task`, not `onAppear` + `Task {}`: SwiftUI cancels these when the cover is
    73	        // dismissed, so a load that finishes after dismissal never starts an invisible player.
    74	        .task { await load() }
    75	        .task { await shrinkCaption() }
    76	        .onDisappear(perform: release)
    77	    }
    78	
    79	    private var captionCard: some View {
    80	        Text(caption)
    81	            .font(.body)
    82	            .lineLimit(captionExpanded ? nil : 1)
    83	            .padding(.horizontal, 12)
    84	            .padding(.vertical, 8)
    85	            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
    86	            .environment(\.colorScheme, .dark)
    87	    }
    88	
    89	    private func load() async {
    90	        // Playback owns the audio session while the cover is up. Nothing restores it:
    91	        // AVCaptureSession.automaticallyConfiguresApplicationAudioSession reconfigures the
    92	        // app audio session itself when the next recording starts (see the comment near
    93	        // AVCaptureService.swift:160 -- unverified, so it is on the S2c device-check list).
    94	        let audioSession = AVAudioSession.sharedInstance()
    95	        try? audioSession.setCategory(.playback, mode: .moviePlayback)
    96	        try? audioSession.setActive(true)
    97	
    98	        do {
    99	            let built = try await AVStitcher.makeComposition(sources)
   100	            guard !Task.isCancelled else { return }
   101	            guard built.durationSeconds > 0 else {
   102	                isUnavailable = true
   103	                return
   104	            }
   105	            let readyPlayer = AVPlayer(playerItem: AVPlayerItem(asset: built.composition))
   106	            player = readyPlayer
   107	            isReady = true
   108	            readyPlayer.play()
   109	        } catch is CancellationError {
   110	            // The cover was dismissed mid-load: nothing to show, and not "unavailable".
   111	        } catch {
   112	            guard !Task.isCancelled else { return }
   113	            isUnavailable = true
   114	        }
   115	    }
   116	
   117	    private func shrinkCaption() async {
   118	        try? await Task.sleep(for: .seconds(3))
   119	        guard !Task.isCancelled else { return }
   120	        withAnimation(reduceMotion ? nil : .default) {
   121	            captionExpanded = false
   122	        }
   123	    }
   124	
   125	    private func release() {
   126	        player?.pause()
   127	        player = nil
   128	        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
   129	    }
   130	}

--- storycue/StoryCue/Views/ConsentView.swift ---
     1	import SwiftUI
     2	
     3	/// The consent card AND the permission-priming screen: the system camera/mic prompts
     4	/// appear only after the confirm tap, with this explanation already on screen.
     5	struct ConsentView: View {
     6	    let deck: Deck
     7	    let model: AppModel
     8	
     9	    @State private var isBeginning = false
    10	
    11	    var body: some View {
    12	        ScrollView {
    13	            VStack(alignment: .leading, spacing: 20) {
    14	                Text(UICopy.consentTitle)
    15	                    .font(.largeTitle.bold())
    16	
    17	                Text(UICopy.consentBody)
    18	                    .font(.body)
    19	
    20	                // The read-aloud line, in a quoted callout.
    21	                HStack(alignment: .firstTextBaseline) {
    22	                    Image(systemName: "quote.opening")
    23	                        .foregroundStyle(.tint)
    24	                        .accessibilityHidden(true)
    25	                    Text(UICopy.readAloudCallout)
    26	                        .font(.title3)
    27	                        .fontDesign(DesignTokens.questionFontDesign)
    28	                }
    29	                .padding()
    30	                .frame(maxWidth: .infinity, alignment: .leading)
    31	                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
    32	
    33	                Text(UICopy.privacyNote)
    34	                    .font(.footnote)
    35	                    .foregroundStyle(.secondary)
    36	
    37	                if model.library.storage.isLow {
    38	                    Text(UICopy.lowSpaceConsentNote)
    39	                        .font(.footnote)
    40	                        .foregroundStyle(.secondary)
    41	                }
    42	            }
    43	            .padding()
    44	        }
    45	        .safeAreaInset(edge: .bottom) {
    46	            Button {
    47	                isBeginning = true
    48	                Task {
    49	                    await model.beginSession(deck: deck)
    50	                    // Done/Finish pops back to this screen, so the button must re-enable.
    51	                    isBeginning = false
    52	                }
    53	            } label: {
    54	                Text(UICopy.consentConfirm)
    55	                    .frame(maxWidth: .infinity)
    56	            }
    57	            .primaryAction()
    58	            .disabled(isBeginning || !model.library.isLoaded)
    59	            .accessibilityLabel(UICopy.consentConfirm)
    60	            .accessibilityIdentifier("consentConfirm")
    61	            .padding(DesignTokens.Spacing.l)
    62	            .background(.bar)
    63	        }
    64	        .navigationTitle(deck.title)
    65	        .navigationBarTitleDisplayMode(.inline)
    66	    }
    67	}

--- storycue/StoryCue/Views/DeckPickerView.swift ---
     1	import SwiftUI
     2	
     3	struct DeckPickerView: View {
     4	    let model: AppModel
     5	
     6	    var body: some View {
     7	        List {
     8	            if model.library.storage.isLow {
     9	                Section {
    10	                    StorageBanner(availableBytes: model.library.storage.availableBytes)
    11	                }
    12	            }
    13	            Section {
    14	                ForEach(Deck.v1Decks) { deck in
    15	                    NavigationLink {
    16	                        ConsentView(deck: deck, model: model)
    17	                    } label: {
    18	                        DeckRowLabel(deckID: deck.id, title: deck.title) {
    19	                            Text(UICopy.deckTeaser(deck.id))
    20	                                .font(.callout)
    21	                                .foregroundStyle(.secondary)
    22	                        }
    23	                    }
    24	                    .accessibilityLabel(
    25	                        "\(deck.title), \(UICopy.deckTeaser(deck.id)), \(UICopy.questionCount(deck.questions.count))"
    26	                    )
    27	                    .accessibilityIdentifier("deck.\(deck.id)")
    28	                }
    29	            }
    30	        }
    31	        .navigationTitle(UICopy.deckPickerTitle)
    32	        .toolbar {
    33	            ToolbarItem(placement: .topBarTrailing) {
    34	                NavigationLink {
    35	                    LibraryView(model: model)
    36	                } label: {
    37	                    Text(UICopy.libraryButton)
    38	                }
    39	                .disabled(!model.library.isLoaded)
    40	                .accessibilityIdentifier("libraryButton")
    41	            }
    42	        }
    43	    }
    44	}

--- storycue/StoryCue/Views/DeckTile.swift ---
     1	import SwiftUI
     2	
     3	struct DeckTile: View {
     4	    let deckID: String
     5	
     6	    @ScaledMetric(relativeTo: .title2) private var side: CGFloat = 48
     7	
     8	    var body: some View {
     9	        let cappedSide = min(side, 72)
    10	        Image(systemName: DesignTokens.deckSymbol(deckID))
    11	            .font(.title2)
    12	            .foregroundStyle(DesignTokens.tileSymbol)
    13	            .frame(width: cappedSide, height: cappedSide)
    14	            .background(
    15	                DesignTokens.tileFill,
    16	                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.tile)
    17	            )
    18	            .accessibilityHidden(true)
    19	    }
    20	}
    21	
    22	struct DeckRowLabel<Detail: View>: View {
    23	    let deckID: String
    24	    let title: String
    25	    @ViewBuilder let detail: Detail
    26	
    27	    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    28	
    29	    var body: some View {
    30	        Group {
    31	            if dynamicTypeSize.isAccessibilitySize {
    32	                VStack(alignment: .leading, spacing: DesignTokens.Spacing.m) {
    33	                    DeckTile(deckID: deckID)
    34	                    text
    35	                }
    36	            } else {
    37	                HStack(spacing: DesignTokens.Spacing.m) {
    38	                    DeckTile(deckID: deckID)
    39	                    text
    40	                }
    41	            }
    42	        }
    43	        .padding(.vertical, DesignTokens.Spacing.xs)
    44	    }
    45	
    46	    private var text: some View {
    47	        VStack(alignment: .leading) {
    48	            Text(title)
    49	                .font(.title2)
    50	            detail
    51	        }
    52	    }
    53	}

--- storycue/StoryCue/Views/ExportView.swift ---
     1	import SwiftUI
     2	
     3	/// The export sheet over `ExportModel`. It can't be swiped away mid-export, and leaving it
     4	/// cancels a running export or closes a pending share (so the temp directory and the
     5	/// exporting flag never outlive the sheet).
     6	struct ExportView: View {
     7	    @Bindable var model: ExportModel
     8	    @Environment(\.dismiss) private var dismiss
     9	    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    10	
    11	    private var isRunning: Bool {
    12	        if case .running = model.phase { return true }
    13	        return false
    14	    }
    15	
    16	    private var sharingResult: ExportResult? {
    17	        if case let .sharing(result) = model.phase { return result }
    18	        return nil
    19	    }
    20	
    21	    var body: some View {
    22	        NavigationStack {
    23	            // Scrolls so long result/failure copy at accessibility sizes can't push Done off screen.
    24	            ScrollView {
    25	                content
    26	                    .padding()
    27	                    .frame(maxWidth: .infinity, alignment: .topLeading)
    28	            }
    29	            .navigationTitle(UICopy.exportTitle)
    30	            .navigationBarTitleDisplayMode(.inline)
    31	        }
    32	        .interactiveDismissDisabled(isRunning)
    33	        .onDisappear {
    34	            switch model.phase {
    35	            case .running:
    36	                model.cancel()
    37	            case .sharing:
    38	                Task { await model.shareDismissed() }
    39	            case .choosing, .finished, .failed:
    40	                break
    41	            }
    42	        }
    43	        .sheet(
    44	            isPresented: Binding(
    45	                get: { sharingResult != nil },
    46	                set: { isPresented in
    47	                    if !isPresented { Task { await model.shareDismissed() } }
    48	                }
    49	            )
    50	        ) {
    51	            if let result = sharingResult {
    52	                shareSheet(for: result)
    53	            }
    54	        }
    55	    }
    56	
    57	    private func shareSheet(for result: ExportResult) -> some View {
    58	        let model = self.model
    59	        return ShareSheet(items: result.files) {
    60	            Task { await model.shareDismissed() }
    61	        }
    62	    }
    63	
    64	    @ViewBuilder
    65	    private var content: some View {
    66	        switch model.phase {
    67	        case .choosing:
    68	            choosing
    69	        case let .running(done, total):
    70	            running(done: done, total: total)
    71	        case .sharing:
    72	            // The share sheet is up; this is what shows behind it.
    73	            Text(UICopy.exporting(0, 0))
    74	                .font(.body)
    75	        case let .finished(message), let .failed(message):
    76	            VStack(alignment: .leading, spacing: 20) {
    77	                Text(message)
    78	                    .font(.body)
    79	                Button(UICopy.done) { dismiss() }
    80	                    .buttonStyle(.borderedProminent)
    81	                    .font(.title2)
    82	                    .frame(maxWidth: .infinity, minHeight: 44)
    83	            }
    84	        }
    85	    }
    86	
    87	    private var choosing: some View {
    88	        VStack(alignment: .leading, spacing: 20) {
    89	            // Segments can't wrap, so at accessibility sizes the choice becomes a menu button.
    90	            if dynamicTypeSize.isAccessibilitySize {
    91	                unitPicker
    92	                    .pickerStyle(.menu)
    93	                    .frame(minHeight: 44)
    94	            } else {
    95	                unitPicker
    96	                    .pickerStyle(.segmented)
    97	                    .frame(minHeight: 44)
    98	            }
    99	
   100	            Button(UICopy.exportToFiles) { model.start(.files) }
   101	                .buttonStyle(.borderedProminent)
   102	                .font(.title2)
   103	                .frame(maxWidth: .infinity, minHeight: 44)
   104	
   105	            Button(UICopy.exportToPhotos) { model.start(.photos) }
   106	                .buttonStyle(.bordered)
   107	                .font(.title2)
   108	                .frame(maxWidth: .infinity, minHeight: 44)
   109	        }
   110	    }
   111	
   112	    private var unitPicker: some View {
   113	        Picker(UICopy.exportTitle, selection: $model.unit) {
   114	            Text(UICopy.exportEachAnswer).tag(ExportUnit.perClip)
   115	            Text(UICopy.exportOneVideo).tag(ExportUnit.wholeSession)
   116	        }
   117	        .labelsHidden()
   118	    }
   119	
   120	    private func running(done: Int, total: Int) -> some View {
   121	        VStack(alignment: .leading, spacing: 20) {
   122	            if total == 0 {
   123	                ProgressView()
   124	            } else {
   125	                ProgressView(value: Double(done), total: Double(total))
   126	            }
   127	            Text(UICopy.exporting(done, total))
   128	                .font(.body)
   129	            Button(UICopy.cancel) { model.cancel() }
   130	                .buttonStyle(.bordered)
   131	                .font(.title2)
   132	                .frame(maxWidth: .infinity, minHeight: 44)
   133	        }
   134	    }
   135	}

--- storycue/StoryCue/Views/LibraryView.swift ---
     1	import SwiftUI
     2	
     3	/// The recordings list: recovered clips awaiting a keep/delete decision, then one row per
     4	/// session. Every delete asks first; there is no `.onDelete`, because a full swipe would skip
     5	/// the confirmation.
     6	struct LibraryView: View {
     7	    let model: AppModel
     8	
     9	    @Environment(\.dismiss) private var dismiss
    10	    @State private var pendingSessionDelete: UUID?
    11	    @State private var pendingClipDelete: RecoveredClip?
    12	
    13	    private var library: Library { model.library }
    14	
    15	    var body: some View {
    16	        let recovered = library.recovered
    17	        return List {
    18	            if !recovered.isEmpty {
    19	                Section {
    20	                    ForEach(recovered) { clip in
    21	                        recoveredRow(clip)
    22	                    }
    23	                } header: {
    24	                    Text(UICopy.recoveredHeader)
    25	                } footer: {
    26	                    Text(UICopy.recoveredExplainer)
    27	                }
    28	            }
    29	
    30	            if !library.sessions.isEmpty {
    31	                Section {
    32	                    ForEach(library.sessions) { record in
    33	                        sessionRow(record)
    34	                    }
    35	                }
    36	            }
    37	
    38	            Section {
    39	            } footer: {
    40	                Text(UICopy.storageFooter(
    41	                    used: library.storage.usedBytes,
    42	                    available: library.storage.availableBytes
    43	                ))
    44	            }
    45	        }
    46	        .overlay {
    47	            if library.sessions.isEmpty && recovered.isEmpty {
    48	                ContentUnavailableView {
    49	                    Label(UICopy.libraryEmptyTitle, systemImage: "video.slash")
    50	                } description: {
    51	                    Text(UICopy.libraryEmptyBody)
    52	                } actions: {
    53	                    Button(UICopy.libraryEmptyAction) { dismiss() }
    54	                        .primaryAction()
    55	                }
    56	            }
    57	        }
    58	        .navigationTitle(UICopy.libraryTitle)
    59	        .onAppear { library.refreshStorage() }
    60	        .confirmationDialog(
    61	            UICopy.deleteSessionConfirm,
    62	            isPresented: Binding(
    63	                get: { pendingSessionDelete != nil },
    64	                set: { isPresented in
    65	                    if !isPresented { pendingSessionDelete = nil }
    66	                }
    67	            ),
    68	            titleVisibility: .visible,
    69	            presenting: pendingSessionDelete
    70	        ) { sessionID in
    71	            Button(UICopy.deleteSession, role: .destructive) {
    72	                Task { await library.delete(sessionID: sessionID) }
    73	            }
    74	        }
    75	        .confirmationDialog(
    76	            UICopy.deleteClipConfirm,
    77	            isPresented: Binding(
    78	                get: { pendingClipDelete != nil },
    79	                set: { isPresented in
    80	                    if !isPresented { pendingClipDelete = nil }
    81	                }
    82	            ),
    83	            titleVisibility: .visible,
    84	            presenting: pendingClipDelete
    85	        ) { clip in
    86	            Button(UICopy.deleteClip, role: .destructive) {
    87	                Task { await library.discard(clip) }
    88	            }
    89	        }
    90	    }
    91	
    92	    private func recoveredRow(_ clip: RecoveredClip) -> some View {
    93	        let record = library.record(id: clip.sessionID)
    94	        let counter: String
    95	        if let position = record?.questionPosition(for: clip.segment.questionID) {
    96	            counter = UICopy.questionCounter(position.index, position.count)
    97	        } else {
    98	            counter = clip.segment.questionID
    99	        }
   100	        return VStack(alignment: .leading, spacing: 8) {
   101	            Text(record?.deckTitle ?? "")
   102	                .font(.title2)
   103	            Text(counter)
   104	                .font(.body)
   105	            Text(clip.segment.startedAt.formatted(date: .abbreviated, time: .shortened))
   106	                .font(.callout)
   107	                .foregroundStyle(.secondary)
   108	            VStack(spacing: 8) {
   109	                Button(UICopy.keep) {
   110	                    Task { await library.keep(clip) }
   111	                }
   112	                .buttonStyle(.bordered)
   113	                .frame(maxWidth: .infinity, minHeight: 44)
   114	                Button(UICopy.deleteClip, role: .destructive) {
   115	                    pendingClipDelete = clip
   116	                }
   117	                .buttonStyle(.bordered)
   118	                .frame(maxWidth: .infinity, minHeight: 44)
   119	            }
   120	        }
   121	        .padding(.vertical, 4)
   122	    }
   123	
   124	    private func sessionRow(_ record: SessionRecord) -> some View {
   125	        NavigationLink {
   126	            SessionDetailView(sessionID: record.id, model: model)
   127	        } label: {
   128	            DeckRowLabel(deckID: record.deckID, title: record.deckTitle) {
   129	                Text(UICopy.sessionSubtitle(record.startedAt, count: record.manifest.count))
   130	                    .font(.callout)
   131	                    .foregroundStyle(.secondary)
   132	            }
   133	        }
   134	        .accessibilityIdentifier("session.\(record.deckID)")
   135	        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
   136	            if library.canDelete(record.id) {
   137	                Button(UICopy.deleteSession, role: .destructive) {
   138	                    pendingSessionDelete = record.id
   139	                }
   140	            }
   141	        }
   142	    }
   143	}

--- storycue/StoryCue/Views/RecordButton.swift ---
     1	import SwiftUI
     2	
     3	struct RecordButton: View {
     4	    let primary: RecorderPresentation.Primary
     5	    let label: String
     6	    let action: () -> Void
     7	
     8	    @Environment(\.accessibilityReduceMotion) private var reduceMotion
     9	
    10	    var body: some View {
    11	        VStack(spacing: DesignTokens.Spacing.xs) {
    12	            Button(action: action) {
    13	                ZStack {
    14	                    Circle()
    15	                        .fill(DesignTokens.overCameraFill)
    16	                    Circle()
    17	                        .strokeBorder(.white, lineWidth: DesignTokens.RecordButton.ringWidth)
    18	
    19	                    switch primary.glyph {
    20	                    case .dot, .square:
    21	                        let isSquare = primary.glyph == .square
    22	                        RoundedRectangle(
    23	                            cornerRadius: isSquare
    24	                                ? DesignTokens.RecordButton.squareRadius
    25	                                : DesignTokens.RecordButton.dot / 2
    26	                        )
    27	                        .fill(Color.red)
    28	                        .frame(
    29	                            width: isSquare
    30	                                ? DesignTokens.RecordButton.square
    31	                                : DesignTokens.RecordButton.dot,
    32	                            height: isSquare
    33	                                ? DesignTokens.RecordButton.square
    34	                                : DesignTokens.RecordButton.dot
    35	                        )
    36	                        .animation(
    37	                            reduceMotion ? nil : DesignTokens.Motion.morph,
    38	                            value: primary.glyph
    39	                        )
    40	                    case .spinner:
    41	                        ProgressView()
    42	                            .tint(.white)
    43	                    case .cancel:
    44	                        Circle()
    45	                            .fill(DesignTokens.overCameraFill)
    46	                            .frame(
    47	                                width: DesignTokens.RecordButton.dot,
    48	                                height: DesignTokens.RecordButton.dot
    49	                            )
    50	                        Image(systemName: "xmark")
    51	                            .font(.title2.bold())
    52	                            .foregroundStyle(.white)
    53	                    }
    54	                }
    55	                .frame(
    56	                    width: DesignTokens.RecordButton.outer,
    57	                    height: DesignTokens.RecordButton.outer
    58	                )
    59	                .contentShape(Circle())
    60	            }
    61	            .disabled(primary == .saving || primary == .unavailable)
    62	            .accessibilityLabel(label)
    63	            .accessibilityIdentifier("recordButton")
    64	
    65	            Text(label)
    66	                .font(.footnote)
    67	                .foregroundStyle(.white)
    68	                .padding(.horizontal, DesignTokens.Spacing.s)
    69	                .padding(.vertical, DesignTokens.Spacing.xs)
    70	                .background(DesignTokens.overCameraFill, in: Capsule())
    71	                .accessibilityHidden(true)
    72	        }
    73	    }
    74	}

--- storycue/StoryCue/Views/RecorderView.swift ---
     1	import SwiftUI
     2	import UIKit
     3	
     4	struct RecorderView: View {
     5	    let session: AppModel.ActiveSession
     6	    let model: AppModel
     7	
     8	    @Environment(\.scenePhase) private var scenePhase
     9	    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    10	    @State private var countdown: Int?
    11	    @State private var countdownTask: Task<Void, Never>?
    12	    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    13	    /// Where the question card rests, as a distance down from the top of its slot. Not
    14	    /// persisted: RootView gives each session a fresh RecorderView, so every session starts
    15	    /// with the card at the top.
    16	    @State private var questionRestOffset: CGFloat = 0
    17	    @State private var dragTranslation: CGFloat = 0
    18	    @State private var questionSlotHeight: CGFloat = 0
    19	    @State private var questionCardHeight: CGFloat = 0
    20	    @State private var questionDrops = 0          // haptic trigger: one tick per deliberate move
    21	
    22	    private var store: SessionStore { session.store }
    23	
    24	    private var presentation: RecorderPresentation {
    25	        RecorderPresentation.make(
    26	            state: store.state,
    27	            availability: store.captureAvailability,
    28	            hasAudioInput: store.hasAudioInput,
    29	            elapsed: store.elapsedInSegment,
    30	            countdown: countdown
    31	        )
    32	    }
    33	
    34	    var body: some View {
    35	        ZStack {
    36	            previewBackdrop
    37	
    38	            VStack(spacing: 16) {
    39	                // The question card sits at the top or just above the controls (the user
    40	                // drags it off the subject's face); the controls never move.
    41	                questionArea
    42	                bannerRow
    43	                controlsRow
    44	                    .padding(.bottom, 24)
    45	            }
    46	            .padding(.horizontal)
    47	
    48	            if presentation.blocking != .none {
    49	                blockingOverlay
    50	            }
    51	
    52	            if let countdownText = presentation.countdownText {
    53	                countdownOverlay(countdownText)
    54	            }
    55	        }
    56	        .sensoryFeedback(.impact(weight: .medium), trigger: presentation.primary) { old, new in
    57	            (old == .pause) != (new == .pause)
    58	        }
    59	        .sensoryFeedback(.selection, trigger: store.state.questionIndex)
    60	        .sensoryFeedback(.selection, trigger: questionDrops)
    61	        .task { store.startTicker() }
    62	        .onDisappear { cancelCountdown() }
    63	        .navigationBarBackButtonHidden(true)
    64	        .toolbar {
    65	            ToolbarItem(placement: .topBarLeading) {
    66	                Button(UICopy.done) {
    67	                    cancelCountdown()
    68	                    Task { await model.endSession() }
    69	                }
    70	                .disabled(!presentation.canLeave)
    71	                .accessibilityLabel(UICopy.done)
    72	                .accessibilityIdentifier("doneButton")
    73	            }
    74	            // Only while recording, so an empty item never leaves a glass bubble behind.
    75	            if presentation.showsRecordingDot {
    76	                ToolbarItem(placement: .topBarTrailing) {
    77	                    recordingIndicator
    78	                }
    79	                .sharedBackgroundVisibility(.hidden)
    80	            }
    81	        }
    82	        .onChange(of: scenePhase) { old, new in
    83	            if new != .active {
    84	                cancelCountdown()
    85	                dragTranslation = 0     // an interrupted drag may never reach onEnded
    86	            }
    87	            if let event = ScenePhaseMapping.event(from: old, to: new) {
    88	                store.send(event)
    89	            }
    90	        }
    91	        .onChange(of: presentation.blocking) { _, new in
    92	            if new != .none { cancelCountdown() }
    93	        }
    94	    }
    95	
    96	    /// The camera feed, or -- demo mode only (the simulator has no camera) -- a soft dark
    97	    /// warm gradient so the recorder screenshot doesn't show a black void.
    98	    #if DEBUG
    99	    @ViewBuilder
   100	    private var previewBackdrop: some View {
   101	        if model.isDemo {
   102	            LinearGradient(
   103	                colors: [
   104	                    DesignTokens.demoBackdropTop,
   105	                    DesignTokens.demoBackdropBottom,
   106	                ],
   107	                startPoint: .top,
   108	                endPoint: .bottom
   109	            )
   110	            .ignoresSafeArea()
   111	        } else {
   112	            CameraPreview(source: session.capture.previewSource)
   113	                .ignoresSafeArea()
   114	        }
   115	    }
   116	    #else
   117	    private var previewBackdrop: some View {
   118	        CameraPreview(source: session.capture.previewSource)
   119	            .ignoresSafeArea()
   120	    }
   121	    #endif
   122	
   123	    // MARK: - Question panel
   124	
   125	    /// The card at its natural height when it fits, so it can sit anywhere in the slot; in a
   126	    /// ScrollView when it doesn't (largest accessibility sizes on a small screen), so it can
   127	    /// never push Record/Next off screen. Only the fitting card takes the drag: inside the
   128	    /// ScrollView a drag would fight scrolling, so there the handle button moves it.
   129	    private var questionArea: some View {
   130	        ViewThatFits(in: .vertical) {
   131	            // The slot fills the space above the controls; the card is pinned to its top and
   132	            // offset down by where the user left it. (Spacers around the area did not work:
   133	            // the area's layout priority took all the free space and the Spacer got 0.)
   134	            questionPanel(movable: true)
   135	                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { questionCardHeight = $0 }
   136	                .offset(y: questionOffset)
   137	                .gesture(questionDrag)
   138	                .frame(maxHeight: .infinity, alignment: .top)
   139	                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { questionSlotHeight = $0 }
   140	                // Keep the resting spot inside the travel, so the next drag starts where the
   141	                // card actually is.
   142	                .onChange(of: questionTravel) { _, _ in
   143	                    questionRestOffset = clampedQuestionOffset(questionRestOffset)
   144	                }
   145	            // A card this tall fills the whole area, so there is nowhere to move it: no handle.
   146	            ScrollView {
   147	                questionPanel(movable: false)
   148	            }
   149	            .scrollBounceBehavior(.basedOnSize)
   150	        }
   151	        .layoutPriority(1)
   152	    }
   153	
   154	    /// How far the card can travel: the slot minus the card. Shrinks when a banner appears or
   155	    /// the next question is longer, and every offset below is clamped to it.
   156	    private var questionTravel: CGFloat { max(0, questionSlotHeight - questionCardHeight) }
   157	
   158	    private func clampedQuestionOffset(_ y: CGFloat) -> CGFloat { min(max(y, 0), questionTravel) }
   159	
   160	    private var questionOffset: CGFloat { clampedQuestionOffset(questionRestOffset + dragTranslation) }
   161	
   162	    /// In the lower half of its travel: the handle offers "to top", otherwise "to bottom".
   163	    private var questionIsLow: Bool { questionTravel > 0 && questionOffset > questionTravel / 2 }
   164	
   165	    /// Follows the finger anywhere in the slot and stays where it is let go.
   166	    private var questionDrag: some Gesture {
   167	        DragGesture(minimumDistance: 8)
   168	            .onChanged { value in
   169	                dragTranslation = value.translation.height
   170	            }
   171	            .onEnded { value in
   172	                questionRestOffset = clampedQuestionOffset(questionRestOffset + value.translation.height)
   173	                dragTranslation = 0
   174	                questionDrops += 1
   175	            }
   176	    }
   177	
   178	    private func toggleQuestionPosition() {
   179	        withAnimation(reduceMotion ? nil : DesignTokens.Motion.morph) {
   180	            questionRestOffset = questionIsLow ? 0 : questionTravel
   181	        }
   182	        questionDrops += 1
   183	    }
   184	
   185	    private var questionHandle: some View {
   186	        Button(action: toggleQuestionPosition) {
   187	            Capsule()
   188	                .fill(.white.opacity(0.6))
   189	                .frame(width: 36, height: 5)
   190	                .frame(maxWidth: .infinity, minHeight: 44)
   191	                .contentShape(Rectangle())
   192	        }
   193	        .buttonStyle(.plain)
   194	        .padding(.vertical, -8)              // 44 pt to touch, 28 pt of card height
   195	        .accessibilitySortPriority(-1)       // VoiceOver reads the question first
   196	        .accessibilityLabel(questionIsLow ? UICopy.moveQuestionToTop : UICopy.moveQuestionToBottom)
   197	        .accessibilityIdentifier("questionHandle")
   198	    }
   199	
   200	    private func questionPanel(movable: Bool) -> some View {
   201	        VStack(alignment: .leading, spacing: 8) {
   202	            if movable { questionHandle }
   203	            Text(UICopy.questionCounter(store.state.questionIndex, store.state.deck.questions.count))
   204	                .font(.footnote)
   205	                .foregroundStyle(.white.opacity(0.85))
   206	            Text(store.currentQuestion.text)
   207	                .font(.largeTitle.bold())
   208	                .fontDesign(DesignTokens.questionFontDesign)
   209	                .foregroundStyle(.white)
   210	            if let next = store.nextQuestionPreview {
   211	                Text(next.text)
   212	                    .font(.callout)
   213	                    .fontDesign(DesignTokens.questionFontDesign)
   214	                    .foregroundStyle(.white.opacity(0.85))
   215	            }
   216	        }
   217	        .frame(maxWidth: .infinity, alignment: .leading)
   218	        .padding()
   219	        // Translucent black backing: white text stays >=7:1 even over a pure-white feed
   220	        // (70% black over white ~ 8.5:1; 60% was only ~ 5.7:1). Secondary lines use opaque-ish white, not .secondary, which
   221	        // is translucent gray and drops below 3:1 over a bright feed.
   222	        .background(DesignTokens.overCameraFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
   223	        .accessibilityElement(children: .contain)
   224	        .accessibilityIdentifier("questionPanel")
   225	    }
   226	
   227	    // MARK: - Recording indicator
   228	
   229	    /// Top right, red, only while the camera is actually writing: the filmer and the subject
   230	    /// can both tell at a glance whether it is on.
   231	    @ViewBuilder
   232	    private var recordingIndicator: some View {
   233	        if presentation.showsRecordingDot, let timerText = presentation.timerText {
   234	            HStack(spacing: 6) {
   235	                Circle()
   236	                    .fill(.white)
   237	                    .frame(width: 8, height: 8)
   238	                Text(UICopy.recordingIndicator)
   239	                    .fontWeight(.semibold)
   240	                Text(timerText)
   241	                    .monospacedDigit()
   242	            }
   243	            .font(.subheadline)
   244	            .foregroundStyle(.white)
   245	            .padding(.horizontal, 10)
   246	            .padding(.vertical, 4)
   247	            .background(DesignTokens.recordingFill, in: Capsule())
   248	            // The nav bar has a fixed height; past AX1 the pill would clip.
   249	            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
   250	            .accessibilityElement(children: .ignore)
   251	            .accessibilityLabel("\(UICopy.recordingIndicator), \(timerText)")
   252	            .accessibilityIdentifier("recordingIndicator")
   253	        }
   254	    }
   255	
   256	    // MARK: - Banner
   257	
   258	    @ViewBuilder
   259	    private var bannerRow: some View {
   260	        switch presentation.banner {
   261	        case .none:
   262	            EmptyView()
   263	        case .readAloud:
   264	            bannerText(UICopy.readAloudBanner)
   265	        case .noAudio:
   266	            bannerText(UICopy.noAudioBanner)
   267	        case let .paused(reason):
   268	            bannerText(UICopy.pausedBanner(reason))
   269	        }
   270	    }
   271	
   272	    private func bannerText(_ text: String) -> some View {
   273	        Text(text)
   274	            .font(.callout)
   275	            // Wrap, never truncate: the read-aloud banner quotes the consent line, and at AX5
   276	            // it was cut to "First, have them..." (review screenshot ax5-03-recorder). Capped
   277	            // at AX2 so the banner can't crowd out the question card.
   278	            .fixedSize(horizontal: false, vertical: true)
   279	            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
   280	            .foregroundStyle(.white)
   281	            .frame(maxWidth: .infinity)
   282	            .padding()
   283	            .background(DesignTokens.overCameraFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
   284	    }
   285	
   286	    // MARK: - Controls
   287	
   288	    @ViewBuilder
   289	    private var controlsRow: some View {
   290	        if dynamicTypeSize.isAccessibilitySize {
   291	            // Side by side, no spacer column: stacking cost the question card most of its
   292	            // height at AX5 (review screenshot ax5-03-recorder). Control labels cap at AX2;
   293	            // the question above still scales fully.
   294	            HStack(spacing: DesignTokens.Spacing.l) {
   295	                primaryButton
   296	                advanceButton
   297	            }
   298	            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
   299	        } else {
   300	            HStack(spacing: DesignTokens.Spacing.l) {
   301	                Color.clear
   302	                    .frame(maxWidth: .infinity)
   303	                primaryButton
   304	                    .frame(maxWidth: .infinity)
   305	                advanceButton
   306	                    .frame(maxWidth: .infinity)
   307	            }
   308	        }
   309	    }
   310	
   311	    private var primaryButton: some View {
   312	        let p = presentation.primary
   313	        return RecordButton(primary: p, label: primaryLabel(p)) {
   314	            switch p {
   315	            case .record, .resume:
   316	                startCountdown()
   317	            case .cancelCountdown:
   318	                cancelCountdown()
   319	            case .pause:
   320	                store.send(.tapPause)
   321	            case .saving, .unavailable:
   322	                break   // disabled
   323	            }
   324	        }
   325	    }
   326	
   327	    private func primaryLabel(_ p: RecorderPresentation.Primary) -> String {
   328	        switch p {
   329	        case .record: UICopy.record
   330	        case .pause: UICopy.pause
   331	        case .resume: UICopy.resume
   332	        case .saving: UICopy.saving
   333	        case .cancelCountdown: UICopy.cancel
   334	        case .unavailable: UICopy.record   // disabled; behind the blocking overlay
   335	        }
   336	    }
   337	
   338	    private var advanceButton: some View {
   339	        let a = presentation.advance
   340	        return Button {
   341	            switch a {
   342	            case .skip:
   343	                store.send(.tapSkip)
   344	            case .next:
   345	                store.send(.tapNextQuestion)
   346	            case .finish:
   347	                cancelCountdown()
   348	                Task { await model.endSession() }
   349	            case .disabled:
   350	                break
   351	            }
   352	        } label: {
   353	            Text(advanceLabel(a))
   354	                .font(.body.weight(.semibold))
   355	                .foregroundStyle(.white)
   356	                .lineLimit(2)
   357	                .multilineTextAlignment(.center)
   358	                .padding(.horizontal, DesignTokens.Spacing.m)
   359	                .padding(.vertical, DesignTokens.Spacing.s)
   360	                .frame(minHeight: 44)
   361	                .background(DesignTokens.overCameraFill, in: Capsule())
   362	        }
   363	        .buttonStyle(.plain)
   364	        .disabled(a == .disabled)
   365	        .accessibilityLabel(advanceLabel(a))
   366	    }
   367	
   368	    private func advanceLabel(_ a: RecorderPresentation.Advance) -> String {
   369	        switch a {
   370	        case .skip: UICopy.skip
   371	        case .next: UICopy.next
   372	        case .finish: UICopy.finish
   373	        case .disabled: UICopy.next   // disabled; label is irrelevant to display
   374	        }
   375	    }
   376	
   377	    // MARK: - Countdown
   378	
   379	    /// 3-2-1 before record/resume. The store event is chosen from the phase re-READ at
   380	    /// the end of the countdown, never the phase from when it started.
   381	    private func startCountdown() {
   382	        // A second activation before the view re-renders must not orphan a running task
   383	        // that cancelCountdown() could no longer reach.
   384	        guard countdownTask == nil else { return }
   385	        countdown = 3
   386	        countdownTask = Task {
   387	            do {
   388	                while let value = countdown, value > 1 {
   389	                    try await Task.sleep(for: .seconds(1))
   390	                    countdown = value - 1
   391	                }
   392	                try await Task.sleep(for: .seconds(1))
   393	            } catch {
   394	                return   // cancelled: send nothing
   395	            }
   396	            countdown = nil
   397	            countdownTask = nil
   398	            switch store.state.phase {
   399	            case .idle:
   400	                store.send(.tapRecord)
   401	            case .paused:
   402	                store.send(.tapResume)
   403	            case .recording, .finishing:
   404	                break
   405	            }
   406	        }
   407	    }
   408	
   409	    private func cancelCountdown() {
   410	        countdownTask?.cancel()
   411	        countdownTask = nil
   412	        countdown = nil
   413	    }
   414	
   415	    @ViewBuilder
   416	    private func countdownOverlay(_ text: String) -> some View {
   417	        Text(text)
   418	            .font(.largeTitle.bold().monospacedDigit())
   419	            .foregroundStyle(.white)
   420	            .padding(32)
   421	            .background(DesignTokens.overCameraFill, in: Circle())
   422	    }
   423	
   424	    // MARK: - Blocking overlay
   425	
   426	    /// Opaque black, covers preview and controls; the "Done" toolbar button is in the
   427	    /// navigation bar above this and stays usable when `canLeave`.
   428	    @ViewBuilder
   429	    private var blockingOverlay: some View {
   430	        Color.black
   431	            .ignoresSafeArea()
   432	            .overlay {
   433	                switch presentation.blocking {
   434	                case .none:
   435	                    EmptyView()
   436	                case .preparing:
   437	                    VStack(spacing: 16) {
   438	                        ProgressView()
   439	                        Text(UICopy.preparing)
   440	                            .font(.body)
   441	                            .foregroundStyle(.white)
   442	                    }
   443	                case .notAuthorized:
   444	                    VStack(spacing: 16) {
   445	                        Text(UICopy.notAuthorizedTitle)
   446	                            .font(.title2.bold())
   447	                            .foregroundStyle(.white)
   448	                        Text(UICopy.notAuthorizedBody)
   449	                            .font(.body)
   450	                            .foregroundStyle(.white)
   451	                        Button(UICopy.openSettings) {
   452	                            if let url = URL(string: UIApplication.openSettingsURLString) {
   453	                                UIApplication.shared.open(url)
   454	                            }
   455	                        }
   456	                        .font(.title2)
   457	                        .frame(minWidth: 44, minHeight: 44)
   458	                        .accessibilityLabel(UICopy.openSettings)
   459	                    }
   460	                    .padding()
   461	                case .unavailable:
   462	                    VStack(spacing: 16) {
   463	                        Text(UICopy.unavailableTitle)
   464	                            .font(.title2.bold())
   465	                            .foregroundStyle(.white)
   466	                        Text(UICopy.unavailableBody)
   467	                            .font(.body)
   468	                            .foregroundStyle(.white)
   469	                    }
   470	                    .padding()
   471	                }
   472	            }
   473	    }
   474	}

--- storycue/StoryCue/Views/RootView.swift ---
     1	import SwiftUI
     2	
     3	struct RootView: View {
     4	    @Bindable var model: AppModel
     5	
     6	    var body: some View {
     7	        NavigationStack {
     8	            DeckPickerView(model: model)
     9	                .navigationDestination(
    10	                    isPresented: Binding(
    11	                        get: { model.active != nil },
    12	                        set: { _ in }
    13	                    )
    14	                ) {
    15	                    if let active = model.active {
    16	                        RecorderView(session: active, model: model)
    17	                            // A fresh view per session so its preview connects to the new
    18	                            // capture service instead of reusing the previous one's
    19	                            // (black) representable.
    20	                            .id(ObjectIdentifier(active.store))
    21	                    }
    22	                }
    23	                .navigationDestination(item: $model.finishedSessionID) { id in
    24	                    SessionDetailView(sessionID: id, model: model, showsCompletion: true)
    25	                }
    26	        }
    27	    }
    28	}

--- storycue/StoryCue/Views/SessionDetailView.swift ---
     1	import SwiftUI
     2	
     3	/// One recording: its answers in order, Keep/Delete for undecided recovered clips, Export,
     4	/// and Delete recording. Reads the record live: it may be deleted out from under this view.
     5	struct SessionDetailView: View {
     6	    let sessionID: UUID
     7	    let model: AppModel
     8	    /// True when this screen was opened by "Done" right after recording (S2c): shows the
     9	    /// one-line completion header and fires a one-time success haptic.
    10	    var showsCompletion: Bool = false
    11	
    12	    @Environment(\.dismiss) private var dismiss
    13	    @State private var exportModel: ExportModel?
    14	    @State private var showDeleteSessionConfirm = false
    15	    @State private var pendingClipDelete: RecoveredClip?
    16	    @State private var playing: PlayableAnswer?
    17	    @State private var didAppear = false
    18	
    19	    private var library: Library { model.library }
    20	
    21	    var body: some View {
    22	        Group {
    23	            if let record = library.record(id: sessionID) {
    24	                content(record)
    25	            } else {
    26	                Text(UICopy.sessionGone)
    27	                    .font(.body)
    28	                    .padding()
    29	            }
    30	        }
    31	        .navigationTitle(library.record(id: sessionID)?.deckTitle ?? UICopy.libraryTitle)
    32	        .navigationBarTitleDisplayMode(.inline)
    33	        // Only the post-recording screen celebrates; opening a session from Recordings doesn't.
    34	        .onAppear { if showsCompletion { didAppear = true } }
    35	        .sensoryFeedback(.success, trigger: didAppear)
    36	    }
    37	
    38	    private func isShown(_ clip: Clip) -> Bool {
    39	        clip.segments.contains { $0.outcome != .failed(kept: false) }
    40	    }
    41	
    42	    private func content(_ record: SessionRecord) -> some View {
    43	        let isActive = sessionID == library.activeSessionID
    44	        let shownClips = record.clips.filter { isShown($0) }
    45	        return List {
    46	            Section {
    47	                ForEach(shownClips, id: \.questionID) { clip in
    48	                    clipRow(clip, record: record, isActive: isActive)
    49	                }
    50	            } header: {
    51	                if showsCompletion {
    52	                    if record.manifest.count > 0 {
    53	                        VStack(alignment: .leading, spacing: 4) {
    54	                            Text(UICopy.completionTitle(record.manifest.count))
    55	                                .font(.title3.bold())
    56	                            Text(UICopy.completionBody)
    57	                                .font(.callout)
    58	                                .foregroundStyle(.secondary)
    59	                        }
    60	                        .textCase(nil)   // inset-grouped headers uppercase by default
    61	                        .foregroundStyle(.primary)
    62	                    }
    63	                } else {
    64	                    Text(UICopy.sessionSummary(record.startedAt, count: record.manifest.count))
    65	                        .font(.subheadline)
    66	                        .foregroundStyle(.secondary)
    67	                        .textCase(nil)
    68	                }
    69	            }
    70	            Section {
    71	                Button(UICopy.deleteSession, role: .destructive) {
    72	                    showDeleteSessionConfirm = true
    73	                }
    74	                .frame(maxWidth: .infinity, minHeight: 44)
    75	                .disabled(!library.canDelete(sessionID))
    76	            }
    77	        }
    78	        .toolbar {
    79	            ToolbarItem(placement: .topBarTrailing) {
    80	                Button(UICopy.export) {
    81	                    exportModel = ExportModel(
    82	                        sessionID: sessionID,
    83	                        library: library,
    84	                        exporter: model.exporter
    85	                    )
    86	                }
    87	                .disabled(!canExportNow)
    88	            }
    89	        }
    90	        .sheet(
    91	            isPresented: Binding(
    92	                get: { exportModel != nil },
    93	                set: { isPresented in
    94	                    if !isPresented { exportModel = nil }
    95	                }
    96	            )
    97	        ) {
    98	            if let exportModel {
    99	                ExportView(model: exportModel)
   100	            }
   101	        }
   102	        .confirmationDialog(
   103	            UICopy.deleteSessionConfirm,
   104	            isPresented: $showDeleteSessionConfirm,
   105	            titleVisibility: .visible
   106	        ) {
   107	            Button(UICopy.deleteSession, role: .destructive) {
   108	                Task {
   109	                    let deleted = await library.delete(sessionID: sessionID)
   110	                    if deleted { dismiss() }
   111	                }
   112	            }
   113	        }
   114	        .confirmationDialog(
   115	            UICopy.deleteClipConfirm,
   116	            isPresented: Binding(
   117	                get: { pendingClipDelete != nil },
   118	                set: { isPresented in
   119	                    if !isPresented { pendingClipDelete = nil }
   120	                }
   121	            ),
   122	            titleVisibility: .visible,
   123	            presenting: pendingClipDelete
   124	        ) { clip in
   125	            Button(UICopy.deleteClip, role: .destructive) {
   126	                Task { await library.discard(clip) }
   127	            }
   128	        }
   129	        .fullScreenCover(item: $playing) { answer in
   130	            AnswerPlayerView(
   131	                sources: playbackSources(for: record, questionID: answer.questionID, in: model.segmentDirectory),
   132	                caption: record.questionPosition(for: answer.questionID)?.text ?? UICopy.unknownQuestion
   133	            )
   134	        }
   135	    }
   136	
   137	    private var canExportNow: Bool {
   138	        ExportModel(sessionID: sessionID, library: library, exporter: model.exporter).canExport
   139	    }
   140	
   141	    private func clipRow(_ clip: Clip, record: SessionRecord, isActive: Bool) -> some View {
   142	        let position = record.questionPosition(for: clip.questionID)
   143	        let hasKeptFailure = clip.segments.contains { $0.outcome == .failed(kept: true) }
   144	        let undecided = clip.segments.filter { $0.outcome == nil }
   145	        // The camera owns the audio session while its session is active, so a still-open
   146	        // session's rows get no play button. Sources come from the export manifest rules.
   147	        let sources = playbackSources(for: record, questionID: clip.questionID, in: model.segmentDirectory)
   148	        return HStack(alignment: .top, spacing: 12) {
   149	            VStack(alignment: .leading, spacing: 8) {
   150	                if let position {
   151	                    Text(UICopy.questionCounter(position.index, position.count))
   152	                        .font(.callout)
   153	                        .foregroundStyle(.secondary)
   154	                    Text(position.text)
   155	                        .font(.body)
   156	                        .fontDesign(DesignTokens.questionFontDesign)
   157	                } else {
   158	                    Text(UICopy.unknownQuestion)
   159	                        .font(.body)
   160	                }
   161	                if hasKeptFailure {
   162	                    Text(UICopy.mayBeIncomplete)
   163	                        .font(.caption)
   164	                        .foregroundStyle(.secondary)
   165	                }
   166	                if !isActive {
   167	                    ForEach(undecided, id: \.id) { segment in
   168	                        undecidedControls(RecoveredClip(sessionID: sessionID, segment: segment))
   169	                    }
   170	                }
   171	            }
   172	            if !sources.isEmpty && !isActive {
   173	                Button {
   174	                    playing = PlayableAnswer(questionID: clip.questionID)
   175	                } label: {
   176	                    Image(systemName: "play.circle.fill")
   177	                        .font(.title)
   178	                        .frame(minWidth: 44, minHeight: 44)
   179	                }
   180	                .buttonStyle(.borderless)
   181	                .accessibilityLabel(UICopy.playAnswer)
   182	            }
   183	        }
   184	        .padding(.vertical, 4)
   185	    }
   186	
   187	    private func undecidedControls(_ clip: RecoveredClip) -> some View {
   188	        VStack(alignment: .leading, spacing: 8) {
   189	            Text(UICopy.recoveredUndecided)
   190	                .font(.caption)
   191	                .foregroundStyle(.secondary)
   192	            Button(UICopy.keep) {
   193	                Task { await library.keep(clip) }
   194	            }
   195	            .buttonStyle(.bordered)
   196	            .frame(maxWidth: .infinity, minHeight: 44)
   197	            Button(UICopy.deleteClip, role: .destructive) {
   198	                pendingClipDelete = clip
   199	            }
   200	            .buttonStyle(.bordered)
   201	            .frame(maxWidth: .infinity, minHeight: 44)
   202	        }
   203	    }
   204	}

--- storycue/StoryCue/Views/ShareSheet.swift ---
     1	import SwiftUI
     2	import Synchronization
     3	import UIKit
     4	
     5	/// `UIActivityViewController` wrapper. Its `completionWithItemsHandler` is the only hook that
     6	/// says the sheet closed (Save to Files is inside it), so the export's temp directory can be
     7	/// discarded as soon as it does. `onComplete` runs exactly once, on the main actor.
     8	struct ShareSheet: UIViewControllerRepresentable {
     9	    let items: [URL]
    10	    let onComplete: @MainActor @Sendable () -> Void
    11	
    12	    final class Coordinator: Sendable {
    13	        let didComplete = Mutex(false)
    14	
    15	        /// True only for the first caller.
    16	        func claimCompletion() -> Bool {
    17	            didComplete.withLock { done in
    18	                if done { return false }
    19	                done = true
    20	                return true
    21	            }
    22	        }
    23	    }
    24	
    25	    func makeCoordinator() -> Coordinator { Coordinator() }
    26	
    27	    func makeUIViewController(context: Context) -> UIActivityViewController {
    28	        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
    29	        let coordinator = context.coordinator
    30	        let onComplete = self.onComplete
    31	        controller.completionWithItemsHandler = { _, _, _, _ in
    32	            guard coordinator.claimCompletion() else { return }
    33	            Task { @MainActor in onComplete() }
    34	        }
    35	        return controller
    36	    }
    37	
    38	    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    39	}

--- storycue/StoryCue/Views/StorageBanner.swift ---
     1	import SwiftUI
     2	
     3	/// Low-space warning. No button: it informs, it never blocks recording.
     4	struct StorageBanner: View {
     5	    let availableBytes: Int64?
     6	
     7	    var body: some View {
     8	        HStack(alignment: .firstTextBaseline, spacing: 12) {
     9	            Image(systemName: "exclamationmark.triangle.fill")
    10	                .foregroundStyle(.orange)
    11	                .accessibilityHidden(true)
    12	            Text(UICopy.lowSpaceBanner(availableBytes))
    13	                .font(.callout)
    14	        }
    15	        .padding(.vertical, 4)
    16	    }
    17	}

--- storycue/StoryCue/RecorderPresentation.swift ---
     1	import Foundation
     2	
     3	enum RecordGlyph: Equatable {
     4	    case dot, square, spinner, cancel
     5	}
     6	
     7	extension RecorderPresentation.Primary {
     8	    var glyph: RecordGlyph {
     9	        switch self {
    10	        case .record, .resume, .unavailable: .dot
    11	        case .pause: .square
    12	        case .saving: .spinner
    13	        case .cancelCountdown: .cancel
    14	        }
    15	    }
    16	}
    17	
    18	/// Everything the recorder shows, derived from store state in one pure function so the
    19	/// rules are unit-tested without SwiftUI. No SwiftUI/UIKit imports here.
    20	struct RecorderPresentation: Equatable {
    21	    enum Primary: Equatable {
    22	        case record, pause, resume, saving, cancelCountdown, unavailable
    23	    }
    24	
    25	    enum Advance: Equatable {
    26	        case skip, next, finish, disabled
    27	    }
    28	
    29	    enum Blocking: Equatable {
    30	        case none, preparing, notAuthorized, unavailable
    31	    }
    32	
    33	    enum Banner: Equatable {
    34	        case none, readAloud, noAudio, paused(SegmentEndReason)
    35	    }
    36	
    37	    var primary: Primary
    38	    var advance: Advance
    39	    var blocking: Blocking
    40	    var banner: Banner
    41	    var showsRecordingDot: Bool
    42	    var timerText: String?          // TimerFormat.string(elapsed) while .recording, else nil
    43	    var countdownText: String?      // "3" / "2" / "1" while counting down, else nil
    44	    var canLeave: Bool
    45	
    46	    static func make(
    47	        state: SessionState,
    48	        availability: CaptureAvailability,
    49	        hasAudioInput: Bool,
    50	        elapsed: TimeInterval,
    51	        countdown: Int?
    52	    ) -> RecorderPresentation {
    53	        let blocking: Blocking
    54	        switch availability {
    55	        case .unknown: blocking = .preparing
    56	        case .notAuthorized: blocking = .notAuthorized
    57	        case .unavailable: blocking = .unavailable
    58	        case .ready: blocking = .none
    59	        }
    60	
    61	        let primary: Primary
    62	        if blocking != .none {
    63	            primary = .unavailable
    64	        } else if countdown != nil {
    65	            primary = .cancelCountdown
    66	        } else {
    67	            switch state.phase {
    68	            case .idle: primary = .record
    69	            case .recording: primary = .pause
    70	            case .finishing: primary = .saving
    71	            case .paused: primary = .resume
    72	            }
    73	        }
    74	
    75	        let isLastQuestion = state.questionIndex == state.deck.questions.count - 1
    76	        let currentQuestionID = state.deck.questions[state.questionIndex].id
    77	        let currentQuestionHasSegments = state.clips
    78	            .first(where: { $0.questionID == currentQuestionID })
    79	            .map { !$0.segments.isEmpty } ?? false
    80	
    81	        let advance: Advance
    82	        if blocking != .none || countdown != nil {
    83	            advance = .disabled
    84	        } else if case .finishing = state.phase {
    85	            advance = .disabled
    86	        } else if isLastQuestion, !isRecording(state.phase) {
    87	            advance = .finish
    88	        } else if currentQuestionHasSegments {
    89	            advance = .next
    90	        } else {
    91	            advance = .skip
    92	        }
    93	
    94	        let banner: Banner
    95	        if case let .paused(reason) = state.phase, reason != .userPause && reason != .userStop {
    96	            banner = .paused(reason)
    97	        } else if blocking == .none && !hasAudioInput {
    98	            banner = .noAudio
    99	        } else if state.phase == .idle && state.questionIndex == 0 && state.clips.isEmpty {
   100	            banner = .readAloud
   101	        } else {
   102	            banner = .none
   103	        }
   104	
   105	        let showsRecordingDot = isRecording(state.phase)
   106	        let timerText = isRecording(state.phase) ? TimerFormat.string(elapsed) : nil
   107	
   108	        let canLeave: Bool
   109	        switch blocking {
   110	        case .preparing:
   111	            canLeave = false   // a configure is in flight; endSession refuses too
   112	        case .notAuthorized, .unavailable:
   113	            canLeave = true
   114	        case .none:
   115	            switch state.phase {
   116	            case .idle, .paused:
   117	                canLeave = true
   118	            case .recording, .finishing:
   119	                canLeave = false
   120	            }
   121	        }
   122	
   123	        return RecorderPresentation(
   124	            primary: primary,
   125	            advance: advance,
   126	            blocking: blocking,
   127	            banner: banner,
   128	            showsRecordingDot: showsRecordingDot,
   129	            timerText: timerText,
   130	            countdownText: countdown.map(String.init),
   131	            canLeave: canLeave
   132	        )
   133	    }
   134	
   135	    private static func isRecording(_ phase: RecordingPhase) -> Bool {
   136	        if case .recording = phase { return true }
   137	        return false
   138	    }
   139	}
   140	
   141	enum TimerFormat {
   142	    /// Count-up. "0:00", "0:59", "1:00", "9:59", "10:00", "61:05". Never negative
   143	    /// (clamps at 0), never hours. Floors fractional seconds.
   144	    static func string(_ elapsed: TimeInterval) -> String {
   145	        let totalSeconds = Int(max(0, elapsed).rounded(.down))
   146	        let minutes = totalSeconds / 60
   147	        let seconds = totalSeconds % 60
   148	        return "\(minutes):\(String(format: "%02d", seconds))"
   149	    }
   150	}

--- storycue/StoryCue/UICopy.swift ---
     1	import Foundation
     2	
     3	/// Every user-visible string in S2a lives here (a `static let`, or a `static func` for
     4	/// the two parameterised ones), so the S4 copy review and the S6 privacy-policy check
     5	/// have one file to read. No string literal shown to the user outside this file.
     6	enum UICopy {
     7	    static let appTitle = "Tellfolk"
     8	    static let deckPickerTitle = "Choose a deck"
     9	    static func questionCount(_ n: Int) -> String { "\(n) questions" }
    10	    static func deckTeaser(_ deckID: String) -> String {
    11	        switch deckID {
    12	        case "grandparents": "Childhood, first jobs, and the years that shaped them"
    13	        case "parents": "The day you were born, and what parenting taught them"
    14	        case "kids": "Kids interview the grownups: toys, school, old fears"
    15	        case "couples": "How you met, and the life you've built since"
    16	        case "holiday-table": "Pass the phone around the table and take turns"
    17	        default: ""
    18	        }
    19	    }
    20	
    21	    // Consent card (also the permission-priming screen: the system camera/mic prompts
    22	    // appear only after the confirm tap, with this explanation already on screen).
    23	    static let consentTitle = "Before you start"
    24	    static let consentBody = "Everyone on camera needs to agree to be recorded. When you start, have the person you're interviewing read this line aloud:"
    25	    static let readAloudLine = "I understand this is being recorded, and I am ready to begin."
    26	    /// The read-aloud line as the consent card shows it, in curly quotes.
    27	    static var readAloudCallout: String { "\u{201C}\(readAloudLine)\u{201D}" }
    28	    static let privacyNote = "Recordings stay on this phone. Nothing is uploaded."
    29	    static let consentConfirm = "We're ready"
    30	
    31	    static func questionCounter(_ i: Int, _ n: Int) -> String { "Question \(i + 1) of \(n)" }
    32	    static let moveQuestionToBottom = "Move question to bottom"
    33	    static let moveQuestionToTop = "Move question to top"
    34	
    35	    static let record = "Record"
    36	    static let pause = "Pause"
    37	    static let resume = "Resume"
    38	    static let saving = "Saving..."
    39	    static let cancel = "Cancel"
    40	
    41	    static let skip = "Skip"
    42	    static let next = "Next question"
    43	    static let finish = "Finish"
    44	    static let done = "Done"
    45	
    46	    /// Quotes the line itself: by the recorder, nobody remembers it from the consent card.
    47	    static var readAloudBanner: String { "First, have them read this aloud: \(readAloudCallout)" }
    48	    static let recordingIndicator = "Recording"
    49	    static let noAudioBanner = "No microphone. Video will record without sound."
    50	
    51	    static let preparing = "Starting the camera..."
    52	    static let notAuthorizedTitle = "Camera or microphone is off"
    53	    static let notAuthorizedBody = "Turn on Camera and Microphone for Tellfolk in Settings to record."
    54	    static let openSettings = "Open Settings"
    55	    static let unavailableTitle = "Camera unavailable"
    56	    static let unavailableBody = "Tellfolk can't use the camera right now. Close other camera apps and try again."
    57	
    58	    static func pausedBanner(_ reason: SegmentEndReason) -> String {
    59	        switch reason {
    60	        case .segmentCapReached:
    61	            return "Ten minutes on this answer. Keep going?"
    62	        case .audioInterruption:
    63	            return "Paused for a call or other audio."
    64	        case .captureInterruption:
    65	            return "The camera was interrupted."
    66	        case .sceneResignedActive, .sceneBackgrounded:
    67	            return "Paused when Tellfolk left the screen."
    68	        case .thermalShutdown:
    69	            return "Paused so the phone can cool down."
    70	        case .runtimeError, .mediaServicesReset, .outputEndedUnexpectedly:
    71	            return "Recording stopped unexpectedly. What was recorded is kept."
    72	        case .directionChanged, .hingeClosed, .accessoryWithdrawn:
    73	            // Duo reasons -- unreachable in 1.0, but the switch stays exhaustive so a new
    74	            // reason is a compile error here.
    75	            return "Paused when the camera changed."
    76	        case .userPause, .userStop:
    77	            return ""   // never shown
    78	        }
    79	    }
    80	
    81	    // MARK: - S2b: library, recovery, delete, export
    82	
    83	    /// Human-readable file size (`ByteCountFormatter`, `.file` style).
    84	    static func fileSize(_ bytes: Int64) -> String {
    85	        let formatter = ByteCountFormatter()
    86	        formatter.countStyle = .file
    87	        return formatter.string(fromByteCount: bytes)
    88	    }
    89	
    90	    static let unknownQuestion = "A question"
    91	    static let unsortedRecordingsTitle = "Unsorted recordings"
    92	
    93	    static let libraryButton = "Recordings"
    94	    static let libraryTitle = "Recordings"
    95	    static let libraryEmptyTitle = "No recordings yet"
    96	    static let libraryEmptyBody = "Your conversations will show up here."
    97	    static let libraryEmptyAction = "Choose a deck"
    98	    static func clipCount(_ n: Int) -> String { n == 1 ? "1 answer" : "\(n) answers" }
    99	    static func sessionSubtitle(_ date: Date, count: Int) -> String {
   100	        "\(date.formatted(.dateTime.month(.abbreviated).day())) ? \(clipCount(count))"
   101	    }
   102	    static func sessionSummary(_ date: Date, count: Int) -> String {
   103	        "\(date.formatted(date: .long, time: .shortened)) ? \(clipCount(count))"
   104	    }
   105	
   106	    static func storageFooter(used: Int64, available: Int64?) -> String {
   107	        var text = "Recordings use \(fileSize(used))."
   108	        if let available {
   109	            text += " \(fileSize(available)) free on this iPhone."
   110	        }
   111	        return text
   112	    }
   113	
   114	    static func lowSpaceBanner(_ available: Int64?) -> String {
   115	        if let available {
   116	            return "Your iPhone is almost full (\(fileSize(available)) free). Long answers may not fit."
   117	        }
   118	        return "Your iPhone is almost full. Long answers may not fit."
   119	    }
   120	    static let lowSpaceConsentNote = "Your iPhone is low on space. Free some up before a long conversation."
   121	
   122	    static let recoveredHeader = "Recovered clips"
   123	    static let recoveredExplainer = "Tellfolk closed while these were recording. They may end early. Keep them or delete them."
   124	    static let recoveredUndecided = "Recovered after Tellfolk closed. It may end early."
   125	    static let keep = "Keep"
   126	    static let deleteClip = "Delete clip"
   127	    static let deleteClipConfirm = "Delete this clip? This can't be undone."
   128	    static let deleteSession = "Delete recording"
   129	    static let deleteSessionConfirm = "Delete this whole recording? This can't be undone."
   130	    static let sessionGone = "This recording was deleted."
   131	    static let mayBeIncomplete = "Part of this answer may be incomplete."
   132	
   133	    static let export = "Export"
   134	    static let exportTitle = "Export"
   135	    static let exportEachAnswer = "Each answer"
   136	    static let exportOneVideo = "One video"
   137	    static let exportToFiles = "Save or share..."
   138	    static let exportToPhotos = "Save to Photos"
   139	    static func exporting(_ done: Int, _ total: Int) -> String {
   140	        total == 0 ? "Preparing..." : "Exporting \(done) of \(total)..."
   141	    }
   142	    static func exportDone(destination: ExportDestination, count: Int) -> String {
   143	        switch destination {
   144	        case .photos:
   145	            return count == 1 ? "Saved 1 video to Photos." : "Saved \(count) videos to Photos."
   146	        case .files:
   147	            return count == 1 ? "Exported 1 video." : "Exported \(count) videos."
   148	        }
   149	    }
   150	    static func droppedNote(_ n: Int) -> String {
   151	        n == 1 ? "1 part couldn't be read and was left out." : "\(n) parts couldn't be read and were left out."
   152	    }
   153	    static let flaggedNote = "Part of this export may be incomplete."
   154	
   155	    // MARK: - S2c: in-app playback, completion
   156	
   157	    static let playAnswer = "Play answer"
   158	    static let playbackUnavailable = "This answer can't be played. The file may be damaged or missing."
   159	    static func completionTitle(_ n: Int) -> String {
   160	        n == 1 ? "You recorded 1 answer" : "You recorded \(n) answers"
   161	    }
   162	    static let completionBody = "They're saved on this iPhone. Tap play to watch one."
   163	}

--- storycue/StoryCue/AppModel.swift ---
     1	import Foundation
     2	
     3	/// One camera, one session at a time. A new `SessionStore` AND a new capture service per
     4	/// recording session: `AsyncStream` is single-consumer, so a second store can't re-iterate
     5	/// the first service's `events`. The ledger is one instance app-wide (one file, one actor).
     6	@MainActor
     7	@Observable
     8	final class AppModel {
     9	    struct ActiveSession {
    10	        let id: UUID
    11	        let startedAt: Date
    12	        let deck: Deck
    13	        let store: SessionStore
    14	        let capture: any CaptureService
    15	    }
    16	
    17	    private(set) var active: ActiveSession?
    18	    /// The session `endSession` just finished, when finish left a keep-worthy record.
    19	    /// RootView binds this to a `navigationDestination(item:)`; `beginSession` clears it.
    20	    var finishedSessionID: UUID?
    21	    /// The shutdown + finish of the session `endSession` just closed. `beginSession` waits for
    22	    /// it, so the camera is released and the old session stays protected until finish lands.
    23	    @ObservationIgnored private var ending: Task<Void, Never>?
    24	    let ledger: SegmentLedger
    25	    let segmentDirectory: URL
    26	    let library: Library
    27	    let exporter: Exporter
    28	
    29	    private let makeCapture: @MainActor (URL) -> any CaptureService
    30	    private let makeBackground: @MainActor () -> any BackgroundTaskRunner
    31	
    32	    /// attributesOfItem size, nil on error.
    33	    nonisolated static let attributesFileSize: @Sendable (URL) -> Int64? = { url in
    34	        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value
    35	    }
    36	
    37	    /// attributesOfItem as a `FileState`: `.missing` only on a positive "no such file" error,
    38	    /// any other error (or no size attribute) is `.unreadable`.
    39	    nonisolated static let attributesFileState: @Sendable (URL) -> FileState = { url in
    40	        do {
    41	            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    42	            guard let size = (attributes[.size] as? NSNumber)?.int64Value else { return .unreadable }
    43	            return .present(size)
    44	        } catch {
    45	            return AppModel.isNoSuchFile(error as NSError) ? .missing : .unreadable
    46	        }
    47	    }
    48	
    49	    nonisolated private static func isNoSuchFile(_ error: NSError) -> Bool {
    50	        if error.domain == NSCocoaErrorDomain,
    51	           error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError {
    52	            return true
    53	        }
    54	        if error.domain == NSPOSIXErrorDomain, error.code == Int(ENOENT) { return true }
    55	        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
    56	            return underlying.domain == NSPOSIXErrorDomain && underlying.code == Int(ENOENT)
    57	        }
    58	        return false
    59	    }
    60	
    61	    /// The volume's "important usage" available capacity for `url`, nil on error.
    62	    nonisolated static func importantUsageCapacity(at url: URL) -> Int64? {
    63	        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    64	        return values?.volumeAvailableCapacityForImportantUsage
    65	    }
    66	
    67	    init(
    68	        segmentDirectory: URL,
    69	        makeCapture: @escaping @MainActor (URL) -> any CaptureService,
    70	        makeBackground: @escaping @MainActor () -> any BackgroundTaskRunner,
    71	        exporter: Exporter? = nil,
    72	        availableCapacity: @escaping @Sendable () -> Int64? = { nil },
    73	        fileState: @escaping @Sendable (URL) -> FileState = AppModel.attributesFileState
    74	    ) {
    75	        let ledger = SegmentLedger(directory: segmentDirectory)
    76	        let resolvedExporter = exporter ?? Exporter(
    77	            segmentDirectory: segmentDirectory,
    78	            temporaryRoot: FileManager.default.temporaryDirectory,
    79	            stitcher: AVStitcher(),
    80	            photos: PHPhotoLibrarySaver(),
    81	            availableCapacity: { AppModel.importantUsageCapacity(at: FileManager.default.temporaryDirectory) },
    82	            fileSize: AppModel.attributesFileSize
    83	        )
    84	        self.segmentDirectory = segmentDirectory
    85	        self.ledger = ledger
    86	        self.exporter = resolvedExporter
    87	        self.library = Library(
    88	            segmentDirectory: segmentDirectory,
    89	            index: SessionIndex(directory: segmentDirectory),
    90	            ledger: ledger,
    91	            exporter: resolvedExporter,
    92	            availableCapacity: availableCapacity,
    93	            fileState: fileState
    94	        )
    95	        self.makeCapture = makeCapture
    96	        self.makeBackground = makeBackground
    97	    }
    98	
    99	    #if DEBUG
   100	    /// Part B demo launch mode (`-StoryCueDemo`, used only by ScreenshotTests): swaps the
   101	    /// camera preview for a warm gradient (RecorderView) and pre-seeds the library.
   102	    var isDemo = false
   103	
   104	    /// Demo wiring for the App Store screenshots: a temp segment directory, a
   105	    /// `MockCaptureService` (default stubs are already authorized and report audio input),
   106	    /// and two finished library records whose segment files are a few junk bytes written
   107	    /// first (export is never exercised in demo mode). `seedForDemo` sets `isLoaded`, so
   108	    /// the root `.task`'s `load()` no-ops and the seed is never re-read from disk.
   109	    static func demo() -> AppModel {
   110	        let segmentDirectory = FileManager.default.temporaryDirectory
   111	            .appendingPathComponent("StoryCueDemoSegments", isDirectory: true)
   112	        try? FileManager.default.createDirectory(at: segmentDirectory, withIntermediateDirectories: true)
   113	
   114	        let model = AppModel(
   115	            segmentDirectory: segmentDirectory,
   116	            makeCapture: { _ in MockCaptureService() },
   117	            makeBackground: { UIKitBackgroundTaskRunner() },
   118	            // The seed files are a few junk bytes; report a plausible clip size (only for files
   119	            // that exist, so delete's "is it gone" check still works) and free space, so the
   120	            // Recordings storage footer in the screenshot reads like a real phone.
   121	            availableCapacity: { 96_000_000_000 },
   122	            fileState: { url in
   123	                let state = AppModel.attributesFileState(url)
   124	                return state.size == nil ? state : .present(46_000_000)
   125	            }
   126	        )
   127	
   128	        // Fixed recent dates at local noon so the Recordings list reads like a real week.
   129	        let calendar = Calendar.current
   130	        let grandparentsDay = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 12))
   131	            ?? Date()
   132	        let holidayTableDay = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12))
   133	            ?? Date()
   134	
   135	        var records: [SessionRecord] = []
   136	        if let grandparents = Deck.v1Decks.first(where: { $0.id == "grandparents" }) {
   137	            records.append(makeDemoRecord(deck: grandparents, clipCount: 3, startedAt: grandparentsDay, in: segmentDirectory))
   138	        }
   139	        if let holidayTable = Deck.v1Decks.first(where: { $0.id == "holiday-table" }) {
   140	            records.append(makeDemoRecord(deck: holidayTable, clipCount: 5, startedAt: holidayTableDay, in: segmentDirectory))
   141	        }
   142	        model.library.seedForDemo(records)
   143	        model.isDemo = true
   144	        return model
   145	    }
   146	
   147	    /// One finished record: `clipCount` clips, one `.saved` segment each, using the deck's
   148	    /// real first question IDs. Segment URLs come only from `SegmentFiles` and each file
   149	    /// gets a few junk bytes before the record is built.
   150	    private static func makeDemoRecord(deck: Deck, clipCount: Int, startedAt: Date, in directory: URL) -> SessionRecord {
   151	        var clips: [Clip] = []
   152	        for index in 0..<clipCount {
   153	            let questionID = deck.questions[index].id
   154	            let segmentID = UUID()
   155	            let url = SegmentFiles.url(for: segmentID, in: directory)
   156	            try? Data([0x00, 0x01, 0x02, 0x03, 0x04]).write(to: url)
   157	            clips.append(Clip(
   158	                questionID: questionID,
   159	                segments: [Segment(
   160	                    id: segmentID,
   161	                    questionID: questionID,
   162	                    startedAt: startedAt.addingTimeInterval(TimeInterval(index * 60)),
   163	                    endReason: .userStop,
   164	                    outcome: .saved(url: url)
   165	                )]
   166	            ))
   167	        }
   168	        return SessionRecord(
   169	            id: UUID(),
   170	            deckID: deck.id,
   171	            deckTitle: deck.title,
   172	            startedAt: startedAt,
   173	            clips: clips,
   174	            isFinished: true
   175	        )
   176	    }
   177	    #endif
   178	
   179	    /// Production wiring. Constructs NO capture service (the S1 nil-safety rule -- nothing
   180	    /// here touches a camera): the factories run inside `beginSession`, after the consent
   181	    /// tap.
   182	    static func production() -> AppModel {
   183	        let segmentDirectory = (try? SegmentFiles.defaultDirectory())
   184	            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
   185	                .appendingPathComponent("Segments", isDirectory: true)
   186	        return AppModel(
   187	            segmentDirectory: segmentDirectory,
   188	            makeCapture: { AVCaptureService(segmentDirectory: $0) },
   189	            makeBackground: { UIKitBackgroundTaskRunner() },
   190	            availableCapacity: { AppModel.importantUsageCapacity(at: segmentDirectory) }
   191	        )
   192	    }
   193	
   194	    private(set) var isPreparing = false
   195	
   196	    /// Creates capture + store for `deck`, sets `active`, calls store.start(), sets
   197	    /// isPreparing = true, awaits store.prepareCapture(), sets isPreparing = false.
   198	    /// If a session is already active, does nothing. prepareCapture never throws
   199	    /// (S1 ?5 rule 5): failures land in store.captureAvailability, which the recorder shows
   200	    /// as a blocking state -- so `active` stays set on failure, by design, and the user
   201	    /// leaves with "Done".
   202	    func beginSession(deck: Deck) async {
   203	        guard active == nil else { return }
   204	        if let ending {
   205	            await ending.value
   206	            guard active == nil else { return }
   207	        }
   208	        finishedSessionID = nil
   209	        let id = UUID()
   210	        let startedAt = Date()
   211	        let capture = makeCapture(segmentDirectory)
   212	        let store = SessionStore(
   213	            deck: deck,
   214	            capture: capture,
   215	            ledger: ledger,
   216	            segmentDirectory: segmentDirectory,
   217	            background: makeBackground(),
   218	            archive: { [weak library = self.library] clips in
   219	                library?.checkpoint(sessionID: id, deck: deck, startedAt: startedAt, clips: clips)
   220	            }
   221	        )
   222	        active = ActiveSession(id: id, startedAt: startedAt, deck: deck, store: store, capture: capture)
   223	        library.activeSessionID = id
   224	        store.start()
   225	        isPreparing = true
   226	        await store.prepareCapture()
   227	        isPreparing = false
   228	    }
   229	
   230	    /// Refuses (returns false, changes nothing) while isPreparing, or while the active
   231	    /// store's phase is .recording or .finishing. The check, store.stop() and
   232	    /// `active = nil` all happen synchronously on the main actor BEFORE the first await,
   233	    /// so no event can slip between them (AppModel and SessionStore are both @MainActor);
   234	    /// then the camera is released (`capture.shutdown()`) and the session is handed to the
   235	    /// library. The clips captured here are final: this only proceeds from .idle/.paused,
   236	    /// which the reducer reaches only after fileOutputFinished set the outcome; a still-queued
   237	    /// .persistLedger only writes the ledger. No active session -> true.
   238	    @discardableResult
   239	    func endSession() async -> Bool {
   240	        guard let active else { return true }
   241	        guard !isPreparing else { return false }
   242	        switch active.store.state.phase {
   243	        case .recording, .finishing:
   244	            return false
   245	        case .idle, .paused:
   246	            break
   247	        }
   248	        let capture = active.capture
   249	        let id = active.id
   250	        let deck = active.deck
   251	        let startedAt = active.startedAt
   252	        let clips = active.store.state.clips
   253	        active.store.stop()
   254	        self.active = nil
   255	        // activeSessionID is cleared only after finish: while the camera shuts down the
   256	        // session must stay protected, or a delete/discard in that window is undone by
   257	        // finish's stale clips. beginSession waits on `ending`, so nothing replaces the ID.
   258	        let library = self.library
   259	        let previous = ending
   260	        let task = Task { @MainActor in
   261	            await previous?.value
   262	            await capture.shutdown()
   263	            await library.finish(sessionID: id, deck: deck, startedAt: startedAt, clips: clips)
   264	            if library.activeSessionID == id { library.activeSessionID = nil }
   265	        }
   266	        ending = task
   267	        await task.value
   268	        // Open the finished session only if nothing replaced it meanwhile: beginSession
   269	        // also waits on `ending`, and its continuation may resume first and set `active`.
   270	        if self.active == nil, library.record(id: id) != nil {   // self.: `active` here is the unwrapped local
   271	            finishedSessionID = id
   272	        }
   273	        return true
   274	    }
   275	}

--- storycue/StoryCue/ExportModel.swift ---
     1	import Foundation
     2	import Observation
     3	
     4	/// Drives one export screen over S3's `Exporter` (S2b spec ?5). The export path never
     5	/// deletes a segment; this model only ever discards the temp directory of its own result.
     6	@MainActor
     7	@Observable
     8	final class ExportModel {
     9	    enum Phase: Equatable {
    10	        case choosing
    11	        case running(done: Int, total: Int)
    12	        case sharing(ExportResult)          // share sheet up; files in result.files
    13	        case finished(String)               // summary copy
    14	        case failed(String)                 // ExportFailure.userMessage
    15	    }
    16	
    17	    private(set) var phase: Phase = .choosing
    18	    var unit: ExportUnit = .perClip
    19	    let sessionID: UUID
    20	
    21	    private let library: Library
    22	    private let exporter: Exporter
    23	    private var task: Task<Void, Never>?
    24	
    25	    init(sessionID: UUID, library: Library, exporter: Exporter) {
    26	        self.sessionID = sessionID
    27	        self.library = library
    28	        self.exporter = exporter
    29	    }
    30	
    31	    /// Record exists, deck resolves, the manifest is non-empty, and the library allows it.
    32	    var canExport: Bool {
    33	        guard let record = library.record(id: sessionID),
    34	              record.deck != nil,
    35	              !record.manifest.isEmpty
    36	        else { return false }
    37	        return library.canStartExport(sessionID)
    38	    }
    39	
    40	    func start(_ destination: ExportDestination) {
    41	        guard canExport else { return }
    42	        switch phase {
    43	        case .choosing, .finished, .failed:
    44	            break
    45	        case .running, .sharing:
    46	            return
    47	        }
    48	        guard let record = library.record(id: sessionID), let deck = record.deck else { return }
    49	
    50	        library.beginExport(sessionID)
    51	        phase = .running(done: 0, total: 0)
    52	
    53	        let exporter = self.exporter
    54	        let unit = self.unit
    55	        let entries = record.manifest
    56	        let sessionDate = record.startedAt
    57	        // Hops can reorder; applyProgress keeps the max and ignores anything outside .running.
    58	        let progress: @Sendable (Int, Int) -> Void = { [weak self] done, total in
    59	            Task { @MainActor in
    60	                guard let self else { return }
    61	                self.applyProgress(done: done, total: total)
    62	            }
    63	        }
    64	        task = Task {
    65	            do {
    66	                let result = try await exporter.export(
    67	                    entries: entries,
    68	                    deck: deck,
    69	                    sessionDate: sessionDate,
    70	                    unit: unit,
    71	                    destination: destination,
    72	                    progress: progress
    73	                )
    74	                self.complete(result, destination: destination)
    75	            } catch {
    76	                self.fail(ExportFailure.from(error))
    77	            }
    78	        }
    79	    }
    80	
    81	    func cancel() {
    82	        task?.cancel()
    83	    }
    84	
    85	    /// Called when the share sheet closes (or the export sheet goes away while sharing).
    86	    /// A no-op unless the phase is `.sharing`, so two callers can't double-discard.
    87	    func shareDismissed() async {
    88	        guard case let .sharing(result) = phase else { return }
    89	        phase = .finished(summary(for: result, destination: .files))
    90	        library.endExport(sessionID)
    91	        await exporter.discard(result)
    92	    }
    93	
    94	    private func applyProgress(done: Int, total: Int) {
    95	        guard case let .running(seen, _) = phase else { return }
    96	        phase = .running(done: max(seen, done), total: total)
    97	    }
    98	
    99	    private func complete(_ result: ExportResult, destination: ExportDestination) {
   100	        task = nil
   101	        switch destination {
   102	        case .files:
   103	            // endExport waits for shareDismissed.
   104	            phase = .sharing(result)
   105	        case .photos:
   106	            phase = .finished(summary(for: result, destination: .photos))
   107	            library.endExport(sessionID)
   108	        }
   109	    }
   110	
   111	    private func fail(_ failure: ExportFailure) {
   112	        task = nil
   113	        phase = .failed(failure.userMessage)
   114	        library.endExport(sessionID)
   115	    }
   116	
   117	    private func summary(for result: ExportResult, destination: ExportDestination) -> String {
   118	        let count = destination == .photos ? result.savedToPhotosCount : result.files.count
   119	        var text = UICopy.exportDone(destination: destination, count: count)
   120	        if !result.dropped.isEmpty {
   121	            text += " " + UICopy.droppedNote(result.dropped.count)
   122	        }
   123	        if !result.flaggedSegmentIDs.isEmpty {
   124	            text += " " + UICopy.flaggedNote
   125	        }
   126	        return text
   127	    }
   128	}

--- storycue/StoryCueUITests/ScreenshotTests.swift ---
     1	import XCTest
     2	
     3	/// App Store screenshots (6.9" set). Launches the app in demo mode (`-StoryCueDemo`):
     4	/// a mock capture service pre-authorized and ready, so no system permission alert can
     5	/// appear and no interruption monitor is needed. Each screenshot is attached with a
     6	/// fixed name; CI renames the exported attachments by these names.
     7	@MainActor
     8	final class ScreenshotTests: XCTestCase {
     9	
    10	    func testCaptureAppStoreScreenshots() {
    11	        let app = XCUIApplication()
    12	        app.launchArguments = ["-StoryCueDemo"]
    13	        app.launch()
    14	
    15	        // 01-decks: the deck picker.
    16	        let grandparentsDeck = app.descendants(matching: .any)["deck.grandparents"].firstMatch
    17	        guard waitForScreen(grandparentsDeck, named: "01-decks (deck picker)") else { return }
    18	        attachScreenshot(of: app, named: "01-decks")
    19	
    20	        // 02-consent: the Grandparents consent card.
    21	        grandparentsDeck.tap()
    22	        let consentConfirm = app.buttons["consentConfirm"].firstMatch
    23	        guard waitForScreen(consentConfirm, named: "02-consent (Grandparents consent)") else { return }
    24	        attachScreenshot(of: app, named: "02-consent")
    25	
    26	        // 03-recorder: after "We're ready", idle on question 1. The Record button only
    27	        // becomes enabled once the (mock) camera reports ready.
    28	        consentConfirm.tap()
    29	        let recordButton = app.buttons["recordButton"].firstMatch
    30	        guard waitForScreen(recordButton, named: "03-recorder (recorder, question 1)") else { return }
    31	        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: recordButton)
    32	        wait(for: [ready], timeout: 10)
    33	        attachScreenshot(of: app, named: "03-recorder")
    34	
    35	        // 04-library: Recordings, through the deck picker's libraryButton. Done lands on the
    36	        // consent card or straight on the deck picker (the recorder is a root-level
    37	        // destination; CI run 37083268083 never showed the consent card), so accept either
    38	        // and go back once more only from the consent card.
    39	        app.buttons["doneButton"].firstMatch.tap()
    40	        let libraryButton = app.buttons["libraryButton"].firstMatch
    41	        // A main-actor poll, not an NSPredicate block: the elements are main-actor isolated.
    42	        // Each `exists` is a round trip to the app, so the loop needs no sleep.
    43	        let deadline = Date().addingTimeInterval(10)
    44	        while !libraryButton.exists && !consentConfirm.exists && Date() < deadline {}
    45	        guard libraryButton.exists || consentConfirm.exists else {
    46	            XCTFail("Screen 04-library (deck picker or consent after Done) did not appear within 10 seconds")
    47	            return
    48	        }
    49	        if !libraryButton.exists {
    50	            app.navigationBars.buttons.element(boundBy: 0).tap()
    51	        }
    52	        guard waitForScreen(libraryButton, named: "04-library (deck picker toolbar)") else { return }
    53	        libraryButton.tap()
    54	        let grandparentsSession = app.descendants(matching: .any)["session.grandparents"].firstMatch
    55	        guard waitForScreen(grandparentsSession, named: "04-library (Recordings)") else { return }
    56	        attachScreenshot(of: app, named: "04-library")
    57	
    58	        // 05-session: the Grandparents session detail (its inline title is the deck title).
    59	        grandparentsSession.tap()
    60	        let sessionDetail = app.navigationBars["Grandparents"].firstMatch
    61	        guard waitForScreen(sessionDetail, named: "05-session (Grandparents detail)") else { return }
    62	        attachScreenshot(of: app, named: "05-session")
    63	    }
    64	
    65	    func testCaptureDarkScreenshots() {
    66	        let app = XCUIApplication()
    67	        app.launchArguments = ["-StoryCueDemo", "-StoryCueDark"]
    68	        app.launch()
    69	
    70	        let grandparentsDeck = app.descendants(matching: .any)["deck.grandparents"].firstMatch
    71	        guard waitForScreen(grandparentsDeck, named: "dark-01-decks (deck picker)") else { return }
    72	        attachScreenshot(of: app, named: "dark-01-decks")
    73	
    74	        grandparentsDeck.tap()
    75	        let consentConfirm = app.buttons["consentConfirm"].firstMatch
    76	        guard waitForScreen(consentConfirm, named: "dark-02-consent (Grandparents consent)") else { return }
    77	        attachScreenshot(of: app, named: "dark-02-consent")
    78	
    79	        consentConfirm.tap()
    80	        let recordButton = app.buttons["recordButton"].firstMatch
    81	        guard waitForScreen(recordButton, named: "dark-03-recorder (recorder, question 1)") else { return }
    82	        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: recordButton)
    83	        wait(for: [ready], timeout: 10)
    84	        attachScreenshot(of: app, named: "dark-03-recorder")
    85	
    86	        // Drag the question card off the subject's face: it follows the finger and stays where
    87	        // it is let go. Dragging far past the controls parks it at the bottom of its travel.
    88	        let questionPanel = app.descendants(matching: .any)["questionPanel"].firstMatch
    89	        guard waitForScreen(questionPanel, named: "dark-04-question-bottom (question card)") else { return }
    90	        let panelTopBefore = questionPanel.frame.minY
    91	        let grab = questionPanel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
    92	        grab.press(forDuration: 0.2, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
    93	        let panelTopBottom = questionPanel.frame.minY
    94	        XCTAssertGreaterThan(panelTopBottom, panelTopBefore + 100, "question card did not move down")
    95	
    96	        // Free positioning: a short drag up leaves it between the two ends, not snapped.
    97	        let regrab = questionPanel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
    98	        regrab.press(forDuration: 0.2, thenDragTo: regrab.withOffset(CGVector(dx: 0, dy: -80)))
    99	        let panelTopMiddle = questionPanel.frame.minY
   100	        XCTAssertLessThan(panelTopMiddle, panelTopBottom - 40, "question card did not follow the drag up")
   101	        XCTAssertGreaterThan(panelTopMiddle, panelTopBefore + 40, "question card snapped to the top")
   102	
   103	        // Park it at the bottom again for the review shot.
   104	        let last = questionPanel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
   105	        last.press(forDuration: 0.2, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
   106	        attachScreenshot(of: app, named: "dark-04-question-bottom")
   107	    }
   108	
   109	    func testCaptureAX5Screenshots() {
   110	        let app = XCUIApplication()
   111	        app.launchArguments = ["-StoryCueDemo", "-StoryCueAX5"]
   112	        app.launch()
   113	
   114	        let grandparentsDeck = app.descendants(matching: .any)["deck.grandparents"].firstMatch
   115	        guard waitForScreen(grandparentsDeck, named: "ax5-01-decks (deck picker)") else { return }
   116	        attachScreenshot(of: app, named: "ax5-01-decks")
   117	
   118	        grandparentsDeck.tap()
   119	        let consentConfirm = app.buttons["consentConfirm"].firstMatch
   120	        guard waitForScreen(consentConfirm, named: "ax5-02-consent (Grandparents consent)") else { return }
   121	        attachScreenshot(of: app, named: "ax5-02-consent")
   122	
   123	        consentConfirm.tap()
   124	        let recordButton = app.buttons["recordButton"].firstMatch
   125	        guard waitForScreen(recordButton, named: "ax5-03-recorder (recorder, question 1)") else { return }
   126	        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: recordButton)
   127	        wait(for: [ready], timeout: 10)
   128	        attachScreenshot(of: app, named: "ax5-03-recorder")
   129	
   130	        // At AX5 the card usually fills the area and scrolls, so it has no handle. When it
   131	        // does fit, the handle button moves it.
   132	        let handle = app.buttons["questionHandle"].firstMatch
   133	        if handle.waitForExistence(timeout: 2) {
   134	            handle.tap()
   135	            attachScreenshot(of: app, named: "ax5-04-question-bottom")
   136	        }
   137	    }
   138	
   139	    /// Waits up to 10 s for the screen's anchor element and fails naming the screen.
   140	    private func waitForScreen(_ element: XCUIElement, named screen: String) -> Bool {
   141	        guard element.waitForExistence(timeout: 10) else {
   142	            XCTFail("Screen \(screen) did not appear within 10 seconds")
   143	            return false
   144	        }
   145	        return true
   146	    }
   147	
   148	    private func attachScreenshot(of app: XCUIApplication, named name: String) {
   149	        let attachment = XCTAttachment(screenshot: app.screenshot())
   150	        attachment.name = name
   151	        attachment.lifetime = .keepAlways
   152	        add(attachment)
   153	    }
   154	}

=== VETERAN EXCERPTS ===

--- wilderness/src/services/nativeHaptics.ts ---
     1	/**
     2	 * Haptic feedback with a native-iOS path and a web fallback.
     3	 *
     4	 * `navigator.vibrate` is a no-op in iOS WKWebView (where the packaged app runs),
     5	 * so on Tauri/iOS we call a native plugin command backed by
     6	 * `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator`. Everywhere
     7	 * else (web PWA, Android) we fall back to `navigator.vibrate`. Both paths are
     8	 * best-effort and never throw - haptics are an enhancement, not a dependency.
     9	 *
    10	 * Native side: see `docs/NATIVE_PLUGINS.md` (plugin name `native`, command `haptic`).
    11	 */
    12	import { invoke } from '@tauri-apps/api/core';
    13	
    14	export type HapticStyle = 'light' | 'medium' | 'heavy' | 'success' | 'warning' | 'error' | 'alarm';
    15	
    16	function isTauri(): boolean {
    17	  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
    18	}
    19	
    20	/** Web-vibration fallback pattern (ms) per semantic style. */
    21	const WEB_FALLBACK: Record<HapticStyle, number | number[]> = {
    22	  light: 20,
    23	  medium: 40,
    24	  heavy: 60,
    25	  success: [40, 60, 40],
    26	  warning: [60, 40, 60],
    27	  error: [80, 40, 80, 40, 80],
    28	  // Sustained check-in alarm - preserves the original Android buzz pattern.
    29	  alarm: [300, 200, 300, 200, 300, 200, 300, 200, 300],
    30	};
    31	
    32	/** Trigger a one-shot haptic. Resolves once dispatched; never rejects. */
    33	export async function haptic(style: HapticStyle = 'medium'): Promise<void> {
    34	  if (isTauri()) {
    35	    try {
    36	      await invoke('plugin:native|haptic', { style });
    37	      return;
    38	    } catch {
    39	      // Native unavailable (e.g. plugin not built) - fall through to web.
    40	    }
    41	  }
    42	  try {
    43	    navigator.vibrate?.(WEB_FALLBACK[style]);
    44	  } catch {
    45	    /* haptics are optional */
    46	  }
    47	}
    48	
    49	/** Cancel any ongoing web vibration pattern (no native equivalent needed). */
    50	export function stopHaptic(): void {
    51	  try {
    52	    navigator.vibrate?.(0);
    53	  } catch {
    54	    /* no-op */
    55	  }
    56	}

--- wilderness/src/components/breathing/BreathingExercise.tsx ---
     1	import React, { useEffect, useRef, useState, useCallback } from 'react';
     2	import { haptic } from '../../services/nativeHaptics';
     3	import { RotateCcw } from 'lucide-react';
     4	import type { BreathingPattern } from '../../calculators/PanicMode.calc';
     5	import { applyVoice } from '../../services/voice';
     6	import { Icon } from '../ui/Icon';
     7	
     8	interface BreathingExerciseProps {
     9	  pattern: BreathingPattern;
    10	  audioCues: boolean;
    11	  onComplete?: () => void;
    12	}
    13	
    14	/**
    15	 * Self-contained breathing driver. Walks a pattern's steps with variable
    16	 * per-step durations (so 4-7-8 works as well as 4-4-4-4), announces each
    17	 * phase via Web Speech API when audioCues is enabled, and lightly vibrates
    18	 * on every phase change (no-op in iOS WKWebView; still helpful on Android).
    19	 *
    20	 * Restart the exercise by remounting the component (use a React `key`).
    21	 */
    22	export function BreathingExercise({
    23	  pattern,
    24	  audioCues,
    25	  onComplete,
    26	}: BreathingExerciseProps) {
    27	  const [phaseIndex, setPhaseIndex] = useState(0);
    28	  const [cycleCount, setCycleCount] = useState(0);
    29	  const [completed, setCompleted] = useState(false);
    30	  const [resetNonce, setResetNonce] = useState(0);
    31	  const timeoutRef = useRef<number | null>(null);
    32	
    33	  const speechSupported =
    34	    typeof window !== 'undefined' && 'speechSynthesis' in window;
    35	
    36	  const currentStep = pattern.steps[phaseIndex] ?? pattern.steps[0];
    37	
    38	  const announce = useCallback(
    39	    (text: string) => {
    40	      if (!audioCues || !speechSupported) return;
    41	      try {
    42	        window.speechSynthesis.cancel();
    43	        const utterance = new SpeechSynthesisUtterance(text);
    44	        utterance.rate = 0.75;
    45	        utterance.pitch = 0.95;
    46	        applyVoice(utterance);
    47	        window.speechSynthesis.speak(utterance);
    48	      } catch {
    49	        /* speech errors are non-fatal */
    50	      }
    51	    },
    52	    [audioCues, speechSupported],
    53	  );
    54	
    55	  // Drive the phase progression.
    56	  useEffect(() => {
    57	    if (completed) return;
    58	
    59	    // Fire vibration + audio cue for the current phase.
    60	    void haptic('medium');
    61	    announce(currentStep.label);
    62	
    63	    timeoutRef.current = window.setTimeout(() => {
    64	      const nextIndex = phaseIndex + 1;
    65	      if (nextIndex >= pattern.steps.length) {
    66	        const nextCycle = cycleCount + 1;
    67	        if (nextCycle >= pattern.totalCycles) {
    68	          setCompleted(true);
    69	          onComplete?.();
    70	          return;
    71	        }
    72	        setCycleCount(nextCycle);
    73	        setPhaseIndex(0);
    74	      } else {
    75	        setPhaseIndex(nextIndex);
    76	      }
    77	    }, currentStep.durationMs);
    78	
    79	    return () => {
    80	      if (timeoutRef.current !== null) {
    81	        window.clearTimeout(timeoutRef.current);
    82	        timeoutRef.current = null;
    83	      }
    84	    };
    85	    // `resetNonce` intentionally included so a manual reset re-triggers the effect.
    86	  }, [phaseIndex, cycleCount, completed, currentStep, pattern, onComplete, announce, resetNonce]);
    87	
    88	  // Cancel any speech when the component unmounts.
    89	  useEffect(() => {
    90	    return () => {
    91	      if (speechSupported) {
    92	        try {
    93	          window.speechSynthesis.cancel();
    94	        } catch {
    95	          /* ignore */
    96	        }
    97	      }
    98	    };
    99	  }, [speechSupported]);
   100	
   101	  const handleReset = () => {
   102	    if (timeoutRef.current !== null) {
   103	      window.clearTimeout(timeoutRef.current);
   104	      timeoutRef.current = null;
   105	    }
   106	    if (speechSupported) {
   107	      try {
   108	        window.speechSynthesis.cancel();
   109	      } catch {
   110	        /* ignore */
   111	      }
   112	    }
   113	    setPhaseIndex(0);
   114	    setCycleCount(0);
   115	    setCompleted(false);
   116	    setResetNonce((n) => n + 1);
   117	  };
   118	
   119	  const transitionSeconds = (currentStep.durationMs / 1000).toFixed(2);
   120	
   121	  return (
   122	    <div
   123	      className="flex flex-col items-center gap-6 py-4"
   124	      data-testid="breathing-exercise"
   125	      data-pattern-id={pattern.id}
   126	    >
   127	      {completed ? (
   128	        <div className="flex flex-col items-center gap-3 py-8 text-center">
   129	          <p className="text-brand-text-primary text-3xl font-semibold">
   130	            You&apos;re ready.
   131	          </p>
   132	          <p className="text-brand-text-secondary text-lg">
   133	            Think clearly. Make a plan.
   134	          </p>
   135	          <button
   136	            type="button"
   137	            onClick={handleReset}
   138	            className="mt-4 flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-accent text-brand-on-accent font-bold text-base uppercase tracking-wide touch-target-critical active:scale-95 transition-transform"
   139	          >
   140	            <Icon icon={RotateCcw} size="md" /> Start Over
   141	          </button>
   142	        </div>
   143	      ) : (
   144	        <>
   145	          <div
   146	            aria-hidden="true"
   147	            data-testid="breathing-circle"
   148	            style={{
   149	              transform: `scale(${currentStep.scale})`,
   150	              transition: `transform ${transitionSeconds}s ease-in-out`,
   151	            }}
   152	            className="w-52 h-52 rounded-full border-4 border-brand-accent bg-brand-accent/20"
   153	          />
   154	
   155	          <p
   156	            aria-live="polite"
   157	            aria-atomic="true"
   158	            data-testid="breathing-label"
   159	            className="text-brand-text-primary text-center text-3xl font-semibold"
   160	          >
   161	            {currentStep.label}
   162	          </p>
   163	
   164	          <p className="text-brand-text-secondary text-center text-base">
   165	            Breath {cycleCount + 1} of {pattern.totalCycles}
   166	          </p>
   167	
   168	          <button
   169	            type="button"
   170	            onClick={handleReset}
   171	            aria-label="Restart breathing exercise"
   172	            className="flex items-center gap-2 px-4 py-2 rounded-xl text-brand-text-secondary hover:bg-brand-accent/10 active:scale-95 transition-transform touch-target-critical"
   173	          >
   174	            <Icon icon={RotateCcw} size="sm" /> <span className="text-sm font-semibold uppercase tracking-wide">Reset</span>
   175	          </button>
   176	        </>
   177	      )}
   178	    </div>
   179	  );
   180	}
   181	
   182	export default BreathingExercise;

--- wilderness/src/components/emergency/PanicOverlay.tsx ---
     1	import React, { useState, useEffect, useCallback } from 'react';
     2	import { haptic } from '../../services/nativeHaptics';
     3	import { X } from 'lucide-react';
     4	import { Icon } from '../ui/Icon';
     5	
     6	interface PanicOverlayProps {
     7	  isOpen: boolean;
     8	  onClose: () => void;
     9	}
    10	
    11	type BreathPhase = 'inhale' | 'hold-in' | 'exhale' | 'hold-out';
    12	
    13	const PHASES: { phase: BreathPhase; label: string; scale: number }[] = [
    14	  { phase: 'inhale', label: 'Breathe In', scale: 1.0 },
    15	  { phase: 'hold-in', label: 'Hold', scale: 1.0 },
    16	  { phase: 'exhale', label: 'Breathe Out', scale: 0.4 },
    17	  { phase: 'hold-out', label: 'Hold', scale: 0.4 },
    18	];
    19	
    20	const PHASE_DURATION_MS = 4000;
    21	const PHASE_DURATION_S = PHASE_DURATION_MS / 1000;
    22	const TOTAL_CYCLES = 10;
    23	
    24	export function PanicOverlay({ isOpen, onClose }: PanicOverlayProps) {
    25	  const [phaseIndex, setPhaseIndex] = useState(0);
    26	  const [cycleCount, setCycleCount] = useState(0);
    27	  const [completed, setCompleted] = useState(false);
    28	
    29	  const advancePhase = useCallback(() => {
    30	    setPhaseIndex((prev) => {
    31	      const next = (prev + 1) % PHASES.length;
    32	      if (next === 0) {
    33	        setCycleCount((c) => {
    34	          const newCount = c + 1;
    35	          if (newCount >= TOTAL_CYCLES) {
    36	            setCompleted(true);
    37	          }
    38	          return newCount;
    39	        });
    40	      }
    41	      return next;
    42	    });
    43	    void haptic('medium');
    44	  }, []);
    45	
    46	  useEffect(() => {
    47	    if (!isOpen || completed) return;
    48	
    49	    const id = setInterval(advancePhase, PHASE_DURATION_MS);
    50	    return () => clearInterval(id);
    51	  }, [isOpen, completed, advancePhase]);
    52	
    53	  useEffect(() => {
    54	    if (!isOpen) {
    55	      setPhaseIndex(0);
    56	      setCycleCount(0);
    57	      setCompleted(false);
    58	    }
    59	  }, [isOpen]);
    60	
    61	  if (!isOpen) return null;
    62	
    63	  const currentPhase = PHASES[phaseIndex];
    64	  const circleScale = currentPhase.scale;
    65	
    66	  return (
    67	    <div
    68	      role="dialog"
    69	      aria-modal="true"
    70	      aria-label="Tactical breathing exercise"
    71	      className="fixed inset-0 z-[110] flex flex-col items-center justify-between bg-brand-bg px-6 py-8"
    72	    >
    73	      {/* Close button */}
    74	      <div className="flex w-full justify-end">
    75	        <button
    76	          onClick={onClose}
    77	          aria-label="Close breathing exercise"
    78	          className="w-14 h-14 rounded-full bg-brand-surface border-2 border-brand-text-secondary/20 text-brand-text-primary flex items-center justify-center"
    79	        >
    80	          <Icon icon={X} size="lg" />
    81	        </button>
    82	      </div>
    83	
    84	      {/* Main content */}
    85	      <div className="flex flex-col items-center gap-6 flex-1 justify-center">
    86	        {/* STOP prompt */}
    87	        <p className="text-brand-text-primary text-center text-xl font-bold tracking-wide">
    88	          STOP. Sit down. Think. Observe. Plan.
    89	        </p>
    90	        <p className="text-brand-text-secondary text-center text-sm">
    91	          Tactical breathing - used by military and search &amp; rescue teams
    92	        </p>
    93	
    94	        {completed ? (
    95	          /* Completion state */
    96	          <div className="flex flex-col items-center gap-4 mt-4">
    97	            <p className="text-brand-text-primary text-center text-2xl font-semibold">
    98	              You're ready.
    99	            </p>
   100	            <p className="text-brand-text-secondary text-center text-lg">
   101	              Think clearly. Make a plan.
   102	            </p>
   103	          </div>
   104	        ) : (
   105	          /* Breathing circle + phase label */
   106	          <div className="flex flex-col items-center gap-8 mt-4">
   107	            {/* Circle */}
   108	            <div
   109	              aria-hidden="true"
   110	              style={{
   111	                transform: `scale(${circleScale})`,
   112	                transition: `transform ${PHASE_DURATION_S}s ease-in-out`,
   113	              }}
   114	              className="w-52 h-52 rounded-full border-4 border-brand-accent bg-brand-accent/20"
   115	            />
   116	
   117	            {/* Phase label */}
   118	            <p
   119	              aria-live="assertive"
   120	              aria-atomic="true"
   121	              className="text-brand-text-primary text-center text-3xl font-semibold"
   122	            >
   123	              {currentPhase.label}
   124	            </p>
   125	
   126	            {/* Cycle counter */}
   127	            <p className="text-brand-text-secondary text-center text-base">
   128	              Breath {cycleCount + 1} of {TOTAL_CYCLES}
   129	            </p>
   130	          </div>
   131	        )}
   132	      </div>
   133	
   134	      {/* 911 reminder + citation */}
   135	      <div className="text-center mt-4 space-y-1">
   136	        <p className="text-brand-text-secondary text-xs font-semibold">
   137	          If in immediate danger, call 911 or your local emergency number.
   138	        </p>
   139	        <p className="text-brand-footer text-xs">
   140	          STOP Protocol (US Forest Service) o FM 21-76
   141	        </p>
   142	      </div>
   143	    </div>
   144	  );
   145	}
   146	
   147	export default PanicOverlay;

--- BoardBound/boardbound/app/quiz/question.tsx ---
     1	import { useEffect, useMemo, useState } from "react";
     2	import { View, Text, Pressable, ScrollView, Alert } from "react-native";
     3	import { useRouter } from "expo-router";
     4	import { Ionicons } from "@expo/vector-icons";
     5	import Animated, { FadeInDown } from "react-native-reanimated";
     6	import * as Haptics from "expo-haptics";
     7	import { useReduceMotion } from "../../lib/hooks/useReduceMotion";
     8	import { useQuizStore } from "../../lib/stores/useQuizStore";
     9	import { useSubscriptionStore } from "../../lib/stores/useSubscriptionStore";
    10	import { useGameModeStore } from "../../lib/stores/useGameModeStore";
    11	import {
    12	  getTodayAnsweredCount,
    13	  getQuestionAttemptStats,
    14	  wasTutorUsedForQuestion,
    15	} from "../../lib/db/progress";
    16	import { FREE_DAILY_QUESTIONS, DOMAIN_LABELS } from "../../lib/utils/constants";
    17	import { canAccessQuestions } from "../../lib/utils/subscription-helpers";
    18	import { earnFromAnswer } from "../../lib/utils/earn-from-answer";
    19	import type { EarnSpec } from "../../lib/utils/coin-rules";
    20	import { QuestionCard } from "../../components/question/QuestionCard";
    21	import { OptionButton } from "../../components/question/OptionButton";
    22	import { FeedbackPanel } from "../../components/question/FeedbackPanel";
    23	import { QuestionSkeleton } from "../../components/question/QuestionSkeleton";
    24	import { QuizErrorBoundary } from "../../components/QuizErrorBoundary";
    25	import { EarnToast } from "../../components/game/EarnToast";
    26	
    27	export default function QuestionScreenWithBoundary() {
    28	  return (
    29	    <QuizErrorBoundary>
    30	      <QuestionScreen />
    31	    </QuizErrorBoundary>
    32	  );
    33	}
    34	
    35	const MODE_LABELS: Record<string, string> = {
    36	  adaptive: "Smart Practice",
    37	  srs_review: "Spaced Review",
    38	  domain_focus: "Domain Focus",
    39	  random: "",
    40	};
    41	
    42	function QuestionScreen() {
    43	  const router = useRouter();
    44	  const reduceMotion = useReduceMotion();
    45	  const {
    46	    status,
    47	    currentQuestion,
    48	    selectedOptionId,
    49	    isAnswered,
    50	    isCorrect,
    51	    questionsAnswered,
    52	    correctCount,
    53	    studyStrategy,
    54	    startTime,
    55	    markedForReview,
    56	    loadQuestion,
    57	    selectOption,
    58	    submitAnswer,
    59	    nextQuestion,
    60	    toggleMarkForReview,
    61	  } = useQuizStore();
    62	  const tier = useSubscriptionStore((s) => s.tier);
    63	  const gameModePreference = useGameModeStore((s) => s.preference);
    64	  const earnCoins = useGameModeStore((s) => s.earn);
    65	  const [upsellDismissed, setUpsellDismissed] = useState(false);
    66	  const [elapsedSeconds, setElapsedSeconds] = useState(0);
    67	  const [latestEarn, setLatestEarn] = useState<EarnSpec | null>(null);
    68	  const [priorAttempts, setPriorAttempts] = useState<{
    69	    attemptCount: number;
    70	    accuracy: number;
    71	  } | null>(null);
    72	  const todayTotal = useMemo(() => getTodayAnsweredCount(), [isAnswered]);
    73	
    74	  // Capture prior-attempt stats when a new question loads. Done BEFORE the
    75	  // user submits so the chip reflects history (Barkley parity: "Seen 3x, 33%
    76	  // correct"), not the current attempt-in-progress.
    77	  useEffect(() => {
    78	    if (!currentQuestion?.id) {
    79	      setPriorAttempts(null);
    80	      return;
    81	    }
    82	    if (isAnswered) return; // freeze chip during answer feedback
    83	    try {
    84	      const stats = getQuestionAttemptStats(currentQuestion.id);
    85	      setPriorAttempts({
    86	        attemptCount: stats.attemptCount,
    87	        accuracy: stats.accuracy,
    88	      });
    89	    } catch (e) {
    90	      console.error("Failed to load attempt stats:", e);
    91	      setPriorAttempts(null);
    92	    }
    93	  }, [currentQuestion?.id, isAnswered]);
    94	
    95	  // Per-question timer. Freeze the displayed value once the question has
    96	  // been answered so feedback time isn't counted against the user.
    97	  useEffect(() => {
    98	    if (!startTime) {
    99	      setElapsedSeconds(0);
   100	      return;
   101	    }
   102	    if (isAnswered) {
   103	      return;
   104	    }
   105	    setElapsedSeconds(0);
   106	    let elapsed = 0;
   107	    const interval = setInterval(() => {
   108	      elapsed += 1;
   109	      setElapsedSeconds(elapsed);
   110	    }, 1000);
   111	    return () => clearInterval(interval);
   112	  }, [startTime, currentQuestion?.id, isAnswered]);
   113	  const showUpsell = tier === "free" && isAnswered && todayTotal >= 5 && todayTotal <= 10 && !upsellDismissed;
   114	
   115	  useEffect(() => {
   116	    loadQuestion();
   117	  }, [loadQuestion]);
   118	
   119	  // Deep-link cover: if the user lands here over the daily limit and the
   120	  // current question has not been answered yet, redirect to the paywall.
   121	  useEffect(() => {
   122	    if (
   123	      currentQuestion &&
   124	      !isAnswered &&
   125	      !canAccessQuestions(tier, getTodayAnsweredCount())
   126	    ) {
   127	      router.replace("/paywall");
   128	    }
   129	  }, [currentQuestion, isAnswered, tier, router]);
   130	
   131	  // Haptic feedback when answer is revealed
   132	  useEffect(() => {
   133	    if (isAnswered && isCorrect !== null) {
   134	      Haptics.notificationAsync(
   135	        isCorrect
   136	          ? Haptics.NotificationFeedbackType.Success
   137	          : Haptics.NotificationFeedbackType.Error
   138	      );
   139	    }
   140	  }, [isAnswered, isCorrect]);
   141	
   142	  // Game Mode: award coins for correct answers (off-mode short-circuits).
   143	  // attemptNumber + usedTutor must reflect the user's real history so the
   144	  // earn rules can classify first_try (+10) vs after_wrong (+3) vs
   145	  // after_tutor (+3). At this point in the lifecycle the new answer has
   146	  // already been inserted into user_answers by submitAnswer, so the
   147	  // attemptCount it returns IS the running attempt number (not prior).
   148	  useEffect(() => {
   149	    if (!isAnswered || isCorrect !== true || !currentQuestion) return;
   150	    if (gameModePreference === "off") return;
   151	    const { attemptCount } = getQuestionAttemptStats(currentQuestion.id);
   152	    const earn = earnFromAnswer({
   153	      questionId: currentQuestion.id,
   154	      isCorrect: true,
   155	      attemptNumber: Math.max(1, attemptCount),
   156	      usedTutor: wasTutorUsedForQuestion(currentQuestion.id),
   157	    });
   158	    if (!earn) return;
   159	    earnCoins(earn.amount, earn.source, currentQuestion.id);
   160	    setLatestEarn(earn);
   161	  }, [isAnswered, isCorrect, currentQuestion, gameModePreference, earnCoins]);
   162	
   163	  if (status === "no_questions") {
   164	    const isSrsMode = studyStrategy === "srs_review";
   165	    return (
   166	      <View className="flex-1 items-center justify-center bg-white dark:bg-gray-900 px-6">
   167	        <Ionicons
   168	          name={isSrsMode ? "checkmark-circle-outline" : "alert-circle-outline"}
   169	          size={48}
   170	          color={isSrsMode ? "#16a34a" : "#f59e0b"}
   171	        />
   172	        <Text className="mt-4 text-center text-lg font-medium text-gray-700 dark:text-gray-300">
   173	          {isSrsMode ? "All caught up" : "No questions available"}
   174	        </Text>
   175	        <Text className="mt-2 text-center text-sm text-gray-500 dark:text-gray-400">
   176	          {isSrsMode
   177	            ? "No cards are due for review right now. Keep practicing to build your review queue."
   178	            : "Questions may not have loaded yet. Try restarting the app."}
   179	        </Text>
   180	        <Pressable
   181	          accessibilityRole="button"
   182	          className="mt-6 rounded-xl bg-brand-600 px-8 py-3 active:bg-brand-700"
   183	          onPress={() => router.back()}
   184	        >
   185	          <Text className="font-bold text-white">Back to Study</Text>
   186	        </Pressable>
   187	      </View>
   188	    );
   189	  }
   190	
   191	  if (!currentQuestion) {
   192	    return <QuestionSkeleton />;
   193	  }
   194	
   195	  const handleEndSession = () => {
   196	    if (questionsAnswered === 0) {
   197	      router.back();
   198	      return;
   199	    }
   200	    Alert.alert(
   201	      "End Session?",
   202	      `You've answered ${questionsAnswered} question${questionsAnswered === 1 ? "" : "s"}. End now and see your results?`,
   203	      [
   204	        { text: "Keep Going", style: "cancel" },
   205	        {
   206	          text: "End Session",
   207	          onPress: () => router.replace("/quiz/results"),
   208	        },
   209	      ]
   210	    );
   211	  };
   212	
   213	  const questionNumber = questionsAnswered + (isAnswered ? 0 : 1);
   214	  const accuracy =
   215	    questionsAnswered > 0
   216	      ? Math.round((correctCount / questionsAnswered) * 100)
   217	      : 0;
   218	
   219	  const sessionTarget =
   220	    studyStrategy === "domain_focus" ? 20 : 12;
   221	
   222	  const timerColorClass =
   223	    elapsedSeconds > 120
   224	      ? "text-red-500"
   225	      : elapsedSeconds >= 90
   226	        ? "text-amber-500"
   227	        : "text-gray-500 dark:text-gray-400";
   228	
   229	  return (
   230	    <View className="flex-1">
   231	    <ScrollView className="flex-1 bg-white dark:bg-gray-900" contentContainerClassName="p-5 pb-12">
   232	      <View className="mb-4 flex-row items-center justify-between">
   233	        <View className="flex-row items-center gap-2">
   234	          <Text className="text-sm text-gray-600 dark:text-gray-400">
   235	            {questionNumber} / {sessionTarget} . {currentQuestion ? DOMAIN_LABELS[currentQuestion.domain] : ""}
   236	          </Text>
   237	        </View>
   238	        <View className="flex-row items-center gap-3">
   239	          {markedForReview.size > 0 && (
   240	            <View className="flex-row items-center gap-1" testID="marked-count-indicator">
   241	              <Ionicons name="bookmark" size={14} color="#1f5c54" />
   242	              <Text className="text-sm font-medium text-brand-600 dark:text-brand-400">
   243	                {markedForReview.size}
   244	              </Text>
   245	            </View>
   246	          )}
   247	          <Text className={`text-sm font-mono ${timerColorClass}`} testID="question-timer">
   248	            {Math.floor(elapsedSeconds / 60)}:{String(elapsedSeconds % 60).padStart(2, "0")}
   249	          </Text>
   250	          {questionsAnswered > 0 && (

--- burn-wizard/app/src/styles/design-system.css ---
     1	@tailwind base;
     2	@tailwind components;
     3	@tailwind utilities;
     4	
     5	@layer base {
     6	  :root {
     7	    /* === MEDICAL WIZARDS UNIFIED DESIGN SYSTEM === */
     8	    /* Professional Medical Design System - Teal-Blue Harmony Theme */
     9	    
    10	    /* Base Colors - Clinical White with Medical Hints */
    11	    --background: 180 20% 98%; /* Clinical white with subtle teal hint */
    12	    --foreground: 192 95% 9%; /* Deep medical teal for text */
    13	    --card: 0 0% 100%; /* Pure white cards for medical clarity */
    14	    --card-foreground: 192 95% 9%;
    15	    --popover: 0 0% 100%;
    16	    --popover-foreground: 192 95% 9%;
    17	    
    18	    /* Primary Medical Palette - Professional Teal-Blue */
    19	    /* WCAG 2.1 AA: 38% measured 2.860:1 on white - it failed even the 3.0:1 large-text
    20	       allowance, so the brand teal was non-compliant at any size (F-01). 27% clears 4.5:1
    21	       against all four light surfaces: card 5.265, background 5.070, secondary 4.776,
    22	       muted 4.660. 28% was considered and rejected - it misses on secondary (4.476) and
    23	       muted (4.367). --ring and --region-stroke below are SEPARATE tokens that happen to
    24	       share this value; they are changed deliberately, not as a consequence of this line. */
    25	    --primary: 174 76% 27%; /* Professional medical teal */
    26	    --primary-light: 174 65% 55%; /* Lighter teal for hover states */
    27	    --primary-dark: 174 85% 28%; /* Darker teal for emphasis */
    28	    --primary-foreground: 0 0% 100%;
    29	    
    30	    /* Secondary Medical Blue (for ECG/Cardio contexts) */
    31	    --secondary-blue: 220 90% 48%; /* Professional medical blue */
    32	    --secondary-blue-light: 220 85% 65%; /* Lighter blue for hover */
    33	    --secondary-blue-dark: 220 95% 35%; /* Darker blue for emphasis */
    34	    
    35	    /* Supporting Colors */
    36	    --secondary: 180 25% 95%; /* Very light teal background */
    37	    --secondary-foreground: 192 95% 9%;
    38	    --muted: 180 15% 94%; /* Subtle neutral background */
    39	    --muted-foreground: 192 30% 35%; /* Darker for WCAG AA contrast (4.5:1+) */
    40	    --accent: 174 45% 85%; /* Soft teal accent */
    41	    --accent-foreground: 192 95% 9%;
    42	    
    43	    /* Medical Status Colors - Clinical Context */
    44	    --success: 142 69% 45%; /* Medical green for positive states */
    45	    --success-light: 142 60% 60%; /* Lighter success */
    46	    --success-dark: 142 75% 35%; /* Darker success */
    47	    --success-foreground: 0 0% 100%;
    48	    
    49	    --warning: 43 89% 58%; /* Amber for caution */
    50	    --warning-light: 43 85% 70%; /* Lighter warning */
    51	    --warning-dark: 43 95% 45%; /* Darker warning */
    52	    --warning-foreground: 43 15% 15%;
    53	    
    54	    --destructive: 0 72% 51%; /* Medical red for critical alerts */
    55	    --destructive-light: 0 65% 65%; /* Lighter destructive */
    56	    --destructive-dark: 0 80% 40%; /* Darker destructive */
    57	    --destructive-foreground: 0 0% 100%;
    58	    
    59	    --info: 207 90% 54%; /* Medical blue for information */
    60	    --info-light: 207 85% 70%; /* Lighter info */
    61	    --info-dark: 207 95% 42%; /* Darker info */
    62	    --info-foreground: 0 0% 100%;
    63	    
    64	    /* Interface Elements */
    65	    --border: 180 25% 87%; /* Refined border color */
    66	    --input: 180 20% 96%; /* Input background */
    67	    /* F-02: independent token, not derived from --primary. 38% gave 2.860:1 against the
    68	       page, below the 3:1 non-text requirement for focus indicators. */
    69	    --ring: 174 76% 27%; /* Focus ring matches primary */
    70	    --radius: 0.75rem; /* Consistent border radius */
    71	    
    72	    /* Medical Severity Palette - Enhanced for Burn Assessment */
    73	    --burn-none: 0 0% 98%; /* No burn - near white */
    74	    --burn-superficial: 0 45% 88%; /* Light pink for superficial */
    75	    --burn-superficial-partial: 25 65% 80%; /* Warm peach */
    76	    --burn-deep-partial: 35 75% 70%; /* Golden amber */
    77	    --burn-full-thickness: 195 15% 75%; /* Cool gray */
    78	    
    79	    /* ECG/Cardiac Specific Colors */
    80	    --ecg-normal: 142 69% 45%; /* Normal rhythm - green */
    81	    --ecg-abnormal: 43 89% 58%; /* Abnormal rhythm - amber */
    82	    --ecg-critical: 0 72% 51%; /* Critical rhythm - red */
    83	    --ecg-trace: 220 90% 48%; /* ECG trace blue */
    84	    
    85	    /* Clinical Risk Levels */
    86	    --risk-low: 142 69% 45%; /* Low risk - green */
    87	    --risk-moderate: 43 89% 58%; /* Moderate risk - amber */
    88	    --risk-high: 25 85% 60%; /* High risk - orange */
    89	    --risk-critical: 0 72% 51%; /* Critical risk - red */
    90	
    91	    /* Body Map Region Colors - Burn Intensity */
    92	    --region-none: 215 20% 96%; /* Slate-100 - unselected region */
    93	    --region-25: 48 96% 89%; /* Amber-100 - 25% burn */
    94	    --region-50: 33 95% 80%; /* Orange-200 - 50% burn */
    95	    --region-75: 0 94% 82%; /* Red-300 - 75% burn */
    96	    --region-100: 0 84% 60%; /* Red-500 - 100% burn */
    97	    /* F-01b: the body-map SELECTED-REGION indicator - a clinical surface. Independent
    98	       token. 38% gave 2.860:1 against a 3:1 non-text requirement.
    99	       The teal alone CANNOT satisfy SC 1.4.11 against these fills at any lightness that
   100	       still reads as teal: against --region-100 (red-500) it is 1.39, and --region-75 is
   101	       2.79. Compliance is carried by --region-stroke-halo, drawn under it, which clears
   102	       3:1 against every one of the five BASE FILLS on its own (min 4.73, vs --region-100).
   103	       The teal is the brand layer on top; the halo is the accessible one. Measure the HALO
   104	       when checking this, not the pair.
   105	       SCOPE, stated precisely because an earlier version of this comment overclaimed: the
   106	       5-fill guarantee does NOT yet cover (a) the fraction/depth PATTERN overlays, which
   107	       paint after the interactive path and composite to ~2.71 light / ~2.38 dark against
   108	       the halo, or (b) shared boundaries where a later-painted neighbouring region can
   109	       overwrite an earlier region's halo. F-01b is therefore still OPEN. */
   110	    --region-stroke: 174 76% 27%; /* Primary teal - selected stroke */
   111	    --region-stroke-halo: 222 47% 11%; /* Slate-900 - outer halo, carries the 3:1 */
   112	    --region-stroke-default: 215 20% 80%; /* Slate-300 - default stroke */
   113	
   114	    /* SVG pattern stroke/fill colors for colorblind-accessibility overlays */
   115	    /* Light mode: dark tones readable on light body-map backgrounds */
   116	    --burn-pattern-25: 22 78% 31%;   /* Amber-900 */
   117	    --burn-pattern-50: 18 88% 40%;   /* Orange-700 */
   118	    --burn-pattern-75: 0 70% 35%;    /* Red-900 */
   119	    --burn-pattern-100: 0 63% 31%;   /* Red-950 */
   120	    --burn-depth-pattern: 0 0% 0%;   /* Black (with alpha applied via var syntax) */
   121	    
   122	    /* Gradient Definitions for Medical UI */
   123	    /* Start stops tracked --primary's old 38%; kept in step for palette consistency.
   124	       Decorative - no WCAG requirement attaches to either gradient. */
   125	    --gradient-primary: linear-gradient(135deg, hsl(174 76% 27%) 0%, hsl(174 65% 55%) 100%);
   126	    --gradient-card: linear-gradient(145deg, hsl(0 0% 100%) 0%, hsl(180 20% 98%) 100%);
   127	    --gradient-accent: linear-gradient(120deg, hsl(174 45% 85%) 0%, hsl(180 25% 95%) 100%);
   128	    --gradient-medical: linear-gradient(135deg, hsl(174 76% 27%) 0%, hsl(220 90% 48%) 100%);
   129	  }
   130	
   131	  .dark {
   132	    /* === DARK MODE - PROFESSIONAL MEDICAL THEME === */
   133	    
   134	    /* Dark Base Colors */
   135	    --background: 192 45% 8%; /* Deep medical teal background */
   136	    --foreground: 180 15% 94%; /* Light text for contrast */
   137	    --card: 192 35% 12%; /* Dark card background */
   138	    --card-foreground: 180 15% 94%;
   139	    --popover: 192 35% 12%;
   140	    --popover-foreground: 180 15% 94%;
   141	    
   142	    /* Dark Mode Primary Palette */
   143	    --primary: 174 65% 55%; /* Bright teal for dark backgrounds */
   144	    --primary-light: 174 55% 70%; /* Even lighter for hover */
   145	    --primary-dark: 174 75% 45%; /* Darker variant */
   146	    --primary-foreground: 192 45% 8%; /* Dark text on teal */
   147	    
   148	    /* Dark Mode Secondary Blue */
   149	    --secondary-blue: 220 85% 65%; /* Brighter blue for dark mode */
   150	    --secondary-blue-light: 220 80% 80%; /* Lighter blue hover */
   151	    --secondary-blue-dark: 220 90% 50%; /* Darker blue emphasis */
   152	    
   153	    /* Dark Mode Supporting Colors */
   154	    --secondary: 192 25% 20%; /* Dark secondary background */
   155	    --secondary-foreground: 180 15% 94%;
   156	    --muted: 192 20% 18%; /* Dark muted background */
   157	    --muted-foreground: 180 10% 65%; /* Muted text */
   158	    --accent: 174 35% 25%; /* Dark accent */
   159	    --accent-foreground: 180 15% 94%;
   160	    
   161	    /* Dark Mode Status Colors */
   162	    --success: 142 60% 50%; /* Brighter green for dark mode */
   163	    --success-light: 142 55% 65%; /* Lighter success */
   164	    --success-dark: 142 70% 40%; /* Darker success */
   165	    --success-foreground: 142 30% 10%;
   166	    
   167	    --warning: 43 85% 65%; /* Brighter amber */
   168	    --warning-light: 43 80% 75%; /* Lighter warning */
   169	    --warning-dark: 43 90% 55%; /* Darker warning */
   170	    --warning-foreground: 43 20% 15%;
   171	    
   172	    --destructive: 0 65% 55%; /* Brighter red */
   173	    --destructive-light: 0 60% 70%; /* Lighter destructive */
   174	    --destructive-dark: 0 75% 45%; /* Darker destructive */
   175	    --destructive-foreground: 0 0% 100%;
   176	    
   177	    --info: 207 85% 65%; /* Brighter info blue */
   178	    --info-light: 207 80% 80%; /* Lighter info */
   179	    --info-dark: 207 90% 50%; /* Darker info */
   180	    --info-foreground: 0 0% 100%;
   181	    
   182	    /* Dark Mode Interface */
   183	    --border: 192 25% 25%; /* Visible borders in dark mode */
   184	    --input: 192 25% 20%; /* Input backgrounds */
   185	    --ring: 174 65% 55%; /* Focus ring */
   186	    
   187	    /* Dark Mode Burn Colors */
   188	    --burn-none: 192 45% 8%; /* Same as background */
   189	    --burn-superficial: 0 35% 30%; /* Dark pink */
   190	    --burn-superficial-partial: 25 45% 35%; /* Dark peach */
   191	    --burn-deep-partial: 35 55% 35%; /* Dark amber - lowered from 40% for WCAG AA 4.5:1 contrast */
   192	    --burn-full-thickness: 195 15% 35%; /* Dark gray */
   193	    
   194	    /* Dark Mode ECG/Cardiac Colors */
   195	    --ecg-normal: 142 60% 50%; /* Brighter green */
   196	    --ecg-abnormal: 43 85% 65%; /* Brighter amber */
   197	    --ecg-critical: 0 65% 55%; /* Brighter red */
   198	    --ecg-trace: 220 85% 65%; /* Brighter trace blue */
   199	    
   200	    /* Dark Mode Clinical Risk Levels */
   201	    --risk-low: 142 60% 50%; /* Brighter low risk */
   202	    --risk-moderate: 43 85% 65%; /* Brighter moderate */
   203	    --risk-high: 25 80% 65%; /* Brighter high risk */
   204	    --risk-critical: 0 65% 55%; /* Brighter critical */
   205	
   206	    /* Dark Mode Body Map Region Colors */
   207	    --region-none: 222 47% 11%; /* Slate-900 - dark unselected */
   208	    --region-25: 28 80% 20%; /* Dark amber */
   209	    --region-50: 20 80% 28%; /* Dark orange */
   210	    --region-75: 0 70% 30%; /* Dark red-700 */
   211	    --region-100: 0 84% 60%; /* Red-500 stays bright */
   212	    /* F-01b, dark mode: the halo INVERTS to light here. --region-stroke 174 80% 50% is
   213	       2.38 against --region-100, which stays bright red-500 in dark - so dark mode failed
   214	       the same way light did and no session had measured it. The white halo clears every
   215	       dark fill on its own (min 3.78). 