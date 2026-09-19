# StoryCue

Family-interview video recorder for iPhone Duo: the person being filmed reads the
question off the outer display while the filmer holds the recording UI on the inner
display. Native SwiftUI, XcodeGen, built and shipped from GitHub Actions (`macos-27`).
Nothing leaves the device.

- **Plan and decisions:** `docs/PLAN.md` (canonical since 2026-09-19; the dev-ops copy is the
  historical record)
- **Handoff for agents:** `ai/STATE.md` first, then the latest dated file in `docs/HANDOFF-*.md`
  (currently `docs/HANDOFF-2026-09-19-sol-review-and-synthesis.md`). Decisions of record:
  `docs/HANDOFF-2026-09-18.md`.
- **Research:** prompts in `docs/research/`, Gemini reports land beside them as `*-REPORT.md`,
  Apple Tech Talk transcripts in `docs/techtalks/<id>-<slug>.md`
- **Reviews:** cross-model reviews of the plan and diffs, adjudicated, in `docs/reviews/`

Bundle id `dev.pmartin1915.storycue`. Pipeline pattern: `pmartin1915/shortless-ios`.
Ship target: iPhone Duo launch, 2026-10-23.
