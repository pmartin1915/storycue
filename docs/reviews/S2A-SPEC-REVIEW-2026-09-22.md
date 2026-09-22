# S2a spec review — Kimi pre-dispatch, 2026-09-22

Reviewer: Kimi (`kimi-exec.sh --review`, spec text only). 18 findings.

| # | Finding (short) | Verdict | Action in spec |
|---|---|---|---|
| 1 | `navigationDestination(isPresented:)` needs a non-nil session; force-unwrap risk | accept | `if let active = model.active` inside the destination |
| 2 | Blocking overlay content unspecified | accept | Overlay table added |
| 3 | `beginSession` error handling | clarify | `prepareCapture` never throws; failure = blocking state, `active` stays set by design |
| 4, 14 | Countdown cancel mechanics; stale `.tapRecord` after backgrounding | accept | Stored task, cancel triggers listed, phase re-read after the sleep |
| 5 | `endSession` check-then-act race | reject, clarified | Both types are `@MainActor`; check, `stop()` and `active = nil` happen before the first `await` |
| 6 | Removing `captureSession` vs "S1 tests pass" | clarify | Verified no test references it; stated |
| 7 | Who builds the ledger; does its init touch disk | clarify | `init` builds it; verified the ledger's init does no I/O |
| 8 | Fallback directory is a placeholder | accept | Exact expression written out |
| 9 | Button → event mapping unstated | accept | Mapping table added |
| 10 | View behavior unverified | partial | `testInfoPlistPortraitOnly` added; back-swipe and 44 pt moved to the S5 device checklist explicitly |
| 11 | Layout review criteria not adjudicable | clarify | Boss adjudicates; edits are boss follow-ups |
| 12 | Preview representable reused across sessions → black preview | accept | `.id(ObjectIdentifier(active.store))` |
| 13 | `@preconcurrency` fallback relaxes the whole file | accept | Noted; file kept to preview types only |
| 15 | `testBeginSessionPreparesCapture` leans on S1 behavior | clarify | Dependency stated |
| 16 | `.userStop` banner rule leans on the reducer | accept | Banner rule excludes `.userStop` explicitly |
| 17 | Forbidden-pattern grep not named | accept | Four greps listed in Done-when |
| 18 | "Done" during `.preparing` races the in-flight configure | accept | `isPreparing`; `canLeave` false and `endSession` refuses while preparing; test added |
