import UIKit

/// Covers an in-flight segment file write while the app is backgrounded. The reducer defers
/// `.endBackgroundTask` until the write is confirmed complete, so the task must outlive
/// individual effect executions — hence a small abstraction rather than ad-hoc UIKit calls.
///
/// The expiration handler is `@Sendable`, not `@MainActor`: UIKit's expirationHandler is an
/// unisolated `() -> Void`, so the store hops to the main actor itself inside the closure.
@MainActor
protocol BackgroundTaskRunner: AnyObject {
    func begin(expiration: @escaping @Sendable () -> Void)
    func end()
}

/// Production runner. Holds at most one identifier; `end()` with none held is a no-op.
final class UIKitBackgroundTaskRunner: BackgroundTaskRunner {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    func begin(expiration: @escaping @Sendable () -> Void) {
        guard identifier == .invalid else { return }
        identifier = UIApplication.shared.beginBackgroundTask(withName: "dev.pmartin1915.storycue.finish-segment-write") {
            expiration()
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
