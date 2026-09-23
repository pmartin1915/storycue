import XCTest
@testable import StoryCue

final class AVCaptureServiceTests: XCTestCase {
    /// The one AVCaptureService test that can run on the simulator/CI host: it exercises the
    /// nil-safety path (AVCaptureDevice.default(...) returns nil here), not real capture.
    /// configureSession() checks camera authorization BEFORE device lookup, so the simulator
    /// (never .authorized) throws .notAuthorized; a camera-less authorized host throws
    /// .deviceUnavailable. Both are the expected nil-safety failure.
    func testPreviewSourceAvailableBeforeConfigure() async {
        // The preview source must exist straight from init (no configure call, no crash):
        // the consent tap's RecorderView connects its preview before prepareCapture runs.
        let service = AVCaptureService(
            segmentDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
        let source = await service.previewSource
        XCTAssertTrue(source is SessionPreviewSource)
    }

    func testShutdownBeforeConfigureIsNoOp() async {
        // Twice: the second call is a no-op beyond the first continuation finish.
        let service = AVCaptureService(
            segmentDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
        await service.shutdown()
        await service.shutdown()
    }

    func testConfigureSessionThrowsWithoutUsableCamera() async {
        let service = AVCaptureService(
            segmentDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
        do {
            try await service.configureSession()
            XCTFail("expected configureSession() to throw on a camera-less or unauthorized host")
        } catch let error as CaptureServiceError {
            guard error == .deviceUnavailable || error == .notAuthorized else {
                return XCTFail("unexpected CaptureServiceError: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
