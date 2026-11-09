import XCTest

/// comeup 2026-11-09 review shots (not App Store shots). Runs in the screenshots workflow's
/// review step as a whole class, so later comeup PRs add tests in an `extension` in their own
/// file and need no workflow edit. Every attachment named `comeup-...` is exported.
@MainActor
final class ComeupReviewTests: XCTestCase {

    /// comeup 2026-11-09 review shots, light appearance. The demo seed files are a few junk
    /// bytes, so playing an answer must land on the "can't be played" state: that state's text
    /// and the player chrome are what the dark-cover fix changed. Then the export sheet.
    func testCaptureComeupPlaybackAndExport() {
        let app = XCUIApplication()
        app.launchArguments = ["-StoryCueDemo"]
        app.launch()

        let libraryButton = app.buttons["libraryButton"].firstMatch
        guard waitForScreen(libraryButton, named: "comeup deck picker") else { return }
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: libraryButton)
        wait(for: [enabled], timeout: 10)
        libraryButton.tap()
        let grandparentsSession = app.descendants(matching: .any)["session.grandparents"].firstMatch
        guard waitForScreen(grandparentsSession, named: "comeup Recordings") else { return }
        grandparentsSession.tap()

        let play = app.buttons["Play answer"].firstMatch
        guard waitForScreen(play, named: "comeup session detail play button") else { return }
        play.tap()
        let caption = app.buttons["playerCaption"].firstMatch
        guard waitForScreen(caption, named: "comeup-01 player caption") else { return }
        let unavailable = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "can't be played"))
            .firstMatch
        guard waitForScreen(unavailable, named: "comeup-01 player unavailable text") else { return }
        attachScreenshot(of: app, named: "comeup-01-player-unavailable-light")

        app.buttons["Done"].firstMatch.tap()
        let export = app.buttons["Export"].firstMatch
        guard waitForScreen(export, named: "comeup-02 export button") else { return }
        export.tap()
        let photos = app.buttons["Save to Photos"].firstMatch
        guard waitForScreen(photos, named: "comeup-02 export sheet") else { return }
        attachScreenshot(of: app, named: "comeup-02-export-choosing")
    }

    /// Waits up to 10 s for the screen's anchor element and fails naming the screen.
    func waitForScreen(_ element: XCUIElement, named screen: String) -> Bool {
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("Screen \(screen) did not appear within 10 seconds")
            return false
        }
        return true
    }

    func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
