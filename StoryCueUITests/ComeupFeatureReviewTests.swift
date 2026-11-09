import XCTest

/// comeup 2026-11-09 PR-4 review shots: Perry's veteran picks that a demo run can reach.
/// V2 (Done with nothing recorded says so) and V4 (a toast after deleting a recording).
extension ComeupReviewTests {
    func testCaptureComeupNothingSavedToast() {
        let app = XCUIApplication()
        app.launchArguments = ["-StoryCueDemo"]
        app.launch()

        let grandparentsDeck = app.descendants(matching: .any)["deck.grandparents"].firstMatch
        guard waitForScreen(grandparentsDeck, named: "comeup-06 deck picker") else { return }
        grandparentsDeck.tap()
        let consentConfirm = app.buttons["consentConfirm"].firstMatch
        guard waitForScreen(consentConfirm, named: "comeup-06 consent") else { return }
        let loaded = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: consentConfirm)
        wait(for: [loaded], timeout: 10)
        consentConfirm.tap()

        let done = app.buttons["doneButton"].firstMatch
        guard waitForScreen(done, named: "comeup-06 recorder") else { return }
        let canLeave = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: done)
        wait(for: [canLeave], timeout: 10)
        done.tap()

        let toast = app.staticTexts["toast"].firstMatch
        guard waitForScreen(toast, named: "comeup-06 nothing-saved toast") else { return }
        XCTAssertTrue(toast.label.contains("Nothing was saved"), "toast said: \(toast.label)")
        attachScreenshot(of: app, named: "comeup-06-nothing-saved-toast")
    }

    func testCaptureComeupDeleteRecordingToast() {
        let app = XCUIApplication()
        app.launchArguments = ["-StoryCueDemo"]
        app.launch()

        let libraryButton = app.buttons["libraryButton"].firstMatch
        guard waitForScreen(libraryButton, named: "comeup-07 deck picker") else { return }
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: libraryButton)
        wait(for: [enabled], timeout: 10)
        libraryButton.tap()
        let session = app.descendants(matching: .any)["session.grandparents"].firstMatch
        guard waitForScreen(session, named: "comeup-07 Recordings") else { return }
        session.tap()

        let delete = app.buttons["Delete recording"].firstMatch
        guard waitForScreen(delete, named: "comeup-07 session detail") else { return }
        delete.tap()
        // The confirmation dialog repeats the label; its button is the last match.
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", "Delete recording"))
        let dialogShown = expectation(for: NSPredicate(format: "count >= 2"), evaluatedWith: matches)
        wait(for: [dialogShown], timeout: 10)
        matches.element(boundBy: matches.count - 1).tap()

        let toast = app.staticTexts["toast"].firstMatch
        guard waitForScreen(toast, named: "comeup-07 recording-deleted toast") else { return }
        attachScreenshot(of: app, named: "comeup-07-recording-deleted-toast")
    }
}
