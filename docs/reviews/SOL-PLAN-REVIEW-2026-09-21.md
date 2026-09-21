# Sol plan review, 2026-09-21 -- docs/PLAN.md sections 1-5

Raw response body, saved before adjudication. Dispatched from the laptop via
`pal clink cli_name=codex role=codereviewer` with `absolute_file_paths` = PLAN.md, transcripts
111464 and 111465, and PLAN-REVIEW-2026-09-18.md. `return_code: 0`, 943.5 s (PAL backgrounded
it past 120 s, as expected), codex `exec --json` with `web_search_request` enabled; usage
1,484,340 input tokens (1,345,792 cached), 23,919 output. Body verified: it cites file:line in
the supplied files and states "no build or test suite was run because the repository currently
contains planning documents only." The stderr `codex_models_manager … missing field` and a
PowerShell-profile banner are the known non-fatal noise. Continuation id
`0d57e75c-6fbd-44bd-aba1-d7e5b0652ac0` (39 turns) if a follow-up is needed.

Adjudication is in `docs/research/SYNTHESIS-2026-09.md` §S. Nothing below is edited.

---

I'll review the plan against both Apple Tech Talk transcripts and the adjudicated prior review, then run targeted repository checks for project-generation and CI assumptions that affect sections 4–5. I'll separate transcript-backed facts from inference and avoid re-reporting accepted findings 1, 2, and 4 unless the plan still has a distinct unresolved issue.

The transcripts support the core architecture, but the risky parts are in the gate and lifecycle contract: "SDK present" is not the same as "every target can import/type-check the new surface," and "fold → pause → resume" is too coarse for a recording that may already be writing a file. I'm checking the exact API annotations and standard AVFoundation interruption semantics before assigning severity.

Direct answer: `CameraCaptureAccessory` is the correct—and currently the only documented—system capability for pairing the Duo outer display with camera UI on the inner display. SwiftUI is not the only API surface: UIKit offers `UISceneAccessory.cameraCapture(sceneConfiguration:)` for the same mechanism.

These APIs postdate my static knowledge. Duo-specific conclusions below are grounded in the supplied Apple transcripts and Apple's current DocC metadata; inferred runtime behavior is identified as such.

1. **Blocking — Sections 4.2/4.5 — The SDK gate is underspecified and will fail or silently omit coverage**

   [`PLAN.md:101`](/C:/Users/perry/DevProjects/storycue/docs/PLAN.md:101), `Duo SDK gate`

   `if #available` is only a runtime guard; it cannot make a 27.0 SDK resolve 27.1 symbols. Conversely, `#if DUO_SDK` makes those symbols compile, but supplies no runtime protection for a binary running on iOS 27.0.

   Specific traps:

   - `.sceneAccessory` exists in iOS 27.0, but `CameraCaptureAccessory` is 27.1. The entire accessory expression must be compile-gated; guarding only its content is insufficient.
   - `CameraCaptureAccessory` is in SwiftUI and `AVCaptureDeviceDirectionCoordinator` is in AVKit—modules that already exist in 27.0. Therefore `canImport(SwiftUI)` or `canImport(AVKit)` does not detect the new API surface.
   - Declarations cannot literally sit inside `if #available`. Put every 27.1 symbol reference under `#if DUO_SDK`, annotate declarations with `@available(iOS 27.1, *)`, and guard entry points with `if #available`.
   - Passing `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DUO_SDK` globally replaces inherited conditions such as `DEBUG` and applies to every target, including XCTest. A test target whose gated branch references 27.1 symbols will compile that branch too.
   - A project-level XcodeGen setting also affects all targets. Baseline tests and dedicated Duo API tests need deliberate, separate scope.
   - The SDK probe and build must use the same selected `DEVELOPER_DIR`; `-showsdks` on one Xcode followed by a build using another is possible once runner images contain multiple Xcodes.

   Recommended text change:

   > Select one Xcode and use it for both `xcrun --sdk iphoneos --show-sdk-version` and the build. Below 27.1, compile the baseline implementation with a no-op Duo adapter. At 27.1 or later, run a baseline lane with the flag off and a Duo compile/archive lane with the flag on. Every 27.1 symbol is inside `#if DUO_SDK`; declarations are `@available(iOS 27.1, *)`; call sites use `if #available`. In `project.yml`, preserve `$(inherited)` and expand a custom condition only in the app target and a dedicated Duo test target. Verify each target with `xcodebuild -showBuildSettings`.

