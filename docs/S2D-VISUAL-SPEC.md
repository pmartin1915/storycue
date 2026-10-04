# S2d spec — visual pass (accent, primary button, record ring, haptics, deck tiles)

_Written 2026-10-04. Sources: `docs/reviews/DESIGN-REVIEW-2026-10-03.md` (rows 1–6, 8, 9a, 10, 14,
Opus-adjudicated) and the Martin Apps house style v0 in
`C:/Users/perry/DevProjects/dev-ops/research/WW-0103-ADJUDICATION.md` (Sonnet-adjudicated).
Accent values from `ai/STATE.md` (S2c/S2d entry, refined 10-04 for WCAG). Same contract style as
S2a–S2c: every file, type, name and test below is fixed, so `/orchestrate` does not invent shapes.
Single-screen 1.0, no Duo code. S2d is the first step to cut if S7 (10-10) goes badly, so the parts
are ordered: a delivery that stops after any part is still coherent._

## Scope

**In:** terracotta accent with WCAG-safe labels; a small design-tokens file; a style lint test;
a filled bottom primary button on Consent; a real record button; haptics on the recorder; deck
tiles and one-line teasers; a serif trial for questions; library row and empty-state polish; a
session summary header; DEBUG-only launch arguments plus screenshots for dark mode and the largest
text size.

**Out (diff is rejected if it touches these):** `SessionStore`, `SessionMachine`, `Library`,
`SessionIndex`, `SegmentLedger`, `SegmentFiles`, `Exporter`, `ExportPlan`, `ExportManifest`,
`ExportModel`, `Stitcher`, `AVCaptureService`, `CaptureService`, `MockCaptureService` (data-loss and
capture code; PR #8 is open in that area). `AnswerPlayerView` and `ExportView` are not restyled
(the one exception: `AnswerPlayerView.swift:85`'s `cornerRadius: 12` becomes
`DesignTokens.Radius.card`, so the part 3 lint passes).
The recorder's dark question card over the camera **stays** (design review row 7, deferred to a
device check). No thumbnails or durations in the library (LATER). No swipe-to-delete changes.
No new dependencies.

## Frozen constraints

- Test anchors stay exactly as they are: `deck.<id>`, `consentConfirm`, `recordButton`,
  `doneButton`, `libraryButton`, `session.<deckID>`, and the session detail's inline navigation
  title equal to the deck title ("Grandparents"). `ScreenshotTests` must pass unchanged in its
  existing method.
- Every user-visible string lives in `UICopy` (existing rule). No string literal shown to the user
  in any other file.
- Existing VoiceOver labels stay (`primaryLabel(p)`, `advanceLabel(a)`, `UICopy.playAnswer`, the
  deck row's combined label).
- The `#if DEBUG` demo backdrop in `RecorderView` survives (its colors move into tokens, part 2).
- Swift 6 strict concurrency; iOS 27 deployment target. Every API used here exists on iOS 17+.
- 44 pt minimum hit targets everywhere (house style rule 4).

## Part 1 — Accent and labels

1. New `StoryCue/Assets.xcassets/AccentColor.colorset/Contents.json`, exactly:

   ```json
   {
     "colors" : [
       { "color" : { "color-space" : "srgb",
           "components" : { "alpha" : "1.000", "blue" : "0x2B", "green" : "0x51", "red" : "0xAD" } },
         "idiom" : "universal" },
       { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
         "color" : { "color-space" : "srgb",
           "components" : { "alpha" : "1.000", "blue" : "0x50", "green" : "0x7A", "red" : "0xE0" } },
         "idiom" : "universal" }
     ],
     "info" : { "author" : "xcode", "version" : 1 }
   }
   ```
2. New `StoryCue/Assets.xcassets/OnAccent.colorset/Contents.json`, same structure: universal
   `0xFF 0xFF 0xFF`, dark `0x1C 0x1C 0x1E`. This is the label color on any accent-filled control.
3. `project.yml`, `StoryCue` target `settings.base`: add
   `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor`. **Required:** this hand-authored
   XcodeGen project does not get Xcode's template defaults (same class of gap as `DEBUG`, see the
   comment in `project.yml`); without it the asset tints nothing.
