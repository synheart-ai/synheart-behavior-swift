import XCTest
@testable import SynheartBehavior

final class InterruptionTrackersTests: XCTestCase {
    private let a = UUID()

    func testAnsweredCallReportsOnceAndHangUpIsSilent() {
        var t = CallOutcomeTracker()
        XCTAssertNil(t.update(id: a, isOutgoing: false, hasConnected: false, hasEnded: false, nowMs: 0))
        XCTAssertEqual(t.update(id: a, isOutgoing: false, hasConnected: true, hasEnded: false, nowMs: 3_000), "answered")
        XCTAssertNil(t.update(id: a, isOutgoing: false, hasConnected: true, hasEnded: false, nowMs: 4_000), "no second answered")
        XCTAssertNil(t.update(id: a, isOutgoing: false, hasConnected: true, hasEnded: true, nowMs: 60_000), "hang-up is not an event")
    }

    func testUnansweredCallReportsIgnoredOnce() {
        var t = CallOutcomeTracker()
        XCTAssertNil(t.update(id: a, isOutgoing: false, hasConnected: false, hasEnded: false, nowMs: 0))
        XCTAssertEqual(t.update(id: a, isOutgoing: false, hasConnected: false, hasEnded: true, nowMs: 8_000), "ignored")
        XCTAssertNil(t.update(id: a, isOutgoing: false, hasConnected: false, hasEnded: true, nowMs: 9_000), "already reported")
    }

    func testVeryShortRingIsNotAnIgnoredCall() {
        var t = CallOutcomeTracker()
        _ = t.update(id: a, isOutgoing: false, hasConnected: false, hasEnded: false, nowMs: 0)
        XCTAssertNil(t.update(id: a, isOutgoing: false, hasConnected: false, hasEnded: true, nowMs: 500))
    }

    func testOutgoingCallsAreNotInterruptions() {
        var t = CallOutcomeTracker()
        XCTAssertNil(t.update(id: a, isOutgoing: true, hasConnected: false, hasEnded: false, nowMs: 0))
        XCTAssertNil(t.update(id: a, isOutgoing: true, hasConnected: true, hasEnded: false, nowMs: 1_000))
        XCTAssertNil(t.update(id: a, isOutgoing: true, hasConnected: true, hasEnded: true, nowMs: 9_000))
    }

    func testNotificationArrivalThenOneOutcome() {
        var t = NotificationOutcomeTracker()
        XCTAssertTrue(t.received(id: "n1", atMs: 0))
        XCTAssertFalse(t.received(id: "n1", atMs: 10), "a re-delivery is not a second arrival")
        XCTAssertTrue(t.opened(id: "n1"))
        XCTAssertFalse(t.expired(id: "n1"), "opened notifications never also expire")
        XCTAssertTrue(t.received(id: "n2", atMs: 20))
        XCTAssertTrue(t.expired(id: "n2"))
        XCTAssertFalse(t.opened(id: "n2"), "an expired notification cannot also open")
        XCTAssertEqual(t.pendingCount, 0)
    }

    func testNotificationTrackerBoundsItsMemory() {
        var t = NotificationOutcomeTracker(capacity: 3)
        for i in 0..<10 { _ = t.received(id: "n\(i)", atMs: Double(i)) }
        XCTAssertEqual(t.pendingCount, 3)
        XCTAssertFalse(t.opened(id: "n0"), "evicted")
        XCTAssertTrue(t.opened(id: "n9"))
    }

    func testRawMotionFlagDefaultsOffAndRoundTrips() {
        XCTAssertFalse(BehaviorConfig().emitRawMotionSamples)
        let on = BehaviorConfig(emitRawMotionSamples: true)
        XCTAssertTrue(on.emitRawMotionSamples)
        XCTAssertEqual(on.toDictionary()["emitRawMotionSamples"] as? Bool, true)
    }

    func testMotionCollectorBatchesSamplesSinceLastFlush() {
        let collector = MotionSignalCollector(config: BehaviorConfig(emitRawMotionSamples: true))
        var batches: [[[String: Any]]] = []
        collector.setRawSampleBatchHandler { batches.append($0) }
        let start = Date().timeIntervalSince1970 * 1_000 - 100
        collector.startSession(startMs: start)
        collector.ingest(tsMs: start + 10, x: 0, y: 0, z: 9.81)
        collector.ingest(tsMs: start + 30, x: 0.1, y: 0, z: 9.7)
        collector.flushBatch()
        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches[0].count, 2)
        XCTAssertEqual(batches[0][0]["az"] as? Double, 9.81)
        XCTAssertNotNil(batches[0][0]["ts_ms"] as? Int64)
        collector.flushBatch()
        XCTAssertEqual(batches.count, 1, "an empty interval emits nothing")
        collector.endSession()
    }

    func testAttentionSignalsInitializeWithCollectorsOnEveryPlatform() throws {
        let sdk = SynheartBehavior(config: BehaviorConfig(enableInputSignals: false, enableAttentionSignals: true))
        XCTAssertNoThrow(try sdk.initialize())
        sdk.dispose()
    }
}
