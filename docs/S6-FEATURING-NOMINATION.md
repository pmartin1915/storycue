# S6 — App Store featuring nomination (draft)

_Drafted 2026-10-04 against main `58f0e9e`. Opus drafts; Perry edits and files it in App Store
Connect → Featuring Nominations. Form fields were taken from Apple's help page
("Nominate your app for featuring", read 2026-10-04), not from memory._

## Read this first: two decisions are built into this draft

1. **The Duo angle stays out of this nomination.** 1.0 is the single-screen recorder (PLAN §5;
   STATE S8/S9). The outer-display feature does not exist in a shipping build and has never run on
   a Duo. Nominating it now would promise an editor something 1.0 can't show. That gets its own
   **App Enhancements** nomination once 1.1 is real (see the last section).
2. **The publish window is Thanksgiving, not launch day.** Apple now recommends **3 weeks** of
   lead time, up from the 2 weeks PLAN §6 assumed. Launch day, 10-23, is already under 3 weeks
   away. Thanksgiving week is 6 weeks out, and it is the moment the app is actually for.

**File it by ~10-09** (STRATEGY S6 date). That gives about 5½ weeks before the window opens.
The draft can be saved without submitting it. Once it is submitted, the type can't be changed.

## Form fields

**Nomination Name** (internal only):
`StoryCue launch: record your family this Thanksgiving`

**Nomination Type**: **App Launch**

**Description**:
> StoryCue is a new app for recording the people you love telling their stories. Pick a question
> deck (Grandparents, Parents, Kids Ask the Grownups, Couples, or Holiday Table), prop up your
> iPhone, and record the answers one question at a time. A large-type question card stays on
> screen while you film. Before recording, everyone reads a consent card aloud together.
>
> It's built for the real conversations that happen when families get together. Pause and resume
> join into one answer. If a phone call or a crash interrupts an answer,
> StoryCue finds the recording the next time you open the app. Export a whole session as one video, or one video per
> answer, to Photos or Files.
>
> Every question is written for the app to draw out a story, not a one-word fact: "What did
> your childhood kitchen smell like, and who was cooking?" "What do you remember about the day
> I was born?"
>
> Recordings stay on the iPhone until you export them. StoryCue has no account, no cloud, no
> ads, no tracking, and no network requests at all. Its privacy label is Data Not Collected.
>
> StoryCue launches in late October. We're nominating it for Thanksgiving week, when families
> sit down together and many people decide this is the year to record a grandparent.

**Publish Date/Timeframe**: custom range **2026-11-16 → 2026-11-29** (the week before
Thanksgiving, which is 11-26, through the holiday weekend).

## Additional information

| Field | Value |
|---|---|
| Related Apps | none |
| Platforms | iOS (iPhone only; `TARGETED_DEVICE_FAMILY` is 1) |
| Countries or Regions | keep the pre-selected list. The pitch is US Thanksgiving, but the app works everywhere |
| Localizations | English (U.S.), pre-selected |
| In-App Events | none |
| Supplemental Materials | see below |

**Supplemental Materials** (up to 5 URLs):
1. `https://martinapps.dev/storycue/privacy-policy.html` (live only after `storycue-pages` merges)
2. `https://martinapps.dev/storycue/support.html` (same)
3. Optional: a TestFlight **public** link. That needs an External Testing group, and that group
   needs Beta App Review. Skip it unless Perry wants external testers anyway.
4. Strongly recommended: the 15-second clip from PLAN §6 if one exists, as an unlisted link. Apple says
   editors weigh "polished previews". A real-family clip shot on Perry's 16 Pro would work. It
   doesn't need a Duo for this nomination.

**Helpful Details**:
> StoryCue is made by a one-person studio. [PERRY: one or two sentences on why you built
> it, in your own words, or delete this paragraph.]
>
> Accessibility: the question on the recorder scales through every accessibility text size, and
> the deck and export layouts restack at those sizes. Motion respects Reduce Motion. The record
> controls are labeled for VoiceOver. Question type is large enough to read at arm's length, so
> older relatives can follow along.
>
> Privacy is the design, not a setting. No account, no network code, no third-party SDKs, and
> recordings live only on the device until the user exports them. The consent card makes
> asking permission part of the ritual.

## Check before filing

- [ ] **Write the "why I built it" lines first.** A Sonnet review (2026-10-04) rated them the
      strongest editorial asset in the form. Kimi was out of weekly quota, so Kimi did not review.

- [ ] **Placeholder rules.** Only Perry can write it, so the draft doesn't invent a reason. If
      it mentions nursing, keep credentials out: no "FNP-C" before Alabama
      licensure (LIVING).
- [ ] **Accessibility claims.** They match the code as of `58f0e9e`: `dynamicTypeSize`
      branches in `DeckTile`, `ExportView` and `RecorderView`; `accessibilityReduceMotion` in
      `RecordButton` and `AnswerPlayerView`. The question text scales to AX5; the control
      labels under it cap at AX2 (`RecorderView.swift:277`), which is why the text says
      "question" and not "everything". VoiceOver labels are sparse (about 8), so the text claims
      only the record controls. Do one large-text run on the device before filing.
- [ ] **Pricing.** Apple's featuring page says editors favor freemium. The text above says
      nothing about price, so it holds whichever way the pricing decision goes.
- [ ] The privacy and support URLs resolve (merge `storycue-pages` first).

## Second nomination, later: iPhone Duo (App Enhancements)

File it when 1.1 (the outer-display question card) has a build ASC accepts. The earliest
realistic window is "27.1 submissions open" (~10-23, PROMPT-A). Use the remaining 3-week lead
time to aim for early December, or to aim at holiday gift season. Pitch, one sentence:

> With iPhone Duo, the person being interviewed reads the question on the outer display while
> the interviewer films from the inner one, so two people, two screens, and one story.

**What the listing may claim is bounded by the highest test rung passed** (PLAN §5). Without
rung-5 (real Duo) evidence, say "designed for iPhone Duo", never "tested on". Attach the
hardware-only clip from PLAN §6 if anyone has shot one.
