import Foundation
@testable import StoryCue

/// Test doubles for the export engine (S3 spec §6). Not in the app target.
///
/// `MockStitcher` records calls, writes a 1-byte file at `output`, and can be configured
/// per source URL to report unreadable, throw, or wait for a continuation so cancellation
/// can be tested. It mirrors AVStitcher's contract: unreadable sources are reported and
/// skipped; only an all-unreadable call writes nothing (`outputWritten == false`).
actor MockStitcher: Stitcher {
    struct Call: Equatable, Sendable {
        let sources: [URL]
        let output: URL
    }

    private(set) var calls: [Call] = []

    // Per-source behaviors. Set through the setters: actor state can't be assigned from
    // outside the actor, even with `await`.
    private var unreadableSources: Set<URL> = []
    private var throwingSources: [URL: Error] = [:]
    private var stallNextCall = false
    private var stallContinuation: CheckedContinuation<Void, Never>?

    func setUnreadable(_ urls: Set<URL>) { unreadableSources = urls }
    func setThrowing(_ url: URL, error: Error) { throwingSources[url] = error }
    func setStallNextCall() { stallNextCall = true }

    /// Resumes a stalled stitch, if any. Safe to call when nothing is stalled.
    func resolveStall() {
        stallContinuation?.resume()
        stallContinuation = nil
    }

    /// Polls until `calls.count >= count` — the deterministic point to cancel or resolve.
    func waitForCalls(_ count: Int) async {
        while calls.count < count {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Polls until a stitch call is parked on its continuation (so resolveStall can't race
    /// the park itself and leak the continuation).
    func waitForStall() async {
        while stallContinuation == nil {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func stitch(_ sources: [URL], to output: URL) async throws -> StitchReport {
        calls.append(Call(sources: sources, output: output))

        if let throwing = sources.compactMap({ throwingSources[$0] }).first {
            throw throwing
        }

        if stallNextCall {
            stallNextCall = false
            await withCheckedContinuation { continuation in
                stallContinuation = continuation
            }
            // The test cancels the exporting Task while we are parked; surface it.
            try Task.checkCancellation()
        }

        let unreadable = sources.filter { unreadableSources.contains($0) }
        let readableCount = sources.count - unreadable.count
        guard readableCount > 0 else {
            return StitchReport(unreadable: unreadable, durationSeconds: 0, outputWritten: false)
        }
        try Data([0x00]).write(to: output)
        return StitchReport(
            unreadable: unreadable,
            durationSeconds: Double(readableCount),
            outputWritten: true
        )
    }
}

/// Configurable status and request result, records saved URLs, can throw on the k-th
/// save (0-based) so partial Photos saves can be tested.
actor MockPhotoLibrary: PhotoLibrarySaving {
    private(set) var savedURLs: [URL] = []
    private(set) var requestCount = 0

    private var status: PhotoAddAuth
    private var requestResult: PhotoAddAuth
    private var error: Error?
    private var failureOnSaveIndex: Int?

    init(status: PhotoAddAuth = .authorized, requestResult: PhotoAddAuth = .authorized) {
        self.status = status
        self.requestResult = requestResult
    }

    func setStatus(_ value: PhotoAddAuth) { status = value }
    func setRequestResult(_ value: PhotoAddAuth) { requestResult = value }

    /// Throws `error` from the save call whose 0-based index is `index`.
    func setFailure(onSaveIndex index: Int, error: Error) {
        failureOnSaveIndex = index
        self.error = error
    }

    func addOnlyStatus() async -> PhotoAddAuth {
        status
    }

    func requestAddOnly() async -> PhotoAddAuth {
        requestCount += 1
        return requestResult
    }

    func saveVideo(at url: URL) async throws {
        if savedURLs.count == failureOnSaveIndex, let error {
            throw error
        }
        savedURLs.append(url)
    }
}

/// Collects progress callbacks. The Exporter's progress closure is @Sendable, so the
/// recorder it captures must be Sendable — an actor is the simplest Sendable box.
actor ProgressRecorder {
    private(set) var calls: [(done: Int, total: Int)] = []

    func record(_ done: Int, _ total: Int) {
        calls.append((done: done, total: total))
    }
}
