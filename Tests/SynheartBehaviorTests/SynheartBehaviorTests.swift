import XCTest
@testable import SynheartBehavior

final class SynheartBehaviorTests: XCTestCase {
    var sdk: SynheartBehavior!

    override func setUp() {
        super.setUp()
        sdk = SynheartBehavior()
    }

    override func tearDown() {
        sdk?.dispose()
        sdk = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() throws {
        XCTAssertNoThrow(try sdk.initialize())
    }

    func testDoubleInitialization() throws {
        try sdk.initialize()
        XCTAssertNoThrow(try sdk.initialize())  // Should not throw
    }

    func testInitializationWithCustomConfig() throws {
        let config = BehaviorConfig(
            enableInputSignals: true,
            enableAttentionSignals: false,
            enableMotionLite: false,
            sessionIdPrefix: "TEST",
            eventBatchSize: 20,
            maxIdleGapSeconds: 15.0
        )
        sdk = SynheartBehavior(config: config)
        XCTAssertNoThrow(try sdk.initialize())
    }

    func testThrowsErrorWhenNotInitialized() {
        XCTAssertThrowsError(try sdk.startSession()) { error in
            XCTAssertEqual(error as? BehaviorError, .notInitialized)
        }

        XCTAssertThrowsError(try sdk.endSession(sessionId: "test")) { error in
            XCTAssertEqual(error as? BehaviorError, .notInitialized)
        }

        XCTAssertThrowsError(try sdk.getCurrentStats()) { error in
            XCTAssertEqual(error as? BehaviorError, .notInitialized)
        }
    }

    // MARK: - Session Management Tests

    func testStartSession() throws {
        try sdk.initialize()
        let sessionId = try sdk.startSession()
        XCTAssertFalse(sessionId.isEmpty)
        XCTAssertTrue(sessionId.hasPrefix("SESS-"))
    }

    func testStartSessionWithCustomId() throws {
        try sdk.initialize()
        let customId = "CUSTOM-123"
        let sessionId = try sdk.startSession(sessionId: customId)
        XCTAssertEqual(sessionId, customId)
    }

    func testStartSessionWithCustomPrefix() throws {
        let config = BehaviorConfig(sessionIdPrefix: "MYAPP")
        sdk = SynheartBehavior(config: config)
        try sdk.initialize()

        let sessionId = try sdk.startSession()
        XCTAssertTrue(sessionId.hasPrefix("MYAPP-"))
    }

    func testEndSession() throws {
        try sdk.initialize()
        let sessionId = try sdk.startSession()

        // Wait a bit to accumulate some duration
        Thread.sleep(forTimeInterval: 0.1)

        let summary = try sdk.endSession(sessionId: sessionId)
        XCTAssertEqual(summary.sessionId, sessionId)
        XCTAssertGreaterThan(summary.duration, 0)
        XCTAssertGreaterThan(summary.endTimestamp, summary.startTimestamp)
    }

    func testEndSessionWithInvalidId() throws {
        try sdk.initialize()
        _ = try sdk.startSession()

        XCTAssertThrowsError(try sdk.endSession(sessionId: "invalid-id")) { error in
            XCTAssertEqual(error as? BehaviorError, .sessionNotFound)
        }
    }

    // MARK: - Event Handler Tests

    func testEventHandlerReceivesEvents() throws {
        try sdk.initialize()

        let expectation = self.expectation(description: "Event received")
        var receivedEvent: BehaviorEvent?

        sdk.setEventHandler { event in
            receivedEvent = event
            expectation.fulfill()
        }

        let sessionId = try sdk.startSession()

        // Simulate an event (in real app, this would come from user interaction)
        let testEvent = BehaviorEvent(
            sessionId: sessionId,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            type: .typingCadence,
            payload: ["cadence": 5.0]
        )
        sdk.emitEvent(testEvent)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.type, .typingCadence)
    }

    func testBatchEventHandler() throws {
        try sdk.initialize()

        let expectation = self.expectation(description: "Batch received")
        var receivedBatch: [BehaviorEvent]?

        sdk.setBatchEventHandler { events in
            receivedBatch = events
            expectation.fulfill()
        }

        let sessionId = try sdk.startSession()

        // Emit enough events to trigger batch (default batch size is 10)
        for i in 0..<10 {
            let event = BehaviorEvent(
                sessionId: sessionId,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                type: .typingCadence,
                payload: ["cadence": Double(i)]
            )
            sdk.emitEvent(event)
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedBatch)
        XCTAssertEqual(receivedBatch?.count, 10)
    }

    // MARK: - Statistics Tests

    func testGetCurrentStats() throws {
        try sdk.initialize()
        _ = try sdk.startSession()

        let stats = try sdk.getCurrentStats()
        XCTAssertNotNil(stats)
        XCTAssertGreaterThan(stats.timestamp, 0)
    }

    // MARK: - Configuration Tests

    func testUpdateConfig() throws {
        try sdk.initialize()

        let newConfig = BehaviorConfig(
            enableInputSignals: false,
            enableAttentionSignals: true,
            eventBatchSize: 25
        )

        XCTAssertNoThrow(try sdk.updateConfig(newConfig))
    }

    func testUpdateConfigWhenNotInitialized() {
        let newConfig = BehaviorConfig()

        XCTAssertThrowsError(try sdk.updateConfig(newConfig)) { error in
            XCTAssertEqual(error as? BehaviorError, .notInitialized)
        }
    }

