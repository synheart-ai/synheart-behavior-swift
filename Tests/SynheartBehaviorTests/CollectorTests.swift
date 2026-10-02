import XCTest
@testable import SynheartBehavior

final class CollectorTests: XCTestCase {

    // MARK: - Notifications through the public forwarding API

    private func notificationActions(_ sdk: SynheartBehavior) -> [String] {
        sdk.getSessionEvents()
            .filter { $0.eventType == .notification }
            .compactMap { $0.metrics["action"] as? String }
    }

    func testForwardedNotificationReportsArrivalThenOpen() throws {
        let sdk = SynheartBehavior()
        try sdk.initialize()
        _ = try sdk.startSession()

        sdk.notificationDelivered(id: "n1")
        sdk.notificationOpened(id: "n1")

        XCTAssertEqual(notificationActions(sdk), ["received", "opened"])
        sdk.dispose()
    }

    func testOpenWithoutArrivalIsNotReported() throws {
        let sdk = SynheartBehavior()
        try sdk.initialize()
        _ = try sdk.startSession()

        // Delivered in the background, tapped later: no arrival was seen.
        sdk.notificationOpened(id: "background")

        XCTAssertEqual(notificationActions(sdk), [])
        sdk.dispose()
    }

    func testForwardingIsNoOpWithoutAttentionSignals() throws {
        let sdk = SynheartBehavior(config: BehaviorConfig(enableAttentionSignals: false))
        try sdk.initialize()
        _ = try sdk.startSession()

        sdk.notificationDelivered(id: "n1")
        sdk.notificationOpened(id: "n1")

        XCTAssertEqual(notificationActions(sdk), [])
        sdk.dispose()
    }

    func testNotificationDelegateIsNotInstalledByDefault() {
        XCTAssertFalse(BehaviorConfig().installNotificationDelegate)
    }

    // MARK: - Motion

    func testMotionLiteAloneDoesNotSample() {
        let lite = MotionSignalCollector(config: BehaviorConfig(enableMotionLite: true))
        XCTAssertFalse(lite.shouldCollect)
        let raw = MotionSignalCollector(config: BehaviorConfig(emitRawMotionSamples: true))
        XCTAssertTrue(raw.shouldCollect)
    }

    func testFlushHandsOutSessionSamplesInOrderOnMain() {
        let collector = MotionSignalCollector(config: BehaviorConfig(emitRawMotionSamples: true))
        let now = Date().timeIntervalSince1970 * 1_000
        let delivered = expectation(description: "batch")
        var received: [[String: Any]] = []
        collector.setRawSampleBatchHandler { batch in
            XCTAssertTrue(Thread.isMainThread)
            received = batch
            delivered.fulfill()
        }
        collector.startSession(startMs: now - 5_000)
        collector.ingest(tsMs: now - 6_000, x: 9, y: 9, z: 9)   // before the session
        collector.ingest(tsMs: now - 3_000, x: 1, y: 2, z: 3)
        collector.ingest(tsMs: now - 2_000, x: 4, y: 5, z: 6)
        collector.flushBatch(nowMs: now)

        wait(for: [delivered], timeout: 2)
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received.first?["ts_ms"] as? Int64, Int64(now - 3_000))
        XCTAssertEqual(received.last?["ax"] as? Double, 4)
        collector.dispose()
    }

    func testFlushTrimsHistoryOlderThanTenSeconds() {
        let collector = MotionSignalCollector(config: BehaviorConfig(emitRawMotionSamples: true))
        let now = Date().timeIntervalSince1970 * 1_000
        let delivered = expectation(description: "batch")
        collector.setRawSampleBatchHandler { _ in delivered.fulfill() }
        collector.startSession(startMs: now - 20_000)
        collector.ingest(tsMs: now - 15_000, x: 0, y: 0, z: 0)
        collector.ingest(tsMs: now - 1_000, x: 0, y: 0, z: 0)
        collector.flushBatch(nowMs: now)

        wait(for: [delivered], timeout: 2)
        XCTAssertEqual(collector.bufferedSampleCount, 1)
        collector.dispose()
    }

    func testNoBatchWithoutRawSamplesEnabled() {
        let collector = MotionSignalCollector(config: BehaviorConfig(enableMotionLite: true))
        let now = Date().timeIntervalSince1970 * 1_000
        let none = expectation(description: "no batch")
        none.isInverted = true
        collector.setRawSampleBatchHandler { _ in none.fulfill() }
        collector.startSession(startMs: now - 5_000)
        collector.ingest(tsMs: now - 1_000, x: 0, y: 0, z: 0)
        collector.flushBatch(nowMs: now)

        wait(for: [none], timeout: 0.5)
        collector.dispose()
    }
}
