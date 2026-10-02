import Foundation
import Observation

/// Drives one export screen over S3's `Exporter` (S2b spec §5). The export path never
/// deletes a segment; this model only ever discards the temp directory of its own result.
@MainActor
@Observable
final class ExportModel {
    enum Phase: Equatable {
        case choosing
        case running(done: Int, total: Int)
        case sharing(ExportResult)          // share sheet up; files in result.files
        case finished(String)               // summary copy
        case failed(String)                 // ExportFailure.userMessage
    }

    private(set) var phase: Phase = .choosing
    var unit: ExportUnit = .perClip
    let sessionID: UUID

    private let library: Library
    private let exporter: Exporter
    private var task: Task<Void, Never>?

    init(sessionID: UUID, library: Library, exporter: Exporter) {
        self.sessionID = sessionID
        self.library = library
        self.exporter = exporter
    }

    /// Record exists, deck resolves, the manifest is non-empty, and the library allows it.
    var canExport: Bool {
        guard let record = library.record(id: sessionID),
              record.deck != nil,
              !record.manifest.isEmpty
        else { return false }
        return library.canStartExport(sessionID)
    }

    func start(_ destination: ExportDestination) {
        guard canExport else { return }
        switch phase {
        case .choosing, .finished, .failed:
            break
        case .running, .sharing:
            return
        }
        guard let record = library.record(id: sessionID), let deck = record.deck else { return }

        library.beginExport(sessionID)
        phase = .running(done: 0, total: 0)

        let exporter = self.exporter
        let unit = self.unit
        let entries = record.manifest
        let sessionDate = record.startedAt
        // Hops can reorder; applyProgress keeps the max and ignores anything outside .running.
        let progress: @Sendable (Int, Int) -> Void = { [weak self] done, total in
            Task { @MainActor in
                guard let self else { return }
                self.applyProgress(done: done, total: total)
            }
        }
        task = Task {
            do {
                let result = try await exporter.export(
                    entries: entries,
                    deck: deck,
                    sessionDate: sessionDate,
                    unit: unit,
                    destination: destination,
                    progress: progress
                )
                self.complete(result, destination: destination)
            } catch {
                self.fail(ExportFailure.from(error))
            }
        }
    }

    func cancel() {
        task?.cancel()
    }

    /// Called when the share sheet closes (or the export sheet goes away while sharing).
    /// A no-op unless the phase is `.sharing`, so two callers can't double-discard.
    func shareDismissed() async {
        guard case let .sharing(result) = phase else { return }
        phase = .finished(summary(for: result, destination: .files))
        library.endExport(sessionID)
        await exporter.discard(result)
    }

    private func applyProgress(done: Int, total: Int) {
        guard case let .running(seen, _) = phase else { return }
        phase = .running(done: max(seen, done), total: total)
    }

    private func complete(_ result: ExportResult, destination: ExportDestination) {
        task = nil
        switch destination {
        case .files:
            // endExport waits for shareDismissed.
            phase = .sharing(result)
        case .photos:
            phase = .finished(summary(for: result, destination: .photos))
            library.endExport(sessionID)
        }
    }

    private func fail(_ failure: ExportFailure) {
        task = nil
        phase = .failed(failure.userMessage)
        library.endExport(sessionID)
    }

    private func summary(for result: ExportResult, destination: ExportDestination) -> String {
        let count = destination == .photos ? result.savedToPhotosCount : result.files.count
        var text = UICopy.exportDone(destination: destination, count: count)
        if !result.dropped.isEmpty {
            text += " " + UICopy.droppedNote(result.dropped.count)
        }
        if !result.flaggedSegmentIDs.isEmpty {
            text += " " + UICopy.flaggedNote
        }
        return text
    }
}
