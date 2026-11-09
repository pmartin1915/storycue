import XCTest

/// comeup 2026-11-09 PR-3: measured probes M6 and M7 and the AX5 reachability check. These run
/// in the screenshots workflow's review step (the whole ComeupReviewTests class); read the test
/// log for the launch durations and any audit issues.
extension ComeupReviewTests {

    /// M7 baseline: cold launch of the demo build. No threshold yet: the first CI numbers set it
    /// (target from Perry, 2026-11-04: under 2 s on device).
    func testComeupLaunchMetric() {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            let app = XCUIApplication()
            app.launchArguments = ["-StoryCueDemo"]
            app.launch()
        }
    }

    /// M7, readable: xcodebuild does not print XCTApplicationLaunchMetric numbers, so time
    /// launch-to-deck-picker by hand and print it for the log ("LAUNCH-TO-DECKS").
    func testComeupLaunchToDecksTiming() {
        for run in 1...3 {
            let app = XCUIApplication()
            app.launchArguments = ["-StoryCueDemo"]
            let start = Date()
            app.launch()
            let decks = app.descendants(matching: .any)["deck.grandparents"].firstMatch
            XCTAssertTrue(decks.waitForExistence(timeout: 10), "deck picker did not appear")
            print("LAUNCH-TO-DECKS[\(run)] \(String(format: "%.2f", Date().timeIntervalSince(start))) s")
            app.terminate()
        }
    }

    /// M6: Apple's automated accessibility audit on the deck picker, consent card and recorder.
    /// Each issue is printed so the log names it, then fails the test.
    func testComeupAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-StoryCueDemo"]
        app.launch()

        let grandparentsDeck = app.descendants(matching: .any)["deck.grandparents"].firstMatch
        guard waitForScreen(grandparentsDeck, named: "audit deck picker") else { return }
        try audit(app, screen: "deck picker")

        grandparentsDeck.tap()
        let consentConfirm = app.buttons["consentConfirm"].firstMatch
        guard waitForScreen(consentConfirm, named: "audit consent") else { return }
        try audit(app, screen: "consent")

        let loaded = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: consentConfirm)
        wait(for: [loaded], timeout: 10)
        consentConfirm.tap()
        let recordButton = app.buttons["recordButton"].firstMatch
        guard waitForScreen(recordButton, named: "audit recorder") else { return }
        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: recordButton)
        wait(for: [ready], timeout: 10)
        try audit(app, screen: "recorder")
    }

    /// At AX5 the controls must stay on screen and the question card must not cover Record.
    func testComeupAX5ControlsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-StoryCueDemo", "-StoryCueAX5"]
        app.launch()

        let grandparentsDeck = app.descendants(matching: .any)["deck.grandparents"].firstMatch
        guard waitForScreen(grandparentsDeck, named: "ax5 deck picker") else { return }
        grandparentsDeck.tap()
        let consentConfirm = app.buttons["consentConfirm"].firstMatch
        guard waitForScreen(consentConfirm, named: "ax5 consent") else { return }
        XCTAssertTrue(consentConfirm.isHittable, "AX5: We're ready is not hittable")
        let loaded = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: consentConfirm)
        wait(for: [loaded], timeout: 10)
        consentConfirm.tap()

        let recordButton = app.buttons["recordButton"].firstMatch
        guard waitForScreen(recordButton, named: "ax5 recorder") else { return }
        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: recordButton)
        wait(for: [ready], timeout: 10)
        XCTAssertTrue(recordButton.isHittable, "AX5: Record is not hittable")
        XCTAssertTrue(app.buttons["doneButton"].firstMatch.isHittable, "AX5: Done is not hittable")
        // At AX5 the card usually scrolls: its own frame is the full scroll content, so compare
        // the visible scroll view instead (a false overlap otherwise, review run 2026-11-09).
        let questionPanel = app.descendants(matching: .any)["questionPanel"].firstMatch
        if questionPanel.exists {
            let scroller = app.scrollViews.containing(.any, identifier: "questionPanel").firstMatch
            let visible = scroller.exists ? scroller.frame : questionPanel.frame
            XCTAssertFalse(
                visible.intersects(recordButton.frame),
                "AX5: the question card overlaps Record"
            )
        }
        attachScreenshot(of: app, named: "comeup-05-ax5-recorder-reachable")
    }

    private func audit(_ app: XCUIApplication, screen: String) throws {
        try app.performAccessibilityAudit { issue in
            let element = issue.element.map { "\($0.elementType.rawValue) id=\($0.identifier) label=\($0.label)" } ?? "?"
            print("AUDIT [\(screen)] \(issue.auditType.rawValue) \(issue.compactDescription) | \(element)")
            return false
        }
    }
}
