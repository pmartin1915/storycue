import XCTest
@testable import StoryCue

final class MockCaptureServiceTests: XCTestCase {
    func testSimulatedEventsDeliveredInOrder() async {
        let service = MockCaptureService()
        let segmentIDs = [UUID(), UUID(), UUID()]

        // simulate() before any subscriber exists: the unbounded stream buffers, never drops.
        for (index, segmentID) in segmentIDs.enumerated() {
            await service.simulate(.segmentFinished(
                segmentID: segmentID,
                outcome: .saved(url: URL(fileURLWithPath: "/tmp/segment-\(index).mov"))
            ))
        }

        var received: [UUID] = []
        for await event in service.events {
            guard case let .segmentFinished(segmentID, _) = event else {
                return XCTFail("unexpected event \(event)")
            }
            received.append(segmentID)
            if received.count == segmentIDs.count { break }
        }
        XCTAssertEqual(received, segmentIDs)
    }

    func testRequestAuthorizationGrantsNotDetermined() async {
        let service = MockCaptureService()
        await service.setStubAuthorization(CaptureAuthorization(camera: .notDetermined, microphone: .notDetermined))

        let granted = await service.requestAuthorization()

        let requestAuthorizationCount = await service.requestAuthorizationCount
        XCTAssertEqual(granted, CaptureAuthorization(camera: .authorized, microphone: .authorized))
        XCTAssertEqual(requestAuthorizationCount, 1)
    }

    func testStartStopSegmentCallsRecorded() async throws {
        let service = MockCaptureService()
        let segmentID = UUID()

        try await service.startSegment(id: segmentID, for: "grandparents.001")
        await service.stopSegment(segmentID)

        let started = await service.startedSegments
        let stopped = await service.stoppedSegmentIDs
        XCTAssertEqual(started, [MockCaptureService.RecordedStart(id: segmentID, questionID: "grandparents.001")])
        XCTAssertEqual(stopped, [segmentID])
    }
}