4. Contrast, already computed (STATE 10-04): light white-on-`#AD512B` 5.26:1; dark
   `#1C1C1E`-on-`#E07A50` ≈ 5.7:1. Part 3's test enforces ≥ 4.5:1 from the JSON files.

## Part 2 — Tokens file

New `StoryCue/DesignTokens.swift` (`import SwiftUI`). The seed of the later shared package, so keep
it small and flat:

```swift
enum DesignTokens {
    enum Spacing {           // multiples of 4
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }
    enum Radius {
        static let card: CGFloat = 12      // cards, banners, callouts
        static let tile: CGFloat = 10      // deck tiles
    }
    enum Motion {                          // nothing over 0.5 s
        static let morph = Animation.spring(duration: 0.3)
        static let fade = Animation.easeOut(duration: 0.2)
    }
    enum RecordButton {
        static let outer: CGFloat = 72
        static let ringWidth: CGFloat = 4
        static let dot: CGFloat = 58
        static let square: CGFloat = 28
        static let squareRadius: CGFloat = 6
    }
    /// The serif trial (design review row 6). Revert to `.default` in this one line.
    static let questionFontDesign: Font.Design = .serif
    static let onAccent = Color("OnAccent")
    /// Deck tiles: one terracotta family, never a rainbow (WW-0103 disagreement 4).
    static let tileFill = Color.accentColor.opacity(0.15)
    static let tileSymbol = Color.accentColor
    /// Translucent black behind text over the camera (≥ 7:1 white text over a white feed).
    static let overCameraFill = Color.black.opacity(0.7)
    #if DEBUG
    static let demoBackdropTop = Color(red: 0.20, green: 0.13, blue: 0.09)
    static let demoBackdropBottom = Color(red: 0.06, green: 0.04, blue: 0.03)
    #endif
}

extension View {
    /// The one filled primary action of a screen: full width, large, accent fill,
    /// `OnAccent` label. Apply to a `Button` whose label is `Text`.
    func primaryAction() -> some View {
        self
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .foregroundStyle(DesignTokens.onAccent)
    }
}
```

Replace every existing `cornerRadius: 12` literal in `StoryCue/Views/*.swift` with
`DesignTokens.Radius.card`, every `.black.opacity(0.7)` with `DesignTokens.overCameraFill`, and the
demo gradient's two `Color(red:…)` with the two tokens. Spacing literals in code this spec touches
use `DesignTokens.Spacing`; untouched code keeps its literals (not linted).

If `.foregroundStyle` on the button does not color a `.borderedProminent` label (it does on iOS 17+
when applied outside the style, but this is a screenshot check, part 10), the fallback is to apply
`.foregroundStyle(DesignTokens.onAccent)` to the `Text` inside the label instead. Boss decides from
the dark screenshot.

## Part 3 — Tests for parts 1–2 (pure, no simulator UI)

New `StoryCueTests/StyleLintTests.swift`, reading source files through `#filePath` exactly like
`UICopyTests.testNoCopyContainsTODO`:

- `testNoFixedFontSizes`: no `StoryCue/**/*.swift` file contains `.system(size:`.
- `testNoLiteralCornerRadius`: no file except `DesignTokens.swift` matches the regex
  `cornerRadius:\s*[0-9]`.
- `testNoLiteralColorsOutsideTokens`: no file except `DesignTokens.swift` contains `Color(red:`.
- `testNoAnimationLiteralsOutsideTokens`: no file except `DesignTokens.swift` contains `.spring(`,
  `.easeIn(`, `.easeOut(`, `.easeInOut(` or `.linear(`.
