import SwiftUI
import XCTest
@testable import StoryCue

final class ScenePhaseMappingTests: XCTestCase {
    func testActiveToInactiveResigns() {
        XCTAssertEqual(ScenePhaseMapping.event(from: .active, to: .inactive), .sceneWillResignActive)
    }

    func testToBackgroundEntersBackground() {
        XCTAssertEqual(ScenePhaseMapping.event(from: .active, to: .background), .sceneDidEnterBackground)
        XCTAssertEqual(ScenePhaseMapping.event(from: .inactive, to: .background), .sceneDidEnterBackground)
    }

    func testToActiveBecomesActive() {
        XCTAssertEqual(ScenePhaseMapping.event(from: .inactive, to: .active), .sceneDidBecomeActive)
        XCTAssertEqual(ScenePhaseMapping.event(from: .background, to: .active), .sceneDidBecomeActive)
    }

    func testOtherTransitionsNil() {
        XCTAssertNil(ScenePhaseMapping.event(from: .inactive, to: .inactive))
        XCTAssertNil(ScenePhaseMapping.event(from: .background, to: .inactive))
    }
}
