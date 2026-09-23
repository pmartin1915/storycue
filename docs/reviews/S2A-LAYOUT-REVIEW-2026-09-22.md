# S2a layout review — Kimi, 2026-09-22

Kimi `--implement` in a throwaway detached worktree at `ddc0f25`, checklist-only (no edits).
Checks 2 (44 pt targets: `.frame` is on the `Button` in all four files) and 4 (no fixed geometry)
found nothing.

| # | Finding | Verdict | Action |
|---|---|---|---|
| 1 | High: at AX5 on a 667 pt screen the question panel + timer + banner + controls exceed the height; `Spacer(minLength: 0)` collapses and the controls go off screen | accept | Question panel in a `ScrollView`; controls stay pinned (`f3f7796`) |
| 2 | High: `.secondary` (translucent gray) on the 0.6-black backing over a bright feed falls to ~1.5–2.5:1 | accept | `.white.opacity(0.85)` for the counter and next-question preview |
| 3 | High: hiding the back button doesn't stop the edge-swipe pop, so a live recording could be abandoned | reject | In SwiftUI, `navigationBarBackButtonHidden(true)` also disables the interactive pop gesture (widely reported as a side effect). Stays on the S5 device checklist to confirm on hardware |
| 4 | Low: the "≥7:1" comment is wrong (worst case ~5.7:1, still passes) | accept | Comment reworded |
