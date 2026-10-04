# StoryCue design review — 2026-10-03

Asked by Perry after the S5 device pass: "all the most popular apps have a certain look and feel
to them that I want to emulate", across his apps. Reviewer: **Sonnet 5.5** (fresh context, read the
five `asc-screenshots-6.9` PNGs from screenshots run `37086951621` plus `StoryCue/Views/*`). Opus
adjudicated it. Perry also decided at the same time that **1.0 gets in-app playback**.

## Sonnet's verdict (summary)

About 4 out of 10 against "top App Store app": clean, trustworthy and readable, but it looks like
an unstyled template. There's no accent color of its own (system blue everywhere), and the main
actions ("We're ready", "Record") are bare blue words, not buttons. The app has zero haptics, one SF
Symbol and no end-of-flow moment. What top apps share is not a look to copy but **one strong
accent, one hero action per screen, and tactile feedback**.

## Sonnet's suggestions, with Opus adjudication

| # | Suggestion | Sonnet | Opus |
|---|---|---|---|
| 1 | One warm accent color as `AccentColor` (amber/terracotta, from the recorder's brown) | 1.0 | **Accept.** Biggest change for least work. Perry picks the color |
| 2 | Filled, full-width primary button pinned at the bottom (`borderedProminent`, `.large`, `safeAreaInset`) on Consent | 1.0 | **Accept** |
| 3 | Real record button: 72 pt ring, red center that morphs circle→square while recording; Skip secondary | 1.0 | **Accept.** Keep the 44 pt+ target and the existing VoiceOver labels |
| 4 | Haptics: record start/stop, save success, question change (`.sensoryFeedback`) | 1.0 | **Accept** |
| 5 | Deck rows: colored SF Symbol tile + a one-line teaser in place of "10 questions" | 1.0 | **Accept.** Teaser copy lives in `UICopy`/`Decks.swift` and needs Perry's eye |
| 6 | Serif (`.fontDesign(.serif)`) for questions and the consent line | 1.0 | **Accept, trial.** Taste call: judge it on a device screenshot before committing |
| 7 | Recorder question card on `.ultraThinMaterial` instead of dark boxes | 1.0 | **Defer to device.** A light material over a busy live camera can hurt readability; the dark card was a deliberate legibility choice. Try on the 16 Pro, keep whichever reads better |
| 8 | Restyle the consent reminder strip; dismiss it after consent is read | 1.0 | **Restyle yes (icon, not error-looking); don't auto-dismiss.** The app can't know the line was read |
| 9 | Library rows: thumbnail or deck tile, duration, shorter/relative date | 1.0 | **Deck tile + shorter date in 1.0; thumbnails and duration LATER** (needs `AVAssetImageGenerator` and per-file reads) |
| 10 | Session detail: header summary, play glyph per answer, destructive Delete in a footer | 1.0 | **Accept** (comes with playback) |
| 11 | In-app playback: tap an answer → `fullScreenCover` system player, question as caption, autoplay, swipe-down dismiss, playback audio category, friendly missing-file state | 1.0 | **Accept.** Perry said yes. Use the system player, no custom controls |
| 12 | Next/previous answer inside the player | 1.0 if cheap | **LATER** unless it falls out free |
| 13 | Completion screen after a session ("You recorded N answers", success haptic, "Watch them") | 1.0 | **Accept, merged with Opus's Done rec:** Done with ≥1 clip opens that session's detail; with 0 clips, back to the deck list |
| 14 | Empty library state gets a "Pick a deck" button + warmer copy | 1.0 | **Accept** (small) |
| 15 | "Play all" reel with title cards between answers | LATER | **LATER** — the real delight feature, post-1.0 |
| 16 | First-run intro cards; library grouping; swipe-delete | LATER | **LATER.** Swipe-delete was deliberately removed in S2b (no full-swipe without confirm) |

## Opus additions

- **Split into two dispatches so playback can't be held up by polish:** **S2c** = playback +
  Done→session detail + completion state (function); **S2d** = the visual pass (rows 1–6, 8, 9a,
  10, 14). Both go through `/orchestrate`; S2d gets a boss eyeball on rendered screenshots (the
  screenshots workflow already exists) with one bounded fix round.
- **Screenshots get re-shot after S2d.** The S6 set captured today is pre-polish.
- **Schedule:** S8 submit target is 10-16. S2c is maybe 1–2 days and S2d 2–3; it fits, but S2d is the
  first thing to cut if the S7 Xcode check (10-10) goes badly.

## House style

Sonnet's 12-rule "Martin Apps house style" draft is filed as a cross-project idea in
`dev-ops/ai/IDEAS.md` (2026-10-03). Plan: build it in StoryCue first, then extract it as a small
Swift package after 1.0 ships, using StoryCue's final tokens as the seed.