- `testAccentContrast`: parse `AccentColor.colorset/Contents.json` and
  `OnAccent.colorset/Contents.json` (hex string components), and for both the universal and the dark
  entries assert WCAG contrast(accent, onAccent) ≥ 4.5. Implement relative luminance per WCAG 2.1
  (sRGB linearization with the 0.04045 threshold) in a private helper in the test file.

Walk `StoryCue/` recursively with `FileManager.enumerator`; fail with the file name on a hit.

## Part 4 — Consent: one filled bottom button

`ConsentView`:

- The `consentConfirm` button moves out of the `ScrollView` into
  `.safeAreaInset(edge: .bottom) { … }` on the scroll view, with `.padding(DesignTokens.Spacing.l)`
  and `.background(.bar)` so content scrolls under it legibly.
- Label: `Text(UICopy.consentConfirm).frame(maxWidth: .infinity)`, then `.primaryAction()`. The
  old `.font(.title2)` and `.frame(maxWidth: .infinity, minHeight: 44)` are removed
  (`.controlSize(.large)` gives the height). Keep
  `.disabled(isBeginning || !model.library.isLoaded)`, the action body, `.accessibilityLabel` and
  `.accessibilityIdentifier("consentConfirm")` unchanged.
- The read-aloud callout (design review row 8): an `HStack(alignment: .firstTextBaseline)` with
  `Image(systemName: "quote.opening")` with `.foregroundStyle(.tint)` (accessibility-hidden) and the existing
  `Text(UICopy.readAloudCallout)` set in `.font(.title3)` with
  `.fontDesign(DesignTokens.questionFontDesign)`; background stays `.thinMaterial` in a
  `RoundedRectangle(cornerRadius: DesignTokens.Radius.card)`. It is never dismissed.

## Part 5 — Record button

New `RecordGlyph` in `StoryCue/RecorderPresentation.swift` (pure, no SwiftUI import):

```swift
enum RecordGlyph: Equatable { case dot, square, spinner, cancel }

extension RecorderPresentation.Primary {
    var glyph: RecordGlyph {
        switch self {
        case .record, .resume, .unavailable: .dot
        case .pause: .square
        case .saving: .spinner
        case .cancelCountdown: .cancel
        }
    }
}
```

New `StoryCue/Views/RecordButton.swift`: `struct RecordButton: View { let primary:
RecorderPresentation.Primary; let label: String; let action: () -> Void }`. Draws, in a
`DesignTokens.RecordButton.outer` square frame:

- a `Circle().fill(DesignTokens.overCameraFill)` backing, and on it a white
  `Circle().strokeBorder(.white, lineWidth: ringWidth)` ring (white, **not** the accent: it sits on
  the camera, and red/white is the universal record grammar; the dark backing keeps the ring at least
  3:1 over a bright feed);
- inside, by `primary.glyph`: `.dot` = red filled circle of `dot` diameter; `.square` = red
  `RoundedRectangle(cornerRadius: squareRadius)` of `square` side; `.spinner` = white
  `ProgressView().tint(.white)` (`foregroundStyle` does not color it); `.cancel` = `Image(systemName: "xmark")` in `.title2.bold()`, white, on
  `DesignTokens.overCameraFill` circle of `dot` diameter. The red is `Color.red` (system red).
- `.unavailable` shows the plain dot; the button is disabled for `.saving` and `.unavailable`
  (same rule as today) and `.disabled` does the dimming, nothing extra.
- Dot ↔ square morph, exactly: for `.dot` and `.square` draw ONE
  `RoundedRectangle(cornerRadius: glyph == .square ? squareRadius : dot / 2)` filled red, framed
  `glyph == .square ? square : dot` on both axes, with
  `.animation(reduceMotion ? nil : DesignTokens.Motion.morph, value: primary.glyph)` where
  `reduceMotion` is `@Environment(\.accessibilityReduceMotion)`.
