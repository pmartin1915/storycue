# Handoff 2026-09-22 (icon glyph: reconstructed, built, committed)

Continues from `docs/HANDOFF-2026-09-22-coverage-and-icon.md` (coverage pass +
Duo SDK finding + icon prompts, `c7c26cf`). That handoff explicitly flagged the
icon prompts were never saved to a file. This session closed that loop.

## What this session did

**1. Reconstructed the four Gemini prompts from `BRAND.md` + the prior handoff's
paragraph** (the chat that generated them originally had been cleared, and they
were never written to disk -- exactly the gap the prior handoff warned about).
Not a verbatim recovery, a rebuild from the same brand constraints and the four
named concepts (Quote-wave, Cue card, Nested arcs, Story path + play).

**2. Perry ran all four on Gemini and picked Quote-wave**, matching his stated
lean from the prior session. Reviewed all four against `BRAND.md`'s actual rules
(stroke-only, no container in the glyph file, dark-ink container, rust accent,
safe-circle geometry) before he decided -- Cue card and Story-path both had real
defects (generic file-icon drift, filled arrowhead, wrong-background preview);
Quote-wave was the only one that was both on-concept and technically clean.

**3. Hand-authored `brand/marks/apps/storycue.svg`, iterating on rendered output
rather than declaring success on the first geometrically-valid pass.** Three
rounds, each actually rendered via `gen-icons.mjs` + `check-icons.mjs` and looked
at (1024px and 192px), not just checked against the numeric safe-radius gate:
- Round 1 (open arc + zigzag crossing through the loop's mouth): passed the gate,
  looked like an unreadable tangle. Rejected on sight, not shipped.
- Round 2 (closed circle + small zigzag crossing the middle): passed the gate,
  read as a magnifying glass / lollipop, not a quote mark. Rejected on sight.
- Round 3 (closed loop + comma tail + EKG-style zigzag trailing off the loop's
  *outer edge*, no overlap with the loop body): reads cleanly as "spoken word
  opening into a soundwave" at both preview sizes. This is what shipped.

**4. Gated, committed, pushed.** `check-icons.mjs` clean: iOS 1024 opaque with no
baked corner radius, Android adaptive foreground at 92% of the 66dp safe circle,
distinct maskable/plain PWA variants, all 18 iOS slots present and named. Rust
`#E0935F` (dark-theme accent value, correct per `BRAND.md`'s "container is dark
ink in both themes" rule). Committed in `brand` as `e8a29f6` ("brand: StoryCue
joins the outdoor/life line"), pushed clean (no divergence, fast-forward).

## What's next

- **The generated icon set is not wired into the StoryCue Xcode project yet.**
  `StoryCue/Assets.xcassets/AppIcon.appiconset/Contents.json` is still the
  Xcode-default single-universal-slot placeholder with no image files. The real
  output lives in `brand/dist/icons/apps/storycue/ios/AppIcon.appiconset/`
  (18 slots + `Contents.json`, regenerate anytime with
  `node scripts/gen-icons.mjs --app storycue` from `brand/`). Copying that
  appiconset into the app and wiring `project.yml`'s asset catalog reference is
  the remaining step -- small, mechanical, not done this session because it
  wasn't asked for.
- `brand`'s `npm run check` (contrast + drift gate) was not run this session --
  glyph-only change, contrast doesn't apply to a new per-app SVG, but not
  independently confirmed. Worth a quick run before the next `brand` rollout.
- 2026-10-10 pivot check (plan section 5) still needs Perry's re-read against
  the Duo-SDK-availability fact from the prior session -- untouched by this one.

## Do not (unchanged from prior handoffs, still true)

- Don't implement Duo-path code -- still week 2's scoping decision.
- Don't widen `deploy.yml`'s secret set or run it -- App ID/profile/ASC record
  don't exist yet.
- Don't reopen the name, no-hardware, or v1-display-only decisions.
- No AI attribution trailers on any commit (`brand` or `storycue`).

## Verification for the next session to trust this handoff

- `git -C ../brand log --oneline -1` shows `e8a29f6 brand: StoryCue joins the
  outdoor/life line`, and `git -C ../brand status -sb` shows `main` even with
  `origin/main` (pushed, not just committed).
- `brand/marks/apps/storycue.svg` exists: 44 viewBox, three `<path>` elements,
  `stroke="#E0935F"`, no `<rect>`/container, no `fill` other than `none`.
- `ai/STATE.md`'s "What's Done" carries the icon entry; "What's Next" no longer
  lists the icon as pending-on-Perry.
- No file under `StoryCue/Assets.xcassets/AppIcon.appiconset/` besides
  `Contents.json` yet -- confirms the Xcode-wiring step above is genuinely still
  open, not silently done.