    // MARK: - Disposal Tests

    func testDispose() throws {
        try sdk.initialize()
        _ = try sdk.startSession()

        sdk.dispose()

        // Should throw error after disposal
        XCTAssertThrowsError(try sdk.getCurrentStats()) { error in
            XCTAssertEqual(error as? BehaviorError, .notInitialized)
        }
    }

    // MARK: - BehaviorConfig Tests

    func testBehaviorConfigDefaults() {
        let config = BehaviorConfig()

        XCTAssertTrue(config.enableInputSignals)
        XCTAssertTrue(config.enableAttentionSignals)
        XCTAssertFalse(config.enableMotionLite)
        XCTAssertNil(config.sessionIdPrefix)
        XCTAssertEqual(config.eventBatchSize, 10)
        XCTAssertEqual(config.maxIdleGapSeconds, 10.0)
    }

    func testBehaviorConfigToDictionary() {
        let config = BehaviorConfig(
            enableInputSignals: true,
            enableAttentionSignals: false,
            enableMotionLite: true,
            sessionIdPrefix: "TEST",
            eventBatchSize: 20,
            maxIdleGapSeconds: 15.0
        )

        let dict = config.toDictionary()

        XCTAssertEqual(dict["enableInputSignals"] as? Bool, true)
        XCTAssertEqual(dict["enableAttentionSignals"] as? Bool, false)
        XCTAssertEqual(dict["enableMotionLite"] as? Bool, true)
        XCTAssertEqual(dict["sessionIdPrefix"] as? String, "TEST")
        XCTAssertEqual(dict["eventBatchSize"] as? Int, 20)
        XCTAssertEqual(dict["maxIdleGapSeconds"] as? Double, 15.0)
    }

    // MARK: - BehaviorEvent Tests

    func testBehaviorEventCreation() {
        let event = BehaviorEvent(
            sessionId: "test-session",
            timestamp: 123456789,
            type: .typingCadence,
            payload: ["cadence": 5.5, "inter_key_latency_ms": 100.0]
        )

        XCTAssertEqual(event.sessionId, "test-session")
        XCTAssertEqual(event.timestamp, 123456789)
        XCTAssertEqual(event.type, .typingCadence)
        XCTAssertEqual(event.payload["cadence"] as? Double, 5.5)
    }

    func testBehaviorEventToDictionary() {
        let event = BehaviorEvent(
            sessionId: "test-session",
            timestamp: 123456789,
            type: .scrollVelocity,
            payload: ["velocity": 150.0]
        )

        let dict = event.toDictionary()

        XCTAssertEqual(dict["session_id"] as? String, "test-session")
        XCTAssertEqual(dict["timestamp"] as? Int64, 123456789)
        XCTAssertEqual(dict["type"] as? String, "scrollVelocity")
        XCTAssertNotNil(dict["payload"])
    }

    // MARK: - BehaviorSessionSummary Tests

    func testBehaviorSessionSummaryToDictionary() {
        let summary = BehaviorSessionSummary(
            sessionId: "test-session",
            startTimestamp: 1000,
            endTimestamp: 5000,
            duration: 4000,
            eventCount: 42,
            averageTypingCadence: 5.5,
            averageScrollVelocity: 120.0,
            appSwitchCount: 3,
            stabilityIndex: 0.85,
            fragmentationIndex: 0.15
        )

        let dict = summary.toDictionary()

        XCTAssertEqual(dict["session_id"] as? String, "test-session")
        XCTAssertEqual(dict["duration"] as? Int64, 4000)
        XCTAssertEqual(dict["event_count"] as? Int, 42)
        XCTAssertEqual(dict["average_typing_cadence"] as? Double, 5.5)
        XCTAssertEqual(dict["app_switch_count"] as? Int, 3)
    }

    // MARK: - BehaviorStats Tests

    func testBehaviorStatsToDictionary() {
        let stats = BehaviorStats(
            typingCadence: 5.0,
            interKeyLatency: 120.0,
            burstLength: 5,
            scrollVelocity: 150.0,
            scrollAcceleration: 10.0,
            scrollJitter: 2.5,
            tapRate: 1.2,
            appSwitchesPerMinute: 2,
            foregroundDuration: 300.0,
            idleGapSeconds: 5.0,
            stabilityIndex: 0.9,
            fragmentationIndex: 0.1,
            timestamp: 123456789
        )

        let dict = stats.toDictionary()

        XCTAssertEqual(dict["typing_cadence"] as? Double, 5.0)
        XCTAssertEqual(dict["burst_length"] as? Int, 5)
        XCTAssertEqual(dict["scroll_velocity"] as? Double, 150.0)
        XCTAssertEqual(dict["tap_rate"] as? Double, 1.2)
        XCTAssertEqual(dict["timestamp"] as? Int64, 123456789)
    }
}

// MARK: - BehaviorError Equatable Extension for Testing
extension BehaviorError: Equatable {
    public static func == (lhs: BehaviorError, rhs: BehaviorError) -> Bool {
        switch (lhs, rhs) {
        case (.notInitialized, .notInitialized),
             (.invalidConfiguration, .invalidConfiguration),
             (.sessionNotFound, .sessionNotFound):
            return true
        default:
            return false
        }
    }
}