- `RecordButton.body` is a `VStack(spacing: DesignTokens.Spacing.xs)`: the `Button` (its label is
  only the 72 pt drawing), then, OUTSIDE the button, `Text(label)` in `.footnote`, white, padded
  horizontally `Spacing.s` and vertically `Spacing.xs` on a `Capsule().fill(DesignTokens.overCameraFill)`,
  `.accessibilityHidden(true)` (the button already carries the label).
- The `Button` keeps `.accessibilityLabel(label)` and `.accessibilityIdentifier("recordButton")`;
  hit area is the whole 72 pt frame via `.contentShape(Circle())`.

`RecorderView.controlsRow` becomes three equal columns: `Color.clear` (leading spacer, max width),
`RecordButton(primary: p, label: primaryLabel(p), action: …)` (the existing switch moves into the
action closure unchanged), and the advance button. When
`@Environment(\.dynamicTypeSize).isAccessibilitySize` is true it is instead a `VStack` of the record
button then the advance button (no spacer column). The advance button keeps its action, label,
disabled rule and accessibility; its `.font(.title2)` becomes `.font(.body.weight(.semibold))`; its
label is `Text(advanceLabel(a))` in white, `.lineLimit(2)`, `.multilineTextAlignment(.center)`,
padded `Spacing.m` horizontally and `Spacing.s` vertically, on `Capsule().fill(DesignTokens.overCameraFill)`,
at least 44 pt tall, `.buttonStyle(.plain)`. No `.bordered`: a translucent white fill over a bright
feed fails 4.5:1.

## Part 6 — Haptics

Every haptic has a visible twin (house style rule 10). On `RecorderView`'s root:

| Haptic | Trigger | Visible twin |
|---|---|---|
| `.sensoryFeedback(.impact(weight: .medium), trigger: presentation.primary) { old, new in (old == .pause) != (new == .pause) }` | recording starts or stops | dot ↔ square morph |
| `.sensoryFeedback(.selection, trigger: store.state.questionIndex)` | question changes | new question text |

Completion `.success` in `SessionDetailView` is **unchanged** (S2c). No other haptics.

Do **not** call `AVAudioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)`: iOS mutes
haptics while the microphone is live, and allowing them would put the buzz into the recording's
audio. If the device check (part 10) shows these haptics are silent while the camera runs, that is
accepted: the visible twins carry the feedback.

## Part 7 — Deck tiles and teasers

- `UICopy`: `static func deckTeaser(_ deckID: String) -> String`, a `switch` with the five teasers
  below and `default: ""`. **Copy is Perry-eye, non-blocking**: ship these; he edits later in one
  place.

  | deck id | teaser |
  |---|---|
  | `grandparents` | Childhood, first jobs, and the years that shaped them |
  | `parents` | The day you were born, and what parenting taught them |
  | `kids` | Kids interview the grownups: toys, school, old fears |
  | `couples` | How you met, and the life you've built since |
  | `holiday-table` | Pass the phone around the table and take turns |

- `DesignTokens`: `static func deckSymbol(_ deckID: String) -> String`: `grandparents` →
  `"house"`, `parents` → `"figure.2.and.child.holdinghands"`, `kids` → `"questionmark.bubble"`,
  `couples` → `"heart"`, `holiday-table` → `"fork.knife"`, `default` → `"text.bubble"`.
- New `StoryCue/Views/DeckTile.swift`: `struct DeckTile: View { let deckID: String }`. The symbol in
  `DesignTokens.tileSymbol`, `.font(.title2)`, centered in a
  `RoundedRectangle(cornerRadius: DesignTokens.Radius.tile)` filled with `DesignTokens.tileFill`,
  side `min(side, 72)` where `@ScaledMetric(relativeTo: .title2) var side: CGFloat = 48`.
  `.accessibilityHidden(true)`. The tile-beside-or-above-text switch is one shared view in the same
  file, `struct DeckRowLabel<Detail: View>: View { let deckID: String; let title: String;
  @ViewBuilder let detail: Detail }`, used by both `DeckPickerView` and `LibraryView`.
