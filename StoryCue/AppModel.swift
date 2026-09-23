import Foundation

/// One camera, one session at a time. A new `SessionStore` AND a new capture service per
/// recording session: `AsyncStream` is single-consumer, so a second store can't re-iterate
/// the first service's `events`. The ledger is one instance app-wide (one file, one actor).
@MainActor
@Observable
final class AppModel {
    struct ActiveSession {
        let deck: Deck
        let store: SessionStore
        let capture: any CaptureService
    }

    private(set) var active: ActiveSession?
    let ledger: SegmentLedger
    let segmentDirectory: URL

    private let makeCapture: @MainActor (URL) -> any CaptureService
    private let makeBackground: @MainActor () -> any BackgroundTaskRunner

    init(
        segmentDirectory: URL,
        makeCapture: @escaping @MainActor (URL) -> any CaptureService,
        makeBackground: @escaping @MainActor () -> any BackgroundTaskRunner
    ) {
        self.segmentDirectory = segmentDirectory
        self.ledger = SegmentLedger(directory: segmentDirectory)
        self.makeCapture = makeCapture
        self.makeBackground = makeBackground
    }

    /// Production wiring. Constructs NO capture service (the S1 nil-safety rule — nothing
    /// here touches a camera): the factories run inside `beginSession`, after the consent
    /// tap.
    static func production() -> AppModel {
        let segmentDirectory = (try? SegmentFiles.defaultDirectory())
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Segments", isDirectory: true)
        return AppModel(
            segmentDirectory: segmentDirectory,
            makeCapture: { AVCaptureService(segmentDirectory: $0) },
            makeBackground: { UIKitBackgroundTaskRunner() }
        )
    }

    private(set) var isPreparing = false

    /// Creates capture + store for `deck`, sets `active`, calls store.start(), sets
    /// isPreparing = true, awaits store.prepareCapture(), sets isPreparing = false.
    /// If a session is already active, does nothing. prepareCapture never throws
    /// (S1 §5 rule 5): failures land in store.captureAvailability, which the recorder shows
    /// as a blocking state — so `active` stays set on failure, by design, and the user
    /// leaves with "Done".
    func beginSession(deck: Deck) async {
        guard active == nil else { return }
        let capture = makeCapture(segmentDirectory)
        let store = SessionStore(
            deck: deck,
            capture: capture,
            ledger: ledger,
            segmentDirectory: segmentDirectory,
            background: makeBackground()
        )
        active = ActiveSession(deck: deck, store: store, capture: capture)
        store.start()
        isPreparing = true
        await store.prepareCapture()
        isPreparing = false
    }

    /// Refuses (returns false, changes nothing) while isPreparing, or while the active
    /// store's phase is .recording or .finishing. The check, store.stop() and
    /// `active = nil` all happen synchronously on the main actor BEFORE the first await,
    /// so no event can slip between them (AppModel and SessionStore are both @MainActor);
    /// then `await capture.shutdown()` on the captured local. No active session → true.
    @discardableResult
    func endSession() async -> Bool {
        guard let active else { return true }
        guard !isPreparing else { return false }
        switch active.store.state.phase {
        case .recording, .finishing:
            return false
        case .idle, .paused:
            break
        }
        let capture = active.capture
        active.store.stop()
        self.active = nil
        await capture.shutdown()
        return true
    }
}
