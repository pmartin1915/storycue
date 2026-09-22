import XCTest
@testable import StoryCue

final class AVCaptureServiceTests: XCTestCase {
    /// The one AVCaptureService test that can run on the simulator/CI host: it exercises the
    /// nil-safety path (AVCaptureDevice.default(...) returns nil here), not real capture.
    /// If a future runner image grows a camera, treat that as an infra change to this test,
    /// not a SessionMachine/CaptureService logic regression.
    func testConfigureSessionThrowsWhenDeviceUnavailable() async {
        let service = AVCaptureService()
        do {
            try await service.configureSession()
            XCTFail("expected CaptureServiceError.deviceUnavailable on a camera-less host")
        } catch CaptureServiceError.deviceUnavailable {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
