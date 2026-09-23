import Foundation

enum ExportDestination: Equatable, Sendable { case files, photos }   // .files also serves the share sheet

struct ExportResult: Equatable, Sendable {
    let directory: URL                  // the per-export temp dir; S2b calls discard(_:) when done
    let files: [URL]                    // outputs written, in plan order
    let dropped: [DroppedSegment]       // planner drops + stitcher-unreadable (reason .unreadable)
    let flaggedSegmentIDs: [UUID]       // plan order (output order, then source order)
    let savedToPhotosCount: Int         // 0 for .files
}

/// Orchestrates plan → preflight → stitch → (Photos) with a per-export temp directory that
/// is removed on every exit path after stitching starts (S3 spec §4, step 6: a failed
/// export leaves nothing behind). Authorization resolves before any stitching (decision 5)
/// and space is checked before anything is written (decision 6).
actor Exporter {
    private let segmentDirectory: URL
    private let temporaryRoot: URL
    private let stitcher: any Stitcher
    private let photos: any PhotoLibrarySaving
    private let availableCapacity: @Sendable () -> Int64?
    private let fileSize: @Sendable (URL) -> Int64?

    init(
        segmentDirectory: URL,
        temporaryRoot: URL,                         // production: FileManager.default.temporaryDirectory
        stitcher: any Stitcher,
        photos: any PhotoLibrarySaving,
        availableCapacity: @escaping @Sendable () -> Int64?,   // production: temp volume's important-usage capacity
        fileSize: @escaping @Sendable (URL) -> Int64?          // production: attributesOfItem size
    ) {
        self.segmentDirectory = segmentDirectory
        self.temporaryRoot = temporaryRoot
        self.stitcher = stitcher
        self.photos = photos
        self.availableCapacity = availableCapacity
        self.fileSize = fileSize
    }

    /// `progress(done, total)` is called after each output is stitched (total = planned
    /// outputs). S2b drives its progress UI from it; cancellation is Task cancellation.
    func export(
        entries: [ClipManifestEntry], deck: Deck, sessionDate: Date,
        unit: ExportUnit, destination: ExportDestination,
        progress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) async throws -> ExportResult {
        // Step 1 (.photos only): resolve authorization before any stitching, so a denied
        // user isn't made to wait through an export that can't land.
        if destination == .photos {
            var auth = await photos.addOnlyStatus()
            if auth == .notDetermined {
                auth = await photos.requestAddOnly()
            }
            switch auth {
            case .authorized: break
            case .denied: throw ExportFailure.photosDenied
            case .restricted: throw ExportFailure.photosRestricted
            case .notDetermined: throw ExportFailure.photosDenied
            }
        }

        // Step 2: plan.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let plan = ExportPlanner.plan(
            entries: entries,
            deck: deck,
            sessionDate: sessionDate,
            unit: unit,
            segmentDirectory: segmentDirectory,
            fileSize: fileSize,
            calendar: calendar
        )
        guard !plan.outputs.isEmpty else { throw ExportFailure.nothingToExport }

        // Step 3: preflight space. A floor, not a guarantee — the re-encode fallback can
        // outgrow it, which is why .outOfSpace is still mapped. nil capacity skips the check.
        let neededBytes = Int64(Double(plan.totalSourceBytes) * 1.1)
        if let availableBytes = availableCapacity(), availableBytes < neededBytes {
            throw ExportFailure.insufficientSpace(neededBytes: neededBytes, availableBytes: availableBytes)
        }

        // Step 4: stitch into a fresh per-export temp directory (decision 7 — the engine
        // never writes into the segment directory and never deletes a segment).
        let directory = temporaryRoot
            .appendingPathComponent("Exports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            // segmentID → questionID for every planned segment, to map stitcher-reported
            // unreadable URLs back to segments (S3 spec review, point 5).
            var questionIDBySegment: [UUID: String] = [:]
            for entry in entries {
                for segment in entry.segments {
                    questionIDBySegment[segment.id] = entry.questionID
                }
            }

            var files: [URL] = []
            var dropped = plan.dropped
            var flaggedSegmentIDs: [UUID] = []

            for (index, output) in plan.outputs.enumerated() {
                try Task.checkCancellation()
                let outputURL = directory.appendingPathComponent(output.fileName)
                let report = try await stitcher.stitch(output.sources, to: outputURL)

                for url in report.unreadable {
                    guard let segmentID = SegmentFiles.segmentID(from: url),
                          let questionID = questionIDBySegment[segmentID] else {
                        // A URL that maps to no planned segment is a programming error.
                        assertionFailure("unreadable URL maps to no planned segment: \(url)")
                        continue
                    }
                    dropped.append(DroppedSegment(
                        segmentID: segmentID,
                        questionID: questionID,
                        reason: .unreadable
                    ))
                }

                let unreadableIDs = Set(report.unreadable.compactMap { SegmentFiles.segmentID(from: $0) })
                flaggedSegmentIDs.append(
                    contentsOf: output.flaggedSegmentIDs.filter { !unreadableIDs.contains($0) }
                )

                if report.outputWritten {
                    files.append(outputURL)
                }
                // An output with outputWritten == false contributes no file and continues;
                // its segments are already in `dropped` via its report.
                progress(index + 1, plan.outputs.count)
            }

            guard !files.isEmpty else {
                throw ExportFailure.nothingToExport
            }

            // Step 5 (.photos): save each file in order, then remove the temp directory;
            // `files` stays in the result for reporting. If save k+1 fails after k saves
            // succeeded (k ≥ 1), report exactly how many landed. With k == 0 throw the
            // mapped cause directly. No retry de-duplication in 1.0.
            if destination == .photos {
                var saved = 0
                do {
                    for file in files {
                        try await photos.saveVideo(at: file)
                        saved += 1
                    }
                } catch {
                    let cause = ExportFailure.from(error)
                    if saved >= 1 {
                        throw ExportFailure.partiallySavedToPhotos(
                            saved: saved,
                            total: files.count,
                            cause: cause
                        )
                    }
                    throw cause
                }
                try? FileManager.default.removeItem(at: directory)
            }

            return ExportResult(
                directory: directory,
                files: files,
                dropped: dropped,
                flaggedSegmentIDs: flaggedSegmentIDs,
                savedToPhotosCount: destination == .photos ? files.count : 0
            )
        } catch {
            // Step 6: on any throw after step 4 starts, including cancellation, the temp
            // directory is removed before the error propagates.
            try? FileManager.default.removeItem(at: directory)
            throw ExportFailure.from(error)
        }
    }

    /// Removes a result's temp directory. Idempotent.
    func discard(_ result: ExportResult) {
        try? FileManager.default.removeItem(at: result.directory)
    }

    /// Launch-time sweep: removes every <temporaryRoot>/Exports/* directory. S2b calls it
    /// once at launch, before any export can start (the app has no extensions), so it never
    /// races a live export. Nothing that's still in use survives a relaunch.
    func purgeStaleExports() {
        let exports = temporaryRoot.appendingPathComponent("Exports", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: exports,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in contents {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
