import XCTest
@testable import StoryCue

/// This bundle expands STORYCUE_DUO_CONDITIONS exactly like the app target, so the
/// invariant it proves is "app and Duo tests are always gated together".
final class DuoGateTests: XCTestCase {
    func testDuoTestBundleAndAppSeeTheSameFlag() {
        #if DUO_SDK
        XCTAssertTrue(DuoSupport.compiledWithDuoSDK, "app compiled without DUO_SDK while the Duo test bundle has it")
        #else
        XCTAssertFalse(DuoSupport.compiledWithDuoSDK, "app compiled with DUO_SDK while the Duo test bundle lacks it")
        #endif
    }
}
