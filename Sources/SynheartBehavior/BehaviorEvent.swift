import Foundation

/// Types of behavioral events that can be emitted by the SDK.
/// Raw values use the SDK's wire format.
public enum BehaviorEventType: String {
    case scroll = "scroll"
    case tap = "tap"
    case swipe = "swipe"
    case notification = "notification"
    case call = "call"
    case typing = "typing"
    case clipboard = "clipboard"
    case appSwitch = "appSwitch"
}

/// A single behavioral event emitted by the SDK.
public struct BehaviorEvent {
    /// Unique event ID.
    public let eventId: String

    /// Unique session ID for this event.
    public let sessionId: String

    /// Timestamp in ISO 8601 format (e.g., "2025-03-14T10:15:23.456Z").
    public let timestamp: String

    /// Type of behavioral event.
    public let type: BehaviorEventType

    /// Event-specific metrics/payload dictionary.
    public let payload: [String: Any]

    /// ISO 8601 date formatter for generating timestamps.
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public init(
        eventId: String = UUID().uuidString,
        sessionId: String,
        timestamp: String? = nil,
        type: BehaviorEventType,
        payload: [String: Any] = [:]
    ) {
        self.eventId = eventId
        self.sessionId = sessionId
        self.timestamp = timestamp ?? BehaviorEvent.isoFormatter.string(from: Date())
        self.type = type
        self.payload = payload
    }

    // MARK: - Factory Methods

    /// Create a scroll event.
    public static func scroll(
        sessionId: String,
        velocity: Double,
        acceleration: Double? = nil,
        direction: String? = nil,
        directionReversal: Bool = false
    ) -> BehaviorEvent {
        var metrics: [String: Any] = [
            "velocity": velocity,
            "direction_reversal": directionReversal
        ]
        if let acceleration = acceleration { metrics["acceleration"] = acceleration }
        if let direction = direction { metrics["direction"] = direction }

        return BehaviorEvent(
            sessionId: sessionId,
            type: .scroll,
            payload: metrics
        )
    }

    /// Create a tap event.
    public static func tap(
        sessionId: String,
        tapDurationMs: Double? = nil,
        longPress: Bool = false
    ) -> BehaviorEvent {
        var metrics: [String: Any] = [
            "long_press": longPress
        ]
        if let tapDurationMs = tapDurationMs { metrics["tap_duration_ms"] = tapDurationMs }

        return BehaviorEvent(
            sessionId: sessionId,
            type: .tap,
            payload: metrics
        )
    }

    /// Create a swipe event.
    public static func swipe(
        sessionId: String,
        direction: String,
        distancePx: Double? = nil,
        durationMs: Double? = nil,
        velocity: Double? = nil,
        acceleration: Double? = nil
    ) -> BehaviorEvent {
        var metrics: [String: Any] = [
            "direction": direction
        ]
        if let distancePx = distancePx { metrics["distance_px"] = distancePx }
        if let durationMs = durationMs { metrics["duration_ms"] = durationMs }
        if let velocity = velocity { metrics["velocity"] = velocity }
        if let acceleration = acceleration { metrics["acceleration"] = acceleration }

        return BehaviorEvent(
            sessionId: sessionId,
            type: .swipe,
            payload: metrics
        )
    }

    /// Create a notification event.
    public static func notification(
        sessionId: String,
        action: String
    ) -> BehaviorEvent {
        return BehaviorEvent(
            sessionId: sessionId,
            type: .notification,
            payload: ["action": action]
        )
    }

    /// Create a call event.
    public static func call(
        sessionId: String,
        action: String
    ) -> BehaviorEvent {
        return BehaviorEvent(
            sessionId: sessionId,
            type: .call,
            payload: ["action": action]
        )
    }

    /// Create a typing event.
    public static func typing(
        sessionId: String,
        typingTapCount: Int? = nil,
        typingSpeed: Double? = nil,
        meanInterTapIntervalMs: Double? = nil,
        typingCadenceVariability: Double? = nil,
        typingCadenceStability: Double? = nil,
        typingGapCount: Int? = nil,
        typingGapRatio: Double? = nil,
        typingBurstiness: Double? = nil,
        typingActivityRatio: Double? = nil,
        typingInteractionIntensity: Double? = nil,
        durationSeconds: Double? = nil,
        deepTyping: Bool = false
    ) -> BehaviorEvent {
        var metrics: [String: Any] = [
            "deep_typing": deepTyping
        ]
        if let typingTapCount = typingTapCount { metrics["typing_tap_count"] = typingTapCount }
        if let typingSpeed = typingSpeed { metrics["typing_speed"] = typingSpeed }
        if let meanInterTapIntervalMs = meanInterTapIntervalMs { metrics["mean_inter_tap_interval_ms"] = meanInterTapIntervalMs }
        if let typingCadenceVariability = typingCadenceVariability { metrics["typing_cadence_variability"] = typingCadenceVariability }
        if let typingCadenceStability = typingCadenceStability { metrics["typing_cadence_stability"] = typingCadenceStability }
        if let typingGapCount = typingGapCount { metrics["typing_gap_count"] = typingGapCount }
        if let typingGapRatio = typingGapRatio { metrics["typing_gap_ratio"] = typingGapRatio }
        if let typingBurstiness = typingBurstiness { metrics["typing_burstiness"] = typingBurstiness }
        if let typingActivityRatio = typingActivityRatio { metrics["typing_activity_ratio"] = typingActivityRatio }
        if let typingInteractionIntensity = typingInteractionIntensity { metrics["typing_interaction_intensity"] = typingInteractionIntensity }
        if let durationSeconds = durationSeconds { metrics["duration_seconds"] = durationSeconds }

        return BehaviorEvent(
            sessionId: sessionId,
            type: .typing,
            payload: metrics
        )
    }

    /// Create a clipboard event (copy/paste/cut). Privacy-first: only action type, not content.
    public static func clipboard(
        sessionId: String,
        action: String,
        context: String? = nil
    ) -> BehaviorEvent {
        var metrics: [String: Any] = ["action": action]
        if let context = context { metrics["context"] = context }

        return BehaviorEvent(
            sessionId: sessionId,
            type: .clipboard,
            payload: metrics
        )
    }

    /// Create an app switch event.
    public static func appSwitch(
        sessionId: String,
        action: String? = nil,
        metrics: [String: Any] = [:]
    ) -> BehaviorEvent {
        var payload: [String: Any] = metrics
        if let action = action {
            payload["action"] = action
        }
        return BehaviorEvent(
            sessionId: sessionId,
            type: .appSwitch,
            payload: payload
        )
    }

    // MARK: - Serialization

    /// Convert event to dictionary format for serialization.
    /// Uses the canonical wire format matching Dart/Kotlin implementations.
    public func toDictionary() -> [String: Any] {
        return [
            "event": [
                "event_id": eventId,
                "session_id": sessionId,
                "timestamp": timestamp,
                "event_type": type.rawValue,
                "metrics": payload
            ]
        ]
    }
}
