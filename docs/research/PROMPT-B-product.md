# Gemini Deep Research prompt — a family-interview video recorder with a subject-facing prompt screen

> **Paste everything between the rules into Gemini Deep Research.** Gemini doesn't have file access; the prompt is fully self-contained. Drop the report back beside this file as `PROMPT-B-product-REPORT.md`; a Claude session adjudicates it into a synthesis.

---

## Background

I am a solo developer building a small, offline, no-account iOS app that launches with
Apple's iPhone Duo on 2026-10-23. The mechanic: one person films a relative with the
phone open; the relative reads an interview question off the phone's outer display
(large type, a "recording" indicator, a short countdown), answers on camera, and the clip
is saved locally. Decks of questions for grandparents, parents, children interviewing
adults, couples, and a round-the-table holiday set. Nothing leaves the device; no cloud,
no transcription, no subscription in version 1. The first marketing moment is US
Thanksgiving, 2026-11-26.

Today is 2026-09-18. I have five weeks. I need the product decisions grounded, not the
code.

## What I need you to research

Answer each numbered question separately. Cite sources with dates. Mark each answer
High / Medium / Low confidence. "Unknown" is an acceptable answer; a guess is not.

### 1. Competitive landscape (as of September 2026)
For each of: StoryCorps app, Remento, Storyworth, Memoirji, Tell Mel, VoiceWeave,
Simirity, Life Story / Storii, Saga, and any others you find that record family stories
on a phone:
- Mechanic (text prompts by email? voice? video? who holds the phone?), platform, pricing
  model and current prices, whether recordings leave the device, App Store rating and
  review count, and last update date.
- Does ANY of them show the prompt to the person being recorded on a second screen, a
  second device, or a mirrored view? (I believe none do; confirm or refute.)
- What their negative reviews complain about most — this is my feature list.

### 2. What makes an interview question produce a story
- Evidence from oral-history practice (StoryCorps "Great Questions", Library of Congress
  Veterans History Project, Baylor Institute for Oral History, Smithsonian Folklife,
  narrative-gerontology research) on question forms that elicit narrative rather than
  facts, and on ordering (warm-up, depth, closing).
- Recommended session length and clip length for an elderly narrator before fatigue.
- **Licensing of existing question sets**: which published lists are public domain, CC,
  or proprietary? Can a commercial app ship StoryCorps's questions verbatim? What about
  the Veterans History Project's field kit questions (US federal work → public domain?).

### 3. Recording-consent and children
- US one-party vs all-party consent states as they apply to **in-person video where every
  participant can see the camera and a "Recording" indicator**. Is an in-app consent
  card at session start sufficient, and what wording do lawyers recommend for a consumer
  app? Note any state (California, Illinois, Washington, others) with quirks for video vs
  audio.
- Recording minors: parental-consent expectations when a child is the *subject* of a
  family video (not a user of the app). Does an app that records children in the home
  fall under COPPA if it has no accounts and no data collection? Under Apple's Kids
  Category rules if it is NOT in the Kids Category?
- App Store Review Guidelines sections that apply (5.1.1 data collection, 5.1.2 data
  use, camera/mic purpose strings, privacy manifest `PrivacyInfo.xcprivacy`
  requirements for an app that stores video locally only).
- GDPR/UK considerations if the app is sold outside the US but stores nothing server-side.

### 4. Holiday campaign patterns for a zero-budget launch
- StoryCorps's "Great Thanksgiving Listen": how it is run, its numbers, partners, and
  whether an independent app could align with or ride it without infringing.
- Other November/December "record your family" campaigns and what channels they use.
- What a solo developer with no ad budget has done successfully in the 4–6 weeks around a
  hardware launch: press outreach templates, Product Hunt, Reddit communities
  (r/genealogy, r/Genealogy, r/Parenting, r/eldercare), TikTok/Reels clip formats, the
  "one 10-second video" pattern. Give concrete examples with outcomes.

### 5. Monetization
- Current App Store norms for a small utility launched with new hardware: free, paid up
  front ($2.99–$9.99), free + one-time unlock, free + paid decks. Cite comparable apps
  and whatever revenue data is public (Sensor Tower estimates, indie dev write-ups).
- Evidence on whether "paid up front" hurts featuring odds.
- Constraint to respect: no server, no subscription infrastructure in v1.

### 6. Reading at arm's length on a 5.4-inch display
- Human-factors evidence for type size, contrast, line length, and font choice for an
  older adult reading a phone-sized display held 1–2 metres away (Apple HIG large-type
  guidance, WCAG, gerontology/vision research, teleprompter industry conventions).
- Countdown and "recording" cues that reduce anxiety for non-performers (teleprompter and
  broadcast practice).
- Any evidence that showing the *next* question in advance helps or hurts narrators.

### 7. Name check
Working name is "StoryCue". Check App Store, USPTO TESS, and web for conflicts, and
propose five alternatives that are short, spellable, and not taken on the App Store.

## Output format

A report with one section per question, an executive summary listing the ten decisions
this research changes, a table of prices/plans for every competitor, a table of legal
citations (statute, state, what it requires), and a "what I could not find" list. Prefer
primary sources: statutes, Apple's own documents, the organisations' own pages.
