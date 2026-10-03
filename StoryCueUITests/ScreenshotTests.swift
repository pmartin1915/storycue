import XCTest

/// App Store screenshots (6.9" set). Launches the app in demo mode (`-StoryCueDemo`):
/// a mock capture service pre-authorized and ready, so no system permission alert can
/// appear and no interruption monitor is needed. Each screenshot is attached with a
/// fixed name; CI renames the exported attachments by these names.
@MainActor
final class ScreenshotTests: XCTestCase {

    func testCaptureAppStoreScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-StoryCueDemo"]
        app.launch()

        // 01-decks: the deck picker.
        let grandparentsDeck = app.descendants(matching: .any)["deck.grandparents"].firstMatch
        guard waitForScreen(grandparentsDeck, named: "01-decks (deck picker)") else { return }
        attachScreenshot(of: app, named: "01-decks")

        // 02-consent: the Grandparents consent card.
        grandparentsDeck.tap()
        let consentConfirm = app.buttons["consentConfirm"].firstMatch
        guard waitForScreen(consentConfirm, named: "02-consent (Grandparents consent)") else { return }
        attachScreenshot(of: app, named: "02-consent")

        // 03-recorder: after "We're ready", idle on question 1. The Record button only
        // becomes enabled once the (mock) camera reports ready.
        consentConfirm.tap()
        let recordButton = app.buttons["recordButton"].firstMatch
        guard waitForScreen(recordButton, named: "03-recorder (recorder, question 1)") else { return }
        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: recordButton)
        wait(for: [ready], timeout: 10)
        attachScreenshot(of: app, named: "03-recorder")

        // 04-library: Recordings, through the deck picker's libraryButton. Done lands on the
        // consent card or straight on the deck picker (the recorder is a root-level
        // destination; CI run 37083268083 never showed the consent card), so accept either
        // and go back once more only from the consent card.
        app.buttons["doneButton"].firstMatch.tap()
        let libraryButton = app.buttons["libraryButton"].firstMatch
        // A main-actor poll, not an NSPredicate block: the elements are main-actor isolated.
        // Each `exists` is a round trip to the app, so the loop needs no sleep.
        let deadline = Date().addingTimeInterval(10)
        while !libraryButton.exists && !consentConfirm.exists && Date() < deadline {}
        guard libraryButton.exists || consentConfirm.exists else {
            XCTFail("Screen 04-library (deck picker or consent after Done) did not appear within 10 seconds")
            return
        }
        if !libraryButton.exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        guard waitForScreen(libraryButton, named: "04-library (deck picker toolbar)") else { return }
        libraryButton.tap()
        let grandparentsSession = app.descendants(matching: .any)["session.grandparents"].firstMatch
        guard waitForScreen(grandparentsSession, named: "04-library (Recordings)") else { return }
        attachScreenshot(of: app, named: "04-library")

        // 05-session: the Grandparents session detail (its inline title is the deck title).
        grandparentsSession.tap()
        let sessionDetail = app.navigationBars["Grandparents"].firstMatch
        guard waitForScreen(sessionDetail, named: "05-session (Grandparents detail)") else { return }
        attachScreenshot(of: app, named: "05-session")
    }

    /// Waits up to 10 s for the screen's anchor element and fails naming the screen.
    private func waitForScreen(_ element: XCUIElement, named screen: String) -> Bool {
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("Screen \(screen) did not appear within 10 seconds")
            return false
        }
        return true
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
