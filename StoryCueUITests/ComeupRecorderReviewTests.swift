import XCTest

/// comeup 2026-11-09 PR-2 review shots: the recorder countdown (light appearance) and a
/// VoiceOver-facing check that the countdown is on screen while it runs.
extension ComeupReviewTests {
    func testCaptureComeupRecorderCountdown() {
        let app = XCUIApplication()
        app.launchArguments = ["-StoryCueDemo"]
        app.launch()

        let grandparentsDeck = app.descendants(matching: .any)["deck.grandparents"].firstMatch
        guard waitForScreen(grandparentsDeck, named: "comeup-03 deck picker") else { return }
        grandparentsDeck.tap()
        let consentConfirm = app.buttons["consentConfirm"].firstMatch
        guard waitForScreen(consentConfirm, named: "comeup-03 consent") else { return }
        let loaded = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: consentConfirm)
        wait(for: [loaded], timeout: 10)
        consentConfirm.tap()

        let recordButton = app.buttons["recordButton"].firstMatch
        guard waitForScreen(recordButton, named: "comeup-03 recorder") else { return }
        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: recordButton)
        wait(for: [ready], timeout: 10)
        recordButton.tap()

        let countdown = app.staticTexts["countdown"].firstMatch
        guard waitForScreen(countdown, named: "comeup-03 countdown") else { return }
        attachScreenshot(of: app, named: "comeup-03-recorder-countdown")

        // After 3-2-1 the mock camera records: the recording pill appears.
        let indicator = app.descendants(matching: .any)["recordingIndicator"].firstMatch
        guard waitForScreen(indicator, named: "comeup-04 recording") else { return }
        attachScreenshot(of: app, named: "comeup-04-recorder-recording")
    }
}
