import Foundation
import Observation

enum CaptureAvailability: Equatable, Sendable {
    case unknown, ready, notAuthorized, unavailable
}

struct RecoveredSegment: Equatable, Sendable {
    let entry: SegmentLedgerEntry
    let fileExists: Bool
}

/// Owns one `SessionState`: subscribes to `CaptureService.events`, maps them to
/// `SessionEvent`s, reduces, and executes the returned `[SessionEffect]` against the capture
/// service and ledger. Pure-Foundation surface for the S2a UI — never imports AVFoundation
/// or UIKit (the UIKit background-task runner is its own file).
@MainActor
@Observable
final class SessionStore {
    private(set) var state: SessionState
    private(set) var captureAvailability: CaptureAvailability = .unknown
    private(set) var authorization: CaptureAuthorization?
    private(set) var hasAudioInput = true
    private(set) var recoveredSegments: [RecoveredSegment] = []
    private(set) var now: Date

    var currentQuestion: Question { state.deck.questions[state.questionIndex] }
    var nextQuestionPreview: Question? {
        let nextIndex = state.questionIndex + 1
        guard nextIndex < state.deck.questions.count else { return nil }
        return state.deck.questions[nextIndex]
    }
    var elapsedInSegment: TimeInterval {
        guard case let .recording(id) = state.phase,
              let segment = state.clips.flatMap(\.segments).first(where: { $0.id == id })
        else { return 0 }
        return now.timeIntervalSince(segment.startedAt)
    }
    var canResume: Bool {
        if case .paused = state.phase { return true }
        return false
    }

    static let segmentCap: TimeInterval = 600
    private var capNotifiedSegmentIDs: Set<UUID> = []   // one .segmentCapReached per segment id

    private let capture: any CaptureService
    private let ledger: SegmentLedger
    private let segmentDirectory: URL
    private let background: any BackgroundTaskRunner

    // Effects run strictly in order, FIFO across calls: send reduces synchronously on the
    // main actor (state is never stale), appends effects to one queue, and a single
    // consumer Task executes them one at a time. All of these tasks are plain `Task {}`
    // created inside this @MainActor class — they inherit the main actor rather than
    // running detached from it — and every capture/ledger call inside is awaited.
    private var pendingEffects: [SessionEffect] = []
    private var isConsumingEffects = false
    private var eventPumpTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?

    init(
        deck: Deck,
        capture: any CaptureService,
        ledger: SegmentLedger,
        segmentDirectory: URL,
        background: any BackgroundTaskRunner,
        now: Date = Date()
    ) {
        self.state = SessionState(
            deck: deck,
            questionIndex: 0,
            phase: .idle,
            clips: [],
            hinge: nil,
            backgroundTaskActive: false
        )
        self.capture = capture
        self.ledger = ledger
        self.segmentDirectory = segmentDirectory
        self.background = background
        self.now = now
    }

    // MARK: - Event pump and ticker

    /// Begins consuming capture.events ONLY (no ticker); idempotent. Deliberately separate
    /// from the ticker: tests drive `tick(now:)` with synthetic values, and a running
    /// wall-clock ticker would overwrite those between tick and assertion.
    func start() {
        guard eventPumpTask == nil else { return }
        let capture = self.capture
        eventPumpTask = Task { [weak self] in
            // The protocol requirement is actor-isolated, so reading it through the
            // existential needs an await (the conformers' `nonisolated let` doesn't help here).
            let events = await capture.events
            for await event in events {
                // Re-check each time so the pump never keeps the store alive on its own.
                guard let self else { return }
                self.send(SessionStore.map(event))
            }
        }
    }

