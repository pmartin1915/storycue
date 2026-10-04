# Handoff 2026-10-04 -- S2d PR green, PR #8 audit says do not merge

<!-- READ-FIRST:START -->
**State:** S2d visual pass is PR #10 (`s2d`, head `b76980d`), CI 246/246 + screenshots green, boss-eyeballed (dark + AX5 review shots OK). Spec `docs/S2D-VISUAL-SPEC.md` (`08961e7`). PR #8 storage sweep rebased (head `acc600e`); Sol data-loss audit = **DO NOT MERGE** (1 high, 2 med, PR comment). STATE updated.
**Next:** 1. On Perry's go: squash-merge PR #10, deploy TestFlight, Perry device checks (Reduce Motion, VoiceOver, haptics with camera live, serif, teaser copy), re-shoot ASC set. 2. Fix PR #8's 3 findings (spec a small fix, executor, Sol re-check). The high one (`fileSize ?? 0` in `Library.load` step 4) is on main too, so fix it there as well. 3. S6 (privacy policy, metadata).
**Waiting on Perry:** go on PR #10; the 4 playback checks on build 8.1; incoming-call test.
**In flight:** PR #10 (green, unmerged); PR #8 (CI was still pending on `acc600e` at handoff; blocked by audit anyway). Worktrees `.orchestrate/wt/s2d` and `.orchestrate/wt/pr8` (both pushed, safe to remove). Stale remote branches s1-impl..s2c harmless.
**Traps:** Kimi was at its 5h cap on 10-04 (Sol did S2d). Never buy Kimi extra usage (Money Rule). No local Swift compiler. `.orchestrate/` stays untracked. Repo is PUBLIC.
<!-- READ-FIRST:END -->

## Detail

### S2d (PR #10)
- Spec `docs/S2D-VISUAL-SPEC.md`, Sonnet spec review (17 findings, all high/med folded in; see its "Spec review" section).
- Kimi run died at step 1 (403, 5-hour limit; its error offered paid extra usage, declined). Sol implemented via `codex-exec.sh --implement`, final message `.orchestrate/logs/20261004T065351Z-sol-implement.final.txt`.
- Boss review: diff stayed inside the spec's Acceptance item 3 allowlist; no data-loss/capture code touched.
- CI first try: build run `37184964943` 246/246; screenshots run `37184964916`. Fix commit `b76980d`: AX5 recorder controls stayed stacked and squeezed the question to ~3 visible lines; now side by side with labels capped at AX2 (question still scales fully and scrolls). Re-run `37185794134` green, AX5 recorder shows 5 lines.
- Review artifact `review-screenshots` (dark-01..03, ax5-01..03) is separate from `asc-screenshots-6.9`; its steps are continue-on-error.
- Device checks still owed after merge: Reduce Motion (morph instant), VoiceOver on deck rows + record button, whether recorder haptics fire while the mic is live (silent is accepted), serif over camera, Perry's eye on the 5 teasers and empty-library copy (`UICopy.deckTeaser`, `libraryEmptyBody`, `libraryEmptyAction`).
- Material question card over the camera (design review row 7) is still deferred to device.

### PR #8 (storage sweep)
- Perry said "go on PR8" 10-04. Rebased onto main: code commits clean, only `ai/STATE.md`/`ai/IDEAS.md` conflicted (resolved: main's text plus the PR's ADDRESSED markers and its STATE bullet). Force-pushed with lease from `03aa510` to `acc600e`.
- Sol audit prompt `.orchestrate/audit-pr8.md`, verdict `.orchestrate/logs/20261004T074848Z-sol-implement.final.txt`, posted as PR comment 5977891977:
  1. High, `Library.swift:126`: `(fileSize(url) ?? 0) > 0` treats unreadable as empty, so an undecided segment with bytes becomes `.failed(kept:false)` and the sweep deletes it. Boss-confirmed. The same line is on main (main only hides the clip, it doesn't delete). Fix: tri-state file state (missing / size / unreadable), never relabel or delete on unreadable.
  2. Medium, `removeFiles` (`:226`): `try?` on remove, then a failing stat reads as gone, so the ledger entry is dropped for a surviving file. Fix: gone only on success or positive file-not-found.
  3. Medium, sweep `:247` / finish `:363`: deletes a UUID if any reference is unkept even when another reference is `.saved`. Fix: delete only when all references are unkept.
- No defect in skip gates, adopted-record rules, or the S2c interaction.
- Perry's go was given before the audit; the PR's own gate says don't merge before a clean audit, so it is NOT merged.