2. **Blocking — Sections 1, 2, and 5 — Camera choice and recording finalization are not defined**

   [`PLAN.md:34`](/C:/Users/perry/DevProjects/storycue/docs/PLAN.md:34), `Fold → pause recording, preserve state, resume on open`

   "Pause and resume" is unsafe as a general policy. Apple says the Virtual Front Camera uses the inner camera while open and switches automatically when closed ([`111465:42`](/C:/Users/perry/DevProjects/storycue/docs/techtalks/111465-camera-experience.md:42)). That likely points toward the filmer rather than the subject viewing the outer display. If StoryCue selects an individual subject-facing camera, Apple requires `AVCaptureDeviceDirectionCoordinator` and session reconfiguration ([`111465:58`](/C:/Users/perry/DevProjects/storycue/docs/techtalks/111465-camera-experience.md:58), [`111465:98`](/C:/Users/perry/DevProjects/storycue/docs/techtalks/111465-camera-experience.md:98)).

   The state machine must treat capture-session state, file-writing state, accessory availability, and scene state as independent:

   | Event | Concrete signal | Required recording transition |
   |---|---|---|
   | Fold/close or loss of full-screen presentation | `onHingeChange`, `onAvailabilityChange(false)`, direction-coordinator callback | For v1, call `stopRecording()`, enter `finishing`, and wait for `fileOutput(_:didFinishRecordingTo:from:error:)` before stopping or reconfiguring the session. Reopening starts a new segment after user confirmation, not an assumed same-file resume. |
   | Incoming call/alarm | `AVAudioSession.interruptionNotification`; possibly `AVCaptureSession.wasInterruptedNotification` with `.audioDeviceInUseByAnotherClient` or `.videoDeviceInUseByAnotherClient` | Finalize or accept AVFoundation's forced finish; persist the callback result. On interruption end, restore preview only. `shouldResume` is not permission to resume recording silently. |
   | Scene inactive/background | `sceneWillResignActive`, `sceneDidEnterBackground`, `scenePhase`; `.videoDeviceNotAvailableInBackground` | Begin a UIKit background task before recording, stop the file output on deactivation, retain it until the finish callback, then release the camera. Keep a durable temp-file ledger for expiration or process termination. |
   | Thermal/system pressure | KVO on `AVCaptureDevice.systemPressureState`; `.videoDeviceNotAvailableDueToSystemPressure` at shutdown | Reduce frame rate at serious/critical pressure. At shutdown, finalize or quarantine the partial file and wait for pressure recovery plus `interruptionEndedNotification`; never discard automatically. |
   | Other capture failures | `wasInterruptedNotification`, `runtimeErrorNotification`, `AVError.mediaServicesWereReset` | Preserve the current output result. For media-services reset, recreate AVFoundation objects; require user action before starting a new recording. |
   | Direction change | `AVCaptureDeviceDirectionCoordinator` handler | Pass its `AVCaptureDeviceDescriptor` from the main actor to the camera actor. Do not call AVFoundation directly in the handler. If an input must change, finish the current segment before `beginConfiguration`/`commitConfiguration`; otherwise `.sessionConfigurationChanged` can terminate the recording. |

   Apple guarantees the file-output finish delegate is called for each recording request, including error termination. Inspect `AVError.recordingSuccessfullyFinished`; keep unsuccessful files for validation/recovery rather than deleting them. [Apple's recording delegate documentation](https://developer.apple.com/documentation/avfoundation/avcapturefileoutputrecordingdelegate) and [capture interruption reasons](https://developer.apple.com/documentation/avfoundation/avcapturesession/interruptionreason) define these signals.

   Recommended text change: replace "pause recording … resume on open" with "finish the current physical segment on any accessory/camera/lifecycle discontinuity; preserve it through the finish delegate; optionally stitch segments into one logical clip later."

3. **Blocking — Section 5 — The ladder never validates the real recorder before submission**

   [`PLAN.md:133`](/C:/Users/perry/DevProjects/storycue/docs/PLAN.md:133), `XCTest on a mocked capture service`

   A mock proves reducer logic, not permission handling, camera/audio synchronization, codecs, file finalization, low-storage behavior, interruptions, rotation, or Photos/Files export. Yet the plan calls the single-screen recorder "fully tested" at the pivot.

   The constraint is "no Duo and no Mac," not "no ordinary iPhone"; week 3 already expects installation on Perry's iPhone. Add a pre-submission TestFlight rung on that device covering:

   - Camera and microphone permission grant/deny/revoke.
   - Start/stop and repeated clips.
   - Backgrounding, incoming-call interruption, rotation, and app termination.
   - Low-storage/file-output failure and orphan-temp recovery.
   - Photos and Files export, followed by playback of the exported artifact.

   Also replace the unusable "eyeball a SwiftUI preview in Xcode" claim at [`PLAN.md:117`](/C:/Users/perry/DevProjects/storycue/docs/PLAN.md:117): without a Mac, make the outer-preview mode produce automated simulator screenshot artifacts and snapshot assertions.

4. **Should-fix — Sections 1 and 5 — The mechanism is right, but "only" and touch support need correction**

   [`PLAN.md:33`](/C:/Users/perry/DevProjects/storycue/docs/PLAN.md:33), `Whether the subject can TOUCH ... is unconfirmed`

   Apple's Tech Talk explicitly presents `CameraCaptureAccessory` for this exact teleprompter topology ([`111464:68`](/C:/Users/perry/DevProjects/storycue/docs/techtalks/111464-multiple-displays-and-scenes.md:68)). Current Apple documentation additionally says its content can be interactive, unlike `ExternalNonInteractiveAccessory`. Therefore touch capability is documented, although it remains beta and needs hardware verification.

   Alternatives:

   - `UISceneAccessory.cameraCapture(sceneConfiguration:)` is the UIKit spelling of the same camera-capture accessory mechanism, not a distinct capability.
   - `ExternalNonInteractiveAccessory` targets a connected external display or AirPlay, not the built-in Duo outer-display camera experience.
   - Ordinary `UIWindowScene` creation does not apply: Apple states new windows cannot be created on the outer display.
   - Mirroring, widgets, or Live Activities cannot provide an app-controlled paired view with the filmer's inner-display UI.

   Recommended replacement:

   > The camera-capture scene-accessory mechanism is the only documented mechanism for this topology. SwiftUI uses `CameraCaptureAccessory` inside `sceneAccessory`; UIKit can register `UISceneAccessory.cameraCapture`. Its content is documented as interactive, but v1 remains display-only until touch and hit-testing are verified on final hardware.

   Sources: [CameraCaptureAccessory](https://developer.apple.com/documentation/swiftui/cameracaptureaccessory), [ExternalNonInteractiveAccessory](https://developer.apple.com/documentation/swiftui/externalnoninteractiveaccessory).

5. **Should-fix — Section 5 — Launch-day Duo testing cannot de-risk the launch build**

   [`PLAN.md:137`](/C:/Users/perry/DevProjects/storycue/docs/PLAN.md:137), `TestFlight external testers ... on 10-23`

   That rung is post-launch validation. A captured ten-second clip proves recording, but not that the prompt or "Recording" indicator appeared on the outer display.

   Recommended additions:

   - Seek one pre-submission Apple lab, borrowed/rented device, or recruited tester. If none exists, explicitly record outer-display presentation as an unverified launch risk.
   - Ask for a second-device video showing both displays, not only the produced clip.
   - Add a privacy-safe diagnostic export containing timestamps for scene phase, hinge state, accessory availability, session interruptions/runtime errors, selected device descriptor, and file-output completion.
   - Treat Device Hub posture automation as unproven until a documented headless API exists. A debug posture injection validates layout logic, not actual `onHingeChange` delivery.
   - Recompile and archive against each 27.1 beta/RC/final SDK because the relevant APIs are still marked beta.

6. **Should-fix — Section 4.4 — `run_number` is valid but not collision-safe**

   [`PLAN.md:112`](/C:/Users/perry/DevProjects/storycue/docs/PLAN.md:112), `CURRENT_PROJECT_VERSION=${{ github.run_number }}`

   A numeric `run_number` is a valid `CFBundleVersion`, but [GitHub defines it per workflow and leaves it unchanged on reruns](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts). Therefore a rerun after a successful upload repeats the build string; replacing or renaming the deployment workflow can also restart its sequence.

   The `.ipa` read-back verifies that Xcode embedded the expected value. It cannot tell whether App Store Connect already contains that bundle-ID/version/build combination. I agree with the prior review's rejection of the "workflows interleave" claim, but disagree with its statement at [`PLAN-REVIEW:47`](/C:/Users/perry/DevProjects/storycue/docs/reviews/PLAN-REVIEW-2026-09-18.md:47) that IPA read-back catches the collision cases.

   Recommended replacement:

   > Use `CURRENT_PROJECT_VERSION=${{ github.run_number }}.${{ github.run_attempt }}`, keep the deploy workflow identity stable, serialize deploys with a concurrency group, and query App Store Connect for an existing build before archiving/uploading. Verify the main app's exported `CFBundleVersion` equals the computed value; treat that as packaging verification, not uniqueness verification.

   Apple identifies a build by bundle ID, marketing version, and build string. [App Store Connect upload documentation](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).

Positive practices worth preserving: the baseline non-Duo product, compile-time plus runtime gating principle, explicit evidence ladder, mocked state-machine tests, artifact-level `.ipa` verification, and honest acknowledgement that simulator testing cannot exercise the accessory end to end. I agree with the prior review's accepted verdicts 1, 2, and 4 and have not repeated them.

No build or test suite was run because the repository currently contains planning documents only; the review used direct file inspection, targeted `rg` searches, the supplied transcripts, and current Apple DocC metadata.

<SUMMARY>The camera-capture scene-accessory architecture is correct. `CameraCaptureAccessory` is the SwiftUI API; UIKit's `UISceneAccessory.cameraCapture` is an equivalent API surface, while regular scenes and external-display accessories do not satisfy the Duo topology. Apple now documents camera-accessory content as interactive.

Before implementation, rewrite the SDK gate: compile-gate every 27.1 symbol, use `@available` on declarations and `#available` at call sites, preserve inherited Swift conditions, scope the flag through XcodeGen to intentional targets, and bind the SDK probe and build to the same Xcode.

The largest product risk is clip loss. Replace "fold → pause → resume" with a segmented finalization model driven by `AVCaptureFileOutputRecordingDelegate`. Handle fold, accessory withdrawal, calls, backgrounding, thermal shutdown, capture interruptions, media-service reset, and direction changes without stopping or reconfiguring the session before the file finish callback. Persist temp-file recovery state and never silently resume recording.

Add real non-Duo TestFlight capture testing before submission; mocks and a camera-less simulator cannot validate the recorder. Treat launch-day Duo testing as post-launch validation, collect a second-device video plus privacy-safe diagnostics, and explicitly retain the residual hardware risk if no pre-submission Duo access is possible.

Finally, `github.run_number` alone collides on reruns. Use `run_number.run_attempt`, serialize deployments, and preflight App Store Connect. IPA read-back verifies packaging only, not build-number uniqueness.</SUMMARY>
