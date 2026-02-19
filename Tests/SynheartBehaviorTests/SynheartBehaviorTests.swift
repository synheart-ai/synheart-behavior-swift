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
            maxIdleGapSeconds: 15.0,
            consentBehavior: true
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

        // Simulate an event using factory method
        let testEvent = BehaviorEvent.typing(sessionId: sessionId, typingSpeed: 5.0)
        sdk.sendEvent(testEvent)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.type, .typing)
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
            let event = BehaviorEvent.typing(sessionId: sessionId, typingSpeed: Double(i))
            sdk.sendEvent(event)
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
        XCTAssertNil(config.userId)
        XCTAssertNil(config.deviceId)
        XCTAssertEqual(config.behaviorVersion, "1.0.0")
        XCTAssertTrue(config.consentBehavior)
    }

    func testBehaviorConfigToDictionary() {
        let config = BehaviorConfig(
            enableInputSignals: true,
            enableAttentionSignals: false,
            enableMotionLite: true,
            sessionIdPrefix: "TEST",
            eventBatchSize: 20,
            maxIdleGapSeconds: 15.0,
            userId: "user-123",
            deviceId: "device-456",
            behaviorVersion: "2.0.0",
            consentBehavior: false
        )

        let dict = config.toDictionary()

        XCTAssertEqual(dict["enableInputSignals"] as? Bool, true)
        XCTAssertEqual(dict["enableAttentionSignals"] as? Bool, false)
        XCTAssertEqual(dict["enableMotionLite"] as? Bool, true)
        XCTAssertEqual(dict["sessionIdPrefix"] as? String, "TEST")
        XCTAssertEqual(dict["eventBatchSize"] as? Int, 20)
        XCTAssertEqual(dict["maxIdleGapSeconds"] as? Double, 15.0)
        XCTAssertEqual(dict["userId"] as? String, "user-123")
        XCTAssertEqual(dict["deviceId"] as? String, "device-456")
        XCTAssertEqual(dict["behaviorVersion"] as? String, "2.0.0")
        XCTAssertEqual(dict["consentBehavior"] as? Bool, false)
    }

    // MARK: - BehaviorEvent Tests

    func testBehaviorEventCreation() {
        let event = BehaviorEvent.typing(
            sessionId: "test-session",
            typingTapCount: 10,
            typingSpeed: 5.5,
            meanInterTapIntervalMs: 100.0
        )

        XCTAssertEqual(event.sessionId, "test-session")
        XCTAssertFalse(event.timestamp.isEmpty)
        XCTAssertEqual(event.type, .typing)
        XCTAssertFalse(event.eventId.isEmpty)
        XCTAssertEqual(event.payload["typing_speed"] as? Double, 5.5)
        XCTAssertEqual(event.payload["typing_tap_count"] as? Int, 10)
    }

    func testBehaviorEventToDictionary() {
        let event = BehaviorEvent.scroll(
            sessionId: "test-session",
            velocity: 150.0,
            direction: "down"
        )

        let dict = event.toDictionary()
        let eventDict = dict["event"] as? [String: Any]

        XCTAssertNotNil(eventDict)
        XCTAssertEqual(eventDict?["session_id"] as? String, "test-session")
        XCTAssertFalse((eventDict?["timestamp"] as? String ?? "").isEmpty)
        XCTAssertEqual(eventDict?["event_type"] as? String, "scroll")
        XCTAssertNotNil(eventDict?["event_id"])
        XCTAssertNotNil(eventDict?["metrics"])
    }

    func testBehaviorEventFactoryScroll() {
        let event = BehaviorEvent.scroll(
            sessionId: "s1",
            velocity: 120.5,
            acceleration: 10.0,
            direction: "up",
            directionReversal: true
        )

        XCTAssertEqual(event.type, .scroll)
        XCTAssertEqual(event.payload["velocity"] as? Double, 120.5)
        XCTAssertEqual(event.payload["acceleration"] as? Double, 10.0)
        XCTAssertEqual(event.payload["direction"] as? String, "up")
        XCTAssertEqual(event.payload["direction_reversal"] as? Bool, true)
    }

    func testBehaviorEventFactoryTap() {
        let event = BehaviorEvent.tap(
            sessionId: "s1",
            tapDurationMs: 85,
            longPress: false
        )

        XCTAssertEqual(event.type, .tap)
        XCTAssertEqual(event.payload["tap_duration_ms"] as? Double, 85)
        XCTAssertEqual(event.payload["long_press"] as? Bool, false)
    }

    func testBehaviorEventFactorySwipe() {
        let event = BehaviorEvent.swipe(
            sessionId: "s1",
            direction: "left",
            distancePx: 200.0,
            velocity: 500.0
        )

        XCTAssertEqual(event.type, .swipe)
        XCTAssertEqual(event.payload["direction"] as? String, "left")
        XCTAssertEqual(event.payload["distance_px"] as? Double, 200.0)
        XCTAssertEqual(event.payload["velocity"] as? Double, 500.0)
    }

    func testBehaviorEventFactoryNotification() {
        let event = BehaviorEvent.notification(sessionId: "s1", action: "ignored")

        XCTAssertEqual(event.type, .notification)
        XCTAssertEqual(event.payload["action"] as? String, "ignored")
    }

    func testBehaviorEventFactoryCall() {
        let event = BehaviorEvent.call(sessionId: "s1", action: "answered")

        XCTAssertEqual(event.type, .call)
        XCTAssertEqual(event.payload["action"] as? String, "answered")
    }

    func testBehaviorEventFactoryTyping() {
        let event = BehaviorEvent.typing(
            sessionId: "s1",
            typingTapCount: 45,
            typingSpeed: 3.2,
            typingBurstiness: 0.6,
            deepTyping: true
        )

        XCTAssertEqual(event.type, .typing)
        XCTAssertEqual(event.payload["typing_tap_count"] as? Int, 45)
        XCTAssertEqual(event.payload["typing_speed"] as? Double, 3.2)
        XCTAssertEqual(event.payload["typing_burstiness"] as? Double, 0.6)
        XCTAssertEqual(event.payload["deep_typing"] as? Bool, true)
    }

    func testBehaviorEventFactoryClipboard() {
        let event = BehaviorEvent.clipboard(sessionId: "s1", action: "copy", context: "textField")

        XCTAssertEqual(event.type, .clipboard)
        XCTAssertEqual(event.payload["action"] as? String, "copy")
        XCTAssertEqual(event.payload["context"] as? String, "textField")
    }

    func testBehaviorEventFactoryAppSwitch() {
        let event = BehaviorEvent.appSwitch(sessionId: "s1")

        XCTAssertEqual(event.type, .appSwitch)
        XCTAssertTrue(event.payload.isEmpty)
    }

    func testBehaviorEventFactoryAppSwitchWithAction() {
        let event = BehaviorEvent.appSwitch(
            sessionId: "s1",
            action: "session_stability",
            metrics: [
                "stability_index": 0.9
            ]
        )

        XCTAssertEqual(event.type, .appSwitch)
        XCTAssertEqual(event.payload["action"] as? String, "session_stability")
        XCTAssertEqual(event.payload["stability_index"] as? Double, 0.9)
    }

    func testBehaviorEventTimestampIsISO8601() {
        let event = BehaviorEvent.tap(sessionId: "s1")

        // Verify the timestamp is a valid ISO 8601 string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: event.timestamp)
        XCTAssertNotNil(date, "Timestamp should be valid ISO 8601: \(event.timestamp)")
    }

    func testBehaviorEventIdIsUnique() {
        let event1 = BehaviorEvent.tap(sessionId: "s1")
        let event2 = BehaviorEvent.tap(sessionId: "s1")

        XCTAssertNotEqual(event1.eventId, event2.eventId)
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
            fragmentationIndex: 0.15,
            behavioralMetrics: [
                "interactionIntensity": 0.7,
                "behavioralFocusHint": 0.8
            ],
            typingMetrics: [
                "typingCadence": 5.5,
                "typingBurstiness": 0.3
            ],
            deepFocusBlocks: [
                ["startAt": "2025-01-01T00:00:00Z", "endAt": "2025-01-01T00:05:00Z", "durationMs": 300000]
            ]
        )

        let dict = summary.toDictionary()

        XCTAssertEqual(dict["session_id"] as? String, "test-session")
        XCTAssertEqual(dict["duration"] as? Int64, 4000)
        XCTAssertEqual(dict["event_count"] as? Int, 42)
        XCTAssertEqual(dict["average_typing_cadence"] as? Double, 5.5)
        XCTAssertEqual(dict["app_switch_count"] as? Int, 3)
        XCTAssertNotNil(dict["behavioral_metrics"])
        XCTAssertNotNil(dict["typing_metrics"])
        XCTAssertNotNil(dict["deep_focus_blocks"])

        let behavioralMetrics = dict["behavioral_metrics"] as? [String: Any]
        XCTAssertEqual(behavioralMetrics?["interactionIntensity"] as? Double, 0.7)
        XCTAssertEqual(behavioralMetrics?["behavioralFocusHint"] as? Double, 0.8)
    }

    func testBehaviorSessionSummaryNewFieldsDefaults() {
        let summary = BehaviorSessionSummary(
            sessionId: "test",
            startTimestamp: 0,
            endTimestamp: 1000,
            duration: 1000
        )

        XCTAssertNil(summary.behavioralMetrics)
        XCTAssertNil(summary.typingMetrics)
        XCTAssertNil(summary.deepFocusBlocks)
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

 
