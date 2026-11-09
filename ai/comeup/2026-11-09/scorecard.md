# comeup scorecard: StoryCue (store name Tellfolk), 2026-11-09

Reviewers held: Sonnet, Kimi, Sol (account pmartin1913). Adjudication: `adjudication.md` (26 findings: 15 accepted and shipped, 4 rejected, 7 deferred). Perry's veteran picks: V1-V5 (V6, V7 deferred).

| Dimension | Before | After | Notes |
|---|---|---|---|
| 1 Motion and fluidity | 3.0 | 3.3 | Countdown digits roll (numericText), caption uses the fade token, one Haptics catalog with a lint rule. No hitch metric yet |
| 2 State clarity | 2.7 | 3.5 | Player waits for item readiness and names failures; export success vs failure + Try again; loading cues; "Nothing was saved."; toasts after keep/delete. Share-cancel-reads-as-success (C5) deferred |
| 3 Input robustness | 2.7 | 2.9 | Audio-session failure now has a message. Disk-full in recorder (C22), camera retry (C23), audio after playback (C24) deferred |
| 4 Accessibility | 2.3 | 3.0 | VoiceOver hears countdown, recording start, banners, cap warning, toasts; recorder hidden under blocking overlay; player readable in light mode; Apple's audit now runs in CI. Dynamic Type caps (C21) deferred; audit flags open (below) |
| 5 Visual system | 3.0 | 3.3 | primaryAction + spacing tokens on export; recording pill no longer truncates; amber cap state tokenised |
| 6 Performance | 2.0 | 2.3 | First baseline only (CI simulator, see M7). Not representative of device |
| 7 Copy | 3.3 | 3.5 | "clip" -> "answer"; cap and nothing-saved lines |
| 8 Layout resilience | 3.0 | 3.2 | Blocking overlay scrolls at AX5; AX5 reachability test passes (Record, Done hittable, card clear of Record) |

Before = mean of the three seats' scores (Sol's copy deduction partly rested on a packet ASCII artifact, C17). After = Opus re-score from the CI review screenshots and UI tests below; no device was used.

## Shipped (all merged to main with `--merge`, CI green, `reviewer` agent clean before each commit)
- #19 playback and export state clarity (C1-C4, C6-C8) - merge `8f78c92`
- #20 recorder accessibility and loading clarity (C9-C14) - merge `acc0891`
- #21 harness: launch metric, accessibility audit, AX5 reachability (C15, C16) - merge `6c07398`
- #22 Perry's veteran picks V1-V5, plus two defects the review shots found: recording pill truncated to "Recordi..." (pre-existing), toast capsule invisible on light screens; harness fixes - merge `cecd196`

None of this is in the build in review (1.0, publish 11-16); it lands in the next version.

## Rejected
C17 packet artifact (U+00B7 folded to "?"), C18 edge-swipe pop (hiding the back button disables it), C19 haptics in the take (iOS silences them while recording), C20 Keep/Delete double-tap (Library.keep/discard are idempotent).

## Deferred (also in `ai/IDEAS.md`)
C5 share-sheet cancel, C21 Dynamic Type caps, C22 disk-full banner, C23 camera retry, C24 audio after playback, C25 remaining style literals, C26 per-render ExportModel; probes M4 (no crash reporting) and M1 (main not protected); V6 recovery screen, V7 spoken countdown.

## Harness (how Claude exercised each change)
`StoryCueUITests/ComeupReviewTests` runs in the screenshots workflow's review step; every `comeup-*` attachment is exported to the `review-screenshots` artifact. Read by Opus:
- comeup-01 player unavailable, light mode: text, Done and caption readable on black (C1)
- comeup-02 export sheet: primary button style (C7); found the bordered button taller, fixed in #22
- comeup-03/04 countdown roll and recording state (C13); found the pill truncation, fixed in #22 and re-shot whole
- comeup-05 AX5 recorder: Record and Done reachable; the first overlap assertion was a false positive (scroll content frame), fixed
- comeup-06 "Nothing was saved." toast (V2); capsule too faint, fixed in #22
- comeup-06/07 after the capsule fix: "Nothing was saved." and "Recording deleted" read as dark capsules; delete returns to Recordings with the session gone (V2, V4). The first comeup-07 run hit a simulator launch failure, the next run passed
- Unit: ExportModel.retry, RecorderPresentation.nearsCap (V1, which a UI run cannot reach: it needs 9 minutes of recording), AppModel nothing-saved toast, Haptics lint

## Measured probes after this pass
- M6: `performAccessibilityAudit` now runs (deck picker, consent, recorder). Open flags, each with element label in the log: recorder white-on-70%-black text flagged "contrast failed" (HOUSE-STYLE measures it >= 7:1; likely the audit sampling the translucent backing, needs a device look); deck teaser `.secondary` "nearly passed"; Recordings toolbar button flagged while disabled; recorder Dynamic Type "partially unsupported" (the C21 caps) and the question title "text clipped" at default size. These are next-pass inputs, not fixed here.
- M7: launch-to-deck-picker on the CI simulator 14.9 / 14.2 / 11.9 s. That includes XCUITest launch and attach on a shared runner; it is a regression baseline only, not the < 2 s device target.
- M8: review tests now assert, but the step is still continue-on-error (existing IDEAS 2026-10-04 item).

Next: Perry checks the next TestFlight build on a phone (amber pill at 9 min, toasts, VoiceOver countdown); a second comeup pass takes the audit flags and C21.
