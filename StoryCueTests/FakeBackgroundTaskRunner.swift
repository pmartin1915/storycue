import XCTest
@testable import StoryCue

/// Test double for BackgroundTaskRunner: records begin/end calls in order and lets a test
/// fire the expiration handler UIKit would call. Lives in the test target, not the app.
@MainActor
final class FakeBackgroundTaskRunner: BackgroundTaskRunner {
    private(set) var beginCount = 0
    private(set) var endCount = 0
    private(set) var callLog: [String] = []
    private var expiration: (@Sendable () -> Void)?

    func begin(expiration: @escaping @Sendable () -> Void) {
        beginCount += 1
        callLog.append("begin")
        self.expiration = expiration
    }

    func end() {
        endCount += 1
        callLog.append("end")
    }

    /// Simulates UIKit expiring the background task.
    func fireExpiration() {
        let expiration = expiration
        self.expiration = nil
        expiration?()
    }
}
