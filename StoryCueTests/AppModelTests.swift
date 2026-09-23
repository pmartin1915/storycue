import XCTest
@testable import StoryCue

/// AppModel session-lifetime tests (spec §6). Factories return MockCaptureService /
/// FakeBackgroundTaskRunner and count their calls.
@MainActor
final class AppModelTests: XCTestCase {
    private let deck = Deck.v1Decks[0]

    private final class FactorySpy {
        var captureCallCount = 0
        var backgroundCallCount = 0
        var captures: [MockCaptureService] = []
    }

    private func makeModel(spy: FactorySpy = FactorySpy()) -> AppModel {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return AppModel(
            segmentDirectory: directory,
            makeCapture: { _ in
                spy.captureCallCount += 1
                let mock = MockCaptureService()
                spy.captures.append(mock)
                return mock
            },
            makeBackground: {
                spy.backgroundCallCount += 1
                return FakeBackgroundTaskRunner()
            }
        )
    }

    func testInitConstructsNoCapture() {
        let spy = FactorySpy()
        _ = makeModel(spy: spy)
        XCTAssertEqual(spy.captureCallCount, 0)
        XCTAssertEqual(spy.backgroundCallCount, 0)
    }

    func testBeginSessionPreparesCapture() async {
        let spy = FactorySpy()
        let model = makeModel(spy: spy)

        await model.beginSession(deck: deck)

        XCTAssertNotNil(model.active)
        XCTAssertEqual(spy.captureCallCount, 1)
        let mock = spy.captures[0]
        XCTAssertEqual(await mock.requestAuthorizationCount, 1)
        XCTAssertEqual(model.active?.store.captureAvailability, .ready)
    }

    func testBeginSessionTwiceIsNoOp() async {
        let spy = FactorySpy()
        let model = makeModel(spy: spy)

        await model.beginSession(deck: deck)
        await model.beginSession(deck: deck)

        XCTAssertEqual(spy.captureCallCount, 1)
    }

    func testEndSessionRefusedWhileRecording() async {
        let model = makeModel()
        await model.beginSession(deck: deck)
        guard let store = model.active?.store else { return XCTFail("expected an active session") }

        store.send(.tapRecord)
        await store.waitForIdleEffects()
        guard case .recording = store.state.phase else {
            return XCTFail("expected .recording, got \(store.state.phase)")
        }

        let ended = await model.endSession()
        XCTAssertFalse(ended)
        XCTAssertNotNil(model.active)
        let mock = model.active!.capture as? MockCaptureService
        XCTAssertEqual(await mock?.shutdownCount, 0)
    }

    func testEndSessionShutsDownCapture() async {
        let model = makeModel()
        await model.beginSession(deck: deck)
        guard let active = model.active else { return XCTFail("expected an active session") }

        let ended = await model.endSession()
        XCTAssertTrue(ended)
        XCTAssertNil(model.active)
        let mock = active.capture as? MockCaptureService
        XCTAssertEqual(await mock?.shutdownCount, 1)
    }

    func testNewSessionGetsFreshCapture() async {
        let spy = FactorySpy()
        let model = makeModel(spy: spy)

        await model.beginSession(deck: deck)
        let first = model.active
        _ = await model.endSession()
        await model.beginSession(deck: deck)
        let second = model.active

        XCTAssertEqual(spy.captureCallCount, 2)
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertNotEqual(
            ObjectIdentifier(first!.store),
            ObjectIdentifier(second!.store)
        )
        XCTAssertNotEqual(
            ObjectIdentifier(first!.capture as AnyObject),
            ObjectIdentifier(second!.capture as AnyObject)
        )
    }

    func testEndSessionRefusedWhilePreparing() async {
        // A mock whose requestAuthorization suspends: endSession() called DURING
        // beginSession must refuse, and succeed once beginSession returns.
        let mock = MockCaptureService()
        await mock.setStubAuthorizationDelay(0.3)
        var factoryCalls = 0
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let model = AppModel(
            segmentDirectory: directory,
            makeCapture: { _ in
                factoryCalls += 1
                return mock
            },
            makeBackground: { FakeBackgroundTaskRunner() }
        )

        let beginTask = Task { await model.beginSession(deck: deck) }
        while !model.isPreparing {
            await Task.yield()
        }

        let refused = await model.endSession()
        XCTAssertFalse(refused)
        XCTAssertNotNil(model.active)

        await beginTask.value
        XCTAssertEqual(model.active?.store.captureAvailability, .ready)
        let ended = await model.endSession()
        XCTAssertTrue(ended)
        XCTAssertNil(model.active)
        XCTAssertEqual(factoryCalls, 1)
    }

    func testInfoPlistPortraitOnly() {
        let orientations = Bundle(for: AppModel.self).infoDictionary?["UISupportedInterfaceOrientations"] as? [String]
        XCTAssertEqual(orientations, ["UIInterfaceOrientationPortrait"])
    }
}