- `DeckPickerView` row label: `DeckRowLabel(deckID: deck.id, title: deck.title) { teaser (.callout,
  .secondary) }`, which lays out `HStack(spacing: DesignTokens.Spacing.m) { DeckTile;
  VStack(alignment: .leading) { title (.title2); detail } }`. When
  `@Environment(\.dynamicTypeSize).isAccessibilitySize` is true, the tile goes **above** the text
  (`VStack(alignment: .leading)`) so the title keeps the full width. The row's
  `.accessibilityLabel` becomes `"\(deck.title), \(UICopy.deckTeaser(deck.id)), \(UICopy.questionCount(deck.questions.count))"`;
  identifier unchanged. The visible "10 questions" line is removed (deliberate, design review row 5;
  every deck has 10 and the count stays in the VoiceOver label). No `.accessibilityElement` change on
  the `NavigationLink`: it already combines its label, and `deck.<id>` must stay on it.
- Tests, new in `StoryCueTests/DeckDataTests.swift`: `testEveryDeckHasTeaser` (non-empty, ≤ 60
  characters, no trailing period, for every `Deck.v1Decks` id) and `testDeckSymbolsAreDistinct`
  (five distinct symbol names, none equal to the default).

## Part 8 — Serif trial

Apply `.fontDesign(DesignTokens.questionFontDesign)` to: the recorder's current question
`Text(store.currentQuestion.text)` and next-question preview; the consent read-aloud line (part 4);
the question text in `SessionDetailView` rows. Nothing else. Judged on the device screenshot; the
revert is the one token.

## Part 9 — Library, empty state, session header

- **Library session row** (`LibraryView.sessionRow`): label is `DeckRowLabel(deckID:
  record.deckID, title: record.deckTitle) { Text(UICopy.sessionSubtitle(record.startedAt, count:
  record.manifest.count)) (.callout, .secondary) }`. No `.accessibilityElement` modifier; the
  `session.<deckID>` identifier and swipe actions stay on the `NavigationLink` unchanged.
  New `UICopy.sessionSubtitle(_ date: Date, count: Int) -> String` =
  `"\(date.formatted(.dateTime.month(.abbreviated).day())) · \(clipCount(count))"`.
- **Empty state**: `ContentUnavailableView { Label(UICopy.libraryEmptyTitle, systemImage:
  "video.slash") } description: { Text(UICopy.libraryEmptyBody) } actions: { Button(UICopy.
  libraryEmptyAction) { dismiss() }.primaryAction() }`. `LibraryView` gains
  `@Environment(\.dismiss)`; the library is always pushed from the deck picker, so dismiss returns
  there. Copy: `libraryEmptyBody` becomes "Your conversations will show up here." and new
  `libraryEmptyAction = "Choose a deck"` (Perry-eye, non-blocking).
- **Session header** (`SessionDetailView`): when `showsCompletion` is false, the first section's
  header shows `UICopy.sessionSummary(record.startedAt, count: record.manifest.count)` in
  `.subheadline`, `.secondary`, `.textCase(nil)`; new `UICopy.sessionSummary` =
  `"\(date.formatted(date: .long, time: .shortened)) · \(clipCount(count))"`. When
  `showsCompletion` is true the S2c completion header is unchanged (including no header at all
  when `manifest.count == 0`; intended). The play button picks up the
  accent automatically; nothing else on this screen changes.
- **Storage banner**: unchanged.

## Part 10 — Accessibility gate and screenshots

