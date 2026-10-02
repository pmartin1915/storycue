import SwiftUI
import Synchronization
import UIKit

/// `UIActivityViewController` wrapper. Its `completionWithItemsHandler` is the only hook that
/// says the sheet closed (Save to Files is inside it), so the export's temp directory can be
/// discarded as soon as it does. `onComplete` runs exactly once, on the main actor.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [URL]
    let onComplete: @MainActor @Sendable () -> Void

    final class Coordinator: Sendable {
        let didComplete = Mutex(false)

        /// True only for the first caller.
        func claimCompletion() -> Bool {
            didComplete.withLock { done in
                if done { return false }
                done = true
                return true
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let coordinator = context.coordinator
        let onComplete = self.onComplete
        controller.completionWithItemsHandler = { _, _, _, _ in
            guard coordinator.claimCompletion() else { return }
            Task { @MainActor in onComplete() }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
