# S2a Sol diff audit — 2026-09-23

Base `052a3ee`, head `7b932e0` (CI green, 121/121 on the baseline lane). Sol's raw output: `.orchestrate/logs/20260923T035631Z-sol-implement.final.txt` (not committed). 7 findings: 5 accepted and fixed in the commit after this file, 2 rejected.

| # | Sol severity | Finding | Verdict |
|---|---|---|---|
| 1 | blocking | `startCountdown()` overwrote a running countdown task on a fast double activation, orphaning a task that could still send `.tapRecord` | **Accepted.** Guard on `countdownTask == nil`; the task clears itself when it finishes. |
| 2 | major | Done/Finish during a countdown started `endSession()` without cancelling the countdown first | **Accepted.** Both call `cancelCountdown()` synchronously before `endSession()`. |
| 3 | major | Returning from Settings doesn't re-read authorization or availability | **Rejected for 1.0.** iOS terminates an app when its camera or microphone permission changes in Settings, so the stale state can't be reached. Logged to `ai/IDEAS.md` to check on a device at S5. |
| 4 | major | `ConsentView.isBeginning` stayed true, and Done/Finish pops back to the consent screen, so its only button stayed disabled | **Accepted.** It resets after `beginSession` returns. This was a real dead end. |
| 5 | major | A 60% black backing over a white feed gives ≈5.7:1, but the spec requires ≥7:1 | **Accepted.** All four backings are now at 70% (≈8.5:1). |
| 6 | minor | "Saving…" / "Starting the camera…" use U+2026 | **Rejected.** The spec's copy table (lines 289 and 293) uses U+2026 itself. |
| 7 | minor | Curly quotes built in `ConsentView`, outside `UICopy` | **Accepted.** Moved to `UICopy.readAloudCallout`. |
