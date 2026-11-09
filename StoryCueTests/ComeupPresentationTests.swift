import XCTest
@testable import StoryCue

/// comeup 2026-11-09 V1: the recording pill warns in the last minute before the answer cap.
final class ComeupPresentationTests: XCTestCase {
    func testNearsCapOnlyInTheLastMinuteWhileRecording() {
        let cap: TimeInterval = 600
        XCTAssertFalse(RecorderPresentation.nearsCap(elapsed: 0, cap: cap, isRecording: true))
        XCTAssertFalse(RecorderPresentation.nearsCap(elapsed: 539.9, cap: cap, isRecording: true))
        XCTAssertTrue(RecorderPresentation.nearsCap(elapsed: 540, cap: cap, isRecording: true))
        XCTAssertTrue(RecorderPresentation.nearsCap(elapsed: 599, cap: cap, isRecording: true))
        XCTAssertFalse(RecorderPresentation.nearsCap(elapsed: 590, cap: cap, isRecording: false))
    }

    func testCapWarningCopyIsShortEnoughForTheNavBarPill() {
        XCTAssertLessThanOrEqual(UICopy.nearCapIndicator.count, UICopy.recordingIndicator.count + 1)
    }
}
