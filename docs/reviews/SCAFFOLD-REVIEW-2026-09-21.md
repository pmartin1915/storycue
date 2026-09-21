# Scaffold review, 2026-09-21 -- project.yml, build.yml, deploy.yml, DuoSupport + tests

Pre-commit cross-family review of the Claude-authored scaffold. **Kimi**
(`pal clink cli_name=kimi role=codereviewer`, 468 s, `return_code 0`, 10 tool calls, verified the
XcodeGen release asset name against the GitHub API). No Mac exists, so this review plus the
first CI run on `macos-27` are the only execution the scaffold gets before it is pushed.

| # | Kimi | Verdict |
|---|---|---|
| 1 | **Critical.** Unit-test targets lack `TEST_HOST` / `BUNDLE_LOADER`; XcodeGen does not auto-populate them (cites yonaskolb/XcodeGen #408, #1204), so `xcodebuild test` fails with "Could not find test host". | **ACCEPT** -- added `TEST_HOST: $(BUILT_PRODUCTS_DIR)/StoryCue.app/StoryCue` and `BUNDLE_LOADER: $(TEST_HOST)` to both bundles. Not independently verified that current XcodeGen omits them (the cited issues are old and may be fixed), but the explicit setting is correct either way and costs nothing. |
| 2 | **Critical.** `sort -V` is GNU-only; macOS BSD `sort` rejects it, so `Select Xcode` dies in both workflows. | **REJECT on primary evidence.** `shortless-ios` used the identical `ls ... \| sort -V \| tail -1` line in both its workflows on GitHub macOS runners, and its later fix commits (`0612838` simulator name, `43fdf44` xcodegen flag) prove the runs got past that step. macOS's BSD sort has supported `-V` for years. Line kept. |
| 3 | **Critical.** Same `sort -V` in the Duo gate; if it failed silently the gate would force baseline. | **REJECT the premise, ACCEPT the hardening.** The gate now compares major/minor as integers in plain POSIX shell (no `sort`), because the gate is the one place where a wrong answer would read as a green baseline instead of an error. |
| 4 | **Low.** The `-showBuildSettings` evidence steps swallow errors (`2>/dev/null ... \|\| true`), so a miswired gate looks identical to a correct one. | **ACCEPT** -- suppression removed; under `pipefail` an empty grep now fails the step. |
| 5 | **Low.** `SWIFT_STRICT_CONCURRENCY: complete` is redundant in Swift 6 language mode. | **ACCEPT** -- removed. |

Checked clean by Kimi, recorded so the next session does not re-ask: the
`STORYCUE_DUO_CONDITIONS` indirection (`$(inherited)` keeps `DEBUG`; command-line override
resolves through it; `-showBuildSettings -target` honours it); `if: env.DUO_SDK == '1'`;
`$GITHUB_ENV` / `$GITHUB_STEP_SUMMARY` use; the ExportOptions heredoc under YAML block-scalar
indentation; `upload-artifact@v4` inputs; the `concurrency` block; `"12.1"` as a valid
`CFBundleVersion`; `PlistBuddy ... /dev/stdin` (used in Shortless, not executable here); all
three Swift files under Swift 6; the test logic proves the flag-scoping invariant; the XcodeGen
`xcodegen.zip` asset name (verified live, 2.46.0).

**Watch item, not a defect:** whether `xcrun altool --upload-app` still ships in Xcode 27.
Wilderness uploaded 1.7.0 with it on Xcode 26 (2026-08), so it is proven one major back.
If it is gone, the fallback is `xcrun notarytool`-era tooling / Transporter; decide at the
first real deploy, not now.
