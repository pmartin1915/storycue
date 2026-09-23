import XCTest
@testable import StoryCue

final class TimerFormatTests: XCTestCase {
    func testFormatsCountUp() {
        XCTAssertEqual(TimerFormat.string(0), "0:00")
        XCTAssertEqual(TimerFormat.string(59), "0:59")
        XCTAssertEqual(TimerFormat.string(60), "1:00")
        XCTAssertEqual(TimerFormat.string(599), "9:59")
        XCTAssertEqual(TimerFormat.string(600), "10:00")
        XCTAssertEqual(TimerFormat.string(3665), "61:05")
    }

    func testNegativeClampsToZero() {
        XCTAssertEqual(TimerFormat.string(-1), "0:00")
        XCTAssertEqual(TimerFormat.string(-59.9), "0:00")
    }

    func testFloorsFractions() {
        XCTAssertEqual(TimerFormat.string(59.9), "0:59")
    }
}