    /// 1 Hz wall-clock tick. S2a's view calls this; tests never do.
    func startTicker() {
        guard tickerTask == nil else { return }
        tickerTask = Task {
            while !Task.isCancelled {
                self.tick(now: Date())
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        eventPumpTask?.cancel()
        eventPumpTask = nil
        tickerTask?.cancel()
        tickerTask = nil
    }

    // MARK: - Events, ticks, effects

    func send(_ event: SessionEvent) {
        let (newState, effects) = SessionMachine.reduce(state, event)
        state = newState
        pendingEffects.append(contentsOf: effects)
        consumeEffectsIfNeeded()
    }

    /// The store, not the reducer, owns time. Sets `now`; sends .segmentCapReached once
    /// when the current segment's elapsed time reaches the cap.
    func tick(now: Date) {
        self.now = now
        guard case let .recording(id) = state.phase,
              elapsedInSegment >= Self.segmentCap,
              !capNotifiedSegmentIDs.contains(id)
        else { return }
        capNotifiedSegmentIDs.insert(id)
        send(.segmentCapReached)
    }

    /// Safe to call repeatedly; the real service never re-prompts a determined state.
    func prepareCapture() async {
        let auth = await capture.requestAuthorization()
        authorization = auth
        guard auth.camera == .authorized else {
            captureAvailability = .notAuthorized
            return
        }
        do {
            try await capture.configureSession()
            captureAvailability = .ready
            hasAudioInput = await capture.hasAudioInput
        } catch CaptureServiceError.notAuthorized {
            captureAvailability = .notAuthorized
        } catch {
            captureAvailability = .unavailable
        }
    }

    /// Launch-time crash recovery: publish every ledger entry still `.writing`, with
    /// whether its file actually exists on disk (size > 0). A file cut off by a crash is
    /// normally playable up to its last movie fragment; S2b shows it as "recovered" and
    /// owns keep/delete. Nothing is deleted here and no new ledger status is invented.
    func recoverOrphans() async {
        guard let entries = try? await ledger.orphanedEntries() else { return }
        recoveredSegments = entries.map { entry in
            let attributes = try? FileManager.default.attributesOfItem(atPath: entry.fileURL.path)
            let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            return RecoveredSegment(entry: entry, fileExists: size > 0)
        }
    }

    /// Test hook: resumes when the effect queue is drained AND has stayed drained for a run
    /// of consecutive yields. Events reach the store through hops it can't observe (the
    /// event pump's `for await`, the background-expiration `Task { @MainActor }`), so a
    /// single yield can return before a just-simulated event has been sent at all.
    func waitForIdleEffects() async {
        var quietYields = 0
        while quietYields < 20 {
            await Task.yield()
            if isConsumingEffects || !pendingEffects.isEmpty {
                quietYields = 0
            } else {
                quietYields += 1
            }
        }
    }

    private func consumeEffectsIfNeeded() {
        guard !isConsumingEffects, !pendingEffects.isEmpty else { return }
        isConsumingEffects = true
        Task {
            while !self.pendingEffects.isEmpty {
                let effect = self.pendingEffects.removeFirst()
                await self.execute(effect)
            }
            self.isConsumingEffects = false
        }
    }

    private func execute(_ effect: SessionEffect) async {
        switch effect {
        case let .startSegment(id, questionID):
            // Record the .writing ledger entry FIRST, then start capture: a crash
            // mid-recording now leaves an entry recoverOrphans() can find. If the ledger
            // write itself fails, still start the capture — losing crash-recovery for one
            // segment beats losing the recording.
            let startedAt = state.clips
                .flatMap(\.segments)
                .first(where: { $0.id == id })?
                .startedAt ?? now
            let entry = SegmentLedgerEntry(
                segmentID: id,
                questionID: questionID,
                fileURL: SegmentFiles.url(for: id, in: segmentDirectory),
                startedAt: startedAt,
                status: .writing
            )
            try? await ledger.record(entry)
            do {
                try await capture.startSegment(id: id, for: questionID)
            } catch CaptureServiceError.notAuthorized {
                captureAvailability = .notAuthorized
                send(.runtimeError)
            } catch {
                send(.runtimeError)
            }

        case let .stopSegment(id):
            await capture.stopSegment(id)

        case .beginBackgroundTask:
            background.begin { [weak self] in
                // UIKit requires endBackgroundTask be called from the expiration handler.
                // The handler is unisolated () -> Void, so hop to the main actor ourselves.
                Task { @MainActor in
                    guard let self else { return }
                    self.background.end()
                    self.send(.backgroundTaskExpired)
                }
            }

        case .endBackgroundTask:
            background.end()

        case .reduceFrameRate:
            await capture.reduceFrameRate()

        case .recreateCaptureSession:
            do {
                try await capture.recreateSession()
                captureAvailability = .ready
            } catch CaptureServiceError.notAuthorized {
                captureAvailability = .notAuthorized
            } catch {
                captureAvailability = .unavailable
            }

        case let .persistLedger(clip):
            // markFinished is idempotent, so a duplicate persist is harmless.
            for segment in clip.segments where segment.outcome != nil {
                try? await ledger.markFinished(segment.id)
            }
        }
    }

    // MARK: - CaptureServiceEvent mapping

    /// 1:1 with SessionEvent, except segmentFinished → fileOutputFinished (WEEK1-SPEC).
    private static func map(_ event: CaptureServiceEvent) -> SessionEvent {
        switch event {
        case let .segmentFinished(segmentID, outcome):
            return .fileOutputFinished(segmentID: segmentID, outcome: outcome)
        case .audioInterruptionBegan:
            return .audioInterruptionBegan
        case .audioInterruptionEnded:
            return .audioInterruptionEnded
        case let .captureInterruptionBegan(reason):
            return .captureInterruptionBegan(reason)
        case .captureInterruptionEnded:
            return .captureInterruptionEnded
        case .thermalPressureCritical:
            return .thermalPressureCritical
        case .runtimeError:
            return .runtimeError
        case .mediaServicesReset:
            return .mediaServicesReset
        }
    }
}