- DEBUG-only launch arguments in `StoryCueApp.swift`, read next to the existing `-StoryCueDemo`
  check and applied to `RootView` inside `#if DEBUG`:
  `-StoryCueDark` and `-StoryCueAX5`, read into two `static let` Bools on `StoryCueApp`, applied as
  `.preferredColorScheme(isDark ? .dark : nil)` and, only when `isAX5`,
  `.dynamicTypeSize(.accessibility5)` through a small `ViewModifier` (there is no optional overload;
  do not force a size on other DEBUG launches). Release builds compile neither.
- `ScreenshotTests`: the existing method is untouched. Add two methods, each with its own fresh
  `XCUIApplication`: `testCaptureDarkScreenshots` (`["-StoryCueDemo", "-StoryCueDark"]`, capturing
  `dark-01-decks`, `dark-02-consent`, `dark-03-recorder`) and `testCaptureAX5Screenshots`
  (`["-StoryCueDemo", "-StoryCueAX5"]`, capturing `ax5-01-decks`, `ax5-02-consent`,
  `ax5-03-recorder`). Same anchors, `waitForScreen` and attachment helper as the existing method.
- `.github/workflows/screenshots.yml`: the existing `xcodebuild test` step gains
  `-only-testing:StoryCueUITests/ScreenshotTests/testCaptureAppStoreScreenshots`, so a review-shot
  failure can't cost the ASC set; the existing export/rename step, its `expected` list and the 5-PNG
  check on `shots/` are unchanged. After the ASC upload, add separate steps with
  `continue-on-error: true` that run the two new methods (`-only-testing` each, own
  `-resultBundlePath "$RUNNER_TEMP/review.xcresult"`), export its attachments to
  `$RUNNER_TEMP/review-raw`, copy files whose suggested name starts with one of the six names into
  `$RUNNER_TEMP/review/` (same manifest walk as the existing step), and upload that as artifact
  `review-screenshots` (`if-no-files-found: warn`). They must never land in the `asc-screenshots-6.9` set.
- **Boss eyeball on the PNGs** (one bounded fix round): dark-mode primary button label is dark on
  terracotta; AX5 consent button stays on screen and nothing clips; recorder controls stay visible
  at AX5; deck tiles stack above titles at AX5.
- **Device checks (Perry, next TestFlight):** Reduce Motion on → the record morph is instant;
  VoiceOver: deck rows read title, teaser, count; record button reads its label and state; serif
  reads well over the camera; whether recorder haptics fire with the camera live (silent is
  accepted).

## Acceptance

1. CI `build.yml` green, all existing tests plus `StyleLintTests` (5) and the two new
   `DeckDataTests` pass.
2. `screenshots.yml` green: the five ASC PNGs plus six review PNGs.
3. Diff touches only: `project.yml`, `Assets.xcassets/{AccentColor,OnAccent}.colorset`,
   `DesignTokens.swift`, `RecorderPresentation.swift` (the `RecordGlyph` addition only), `UICopy.swift`,
   `StoryCueApp.swift`, `Views/AnswerPlayerView.swift` (the one radius token), `Views/{ConsentView,DeckPickerView,LibraryView,RecorderView,
   SessionDetailView,RecordButton,DeckTile}.swift`, `StyleLintTests.swift`, `DeckDataTests.swift`, `RecorderPresentationTests.swift`, `ScreenshotTests.swift`,
   `screenshots.yml`. Anything else is a rejection.
4. Add one test to `RecorderPresentationTests`: `testGlyphMapping` covering all six `Primary` cases.

## Spec review

Sonnet 5.5 reviewed this spec 2026-10-04 (fresh context, read the touched sources): 17 findings,
0 compile-breakers. Accepted and folded in: advance button contrast and AX5 stacking (high), label
and ring backing, exact morph, spinner tint, no `.combine` on rows (anchors), launch-arg modifier
form, separate review-shot steps so the ASC set can't be lost, literal colorset JSON, the 5.7:1
correction, consent font removal, tile cap and shared `DeckRowLabel`, no double dimming. Noted as
intended: empty completion header at 0 clips, visible question count removed.
