import XCTest
@testable import StoryCue

final class DuoSupportTests: XCTestCase {
    func testBaselineTestBundleIsNeverCompiledWithDuoFlag() {
        #if DUO_SDK
        XCTFail("StoryCueTests must never see DUO_SDK; only the app and StoryCueDuoTests expand STORYCUE_DUO_CONDITIONS")
        #endif
    }

    func testDuoAPIsAreNeverReportedAvailableFromABaselineBinary() {
        if !DuoSupport.compiledWithDuoSDK {
            XCTAssertFalse(DuoSupport.duoAPIsAvailable)
        }
    }

    func testBuildDescriptionNamesTheLane() {
        let description = DuoSupport.buildDescription
        if DuoSupport.compiledWithDuoSDK {
            XCTAssertTrue(description.hasPrefix("Duo-capable build"))
        } else {
            XCTAssertTrue(description.hasPrefix("Baseline build"))
        }
    }
}
