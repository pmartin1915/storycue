import Foundation

/// One camera, one session at a time. A new `SessionStore` AND a new capture service per
/// recording session: `AsyncStream` is single-consumer, so a second store can't re-iterate
/// the first service's `events`. The ledger is one instance app-wide (one file, one actor).
@MainActor
@Observable
final class AppModel {
    struct ActiveSession {
        let id: UUID
        let startedAt: Date
        let deck: Deck
        let store: SessionStore
        let capture: any CaptureService
    }

    private(set) var active: ActiveSession?
    /// The shutdown + finish of the session `endSession` just closed. `beginSession` waits for
    /// it, so the camera is released and the old session stays protected until finish lands.
    @ObservationIgnored private var ending: Task<Void, Never>?
    let ledger: SegmentLedger
    let segmentDirectory: URL
    let library: Library
    let exporter: Exporter

    private let makeCapture: @MainActor (URL) -> any CaptureService
    private let makeBackground: @MainActor () -> any BackgroundTaskRunner

    /// attributesOfItem size, nil on error.
    nonisolated static let attributesFileSize: @Sendable (URL) -> Int64? = { url in
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value
    }

    /// The volume's "important usage" available capacity for `url`, nil on error.
    nonisolated static func importantUsageCapacity(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    init(
        segmentDirectory: URL,
        makeCapture: @escaping @MainActor (URL) -> any CaptureService,
        makeBackground: @escaping @MainActor () -> any BackgroundTaskRunner,
        exporter: Exporter? = nil,
        availableCapacity: @escaping @Sendable () -> Int64? = { nil },
        fileSize: @escaping @Sendable (URL) -> Int64? = AppModel.attributesFileSize
    ) {
        let ledger = SegmentLedger(directory: segmentDirectory)
        let resolvedExporter = exporter ?? Exporter(
            segmentDirectory: segmentDirectory,
            temporaryRoot: FileManager.default.temporaryDirectory,
            stitcher: AVStitcher(),
            photos: PHPhotoLibrarySaver(),
            availableCapacity: { AppModel.importantUsageCapacity(at: FileManager.default.temporaryDirectory) },
            fileSize: AppModel.attributesFileSize
        )
        self.segmentDirectory = segmentDirectory
        self.ledger = ledger
        self.exporter = resolvedExporter
        self.library = Library(
            segmentDirectory: segmentDirectory,
            index: SessionIndex(directory: segmentDirectory),
            ledger: ledger,
            exporter: resolvedExporter,
            availableCapacity: availableCapacity,
            fileSize: fileSize
        )
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
            makeBackground: { UIKitBackgroundTaskRunner() },
            availableCapacity: { AppModel.importantUsageCapacity(at: segmentDirectory) }
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
        if let ending {
            await ending.value
            guard active == nil else { return }
        }
        let id = UUID()
        let startedAt = Date()
        let capture = makeCapture(segmentDirectory)
        let store = SessionStore(
            deck: deck,
            capture: capture,
            ledger: ledger,
            segmentDirectory: segmentDirectory,
            background: makeBackground(),
            archive: { [weak library = self.library] clips in
                library?.checkpoint(sessionID: id, deck: deck, startedAt: startedAt, clips: clips)
            }
        )
        active = ActiveSession(id: id, startedAt: startedAt, deck: deck, store: store, capture: capture)
        library.activeSessionID = id
        store.start()
        isPreparing = true
        await store.prepareCapture()
        isPreparing = false
    }

    /// Refuses (returns false, changes nothing) while isPreparing, or while the active
    /// store's phase is .recording or .finishing. The check, store.stop() and
    /// `active = nil` all happen synchronously on the main actor BEFORE the first await,
    /// so no event can slip between them (AppModel and SessionStore are both @MainActor);
    /// then the camera is released (`capture.shutdown()`) and the session is handed to the
    /// library. The clips captured here are final: this only proceeds from .idle/.paused,
    /// which the reducer reaches only after fileOutputFinished set the outcome; a still-queued
    /// .persistLedger only writes the ledger. No active session → true.
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
        let id = active.id
        let deck = active.deck
        let startedAt = active.startedAt
        let clips = active.store.state.clips
        active.store.stop()
        self.active = nil
        // activeSessionID is cleared only after finish: while the camera shuts down the
        // session must stay protected, or a delete/discard in that window is undone by
        // finish's stale clips. beginSession waits on `ending`, so nothing replaces the ID.
        let library = self.library
        let previous = ending
        let task = Task { @MainActor in
            await previous?.value
            await capture.shutdown()
            await library.finish(sessionID: id, deck: deck, startedAt: startedAt, clips: clips)
            if library.activeSessionID == id { library.activeSessionID = nil }
        }
        ending = task
        await task.value
        return true
    }
}
