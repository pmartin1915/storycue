import XCTest
@testable import StoryCue

final class UICopyTests: XCTestCase {
    func testPausedBannerNonEmptyForEveryShownReason() {
        let allReasons: [SegmentEndReason] = [
            .userPause,
            .userStop,
            .hingeClosed,
            .accessoryWithdrawn,
            .audioInterruption,
            .captureInterruption(.videoDeviceInUseByAnotherClient),
            .sceneResignedActive,
            .sceneBackgrounded,
            .thermalShutdown,
            .runtimeError,
            .mediaServicesReset,
            .directionChanged,
            .segmentCapReached,
            .outputEndedUnexpectedly,
        ]
        XCTAssertEqual(allReasons.count, 14)
        for reason in allReasons where reason != .userPause && reason != .userStop {
            XCTAssertFalse(
                UICopy.pausedBanner(reason).isEmpty,
                "pausedBanner(\(reason)) must be non-empty"
            )
        }
        XCTAssertEqual(UICopy.pausedBanner(.userPause), "")
        XCTAssertEqual(UICopy.pausedBanner(.userStop), "")
    }

    func testReadAloudLineIsExact() {
        // SYNTHESIS-2026-09 Q7, byte for byte.
        XCTAssertEqual(
            UICopy.readAloudLine,
            "I understand this is being recorded, and I am ready to begin."
        )
    }

    func testNoCopyContainsTODO() {
        // The copy table is statics, not introspectable — so scan the one file that may
        // hold user-visible strings.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // StoryCueTests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("StoryCue/UICopy.swift")
        guard let source = try? String(contentsOf: url, encoding: .utf8) else {
            return XCTFail("could not read UICopy.swift at \(url)")
        }
        XCTAssertFalse(source.contains("TODO"), "user-visible copy must not contain TODO")
    }
}
