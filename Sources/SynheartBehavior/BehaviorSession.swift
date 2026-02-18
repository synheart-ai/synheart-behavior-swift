import Foundation

/// Summary statistics for a completed behavioral session.
public struct BehaviorSessionSummary {
    /// Unique session ID.
    public let sessionId: String

    /// Start timestamp in milliseconds since epoch.
    public let startTimestamp: Int64

    /// End timestamp in milliseconds since epoch.
    public let endTimestamp: Int64

    /// Total session duration in milliseconds.
    public let duration: Int64

    /// Total number of events captured during this session.
    public let eventCount: Int

    /// Average typing cadence (keys per second) during session.
    public let averageTypingCadence: Double?

    /// Average scroll velocity during session.
    public let averageScrollVelocity: Double?

    /// Number of app switches during session.
    public let appSwitchCount: Int

    /// Session stability index (0.0 to 1.0).
    public let stabilityIndex: Double?

    /// Fragmentation index (0.0 to 1.0).
    public let fragmentationIndex: Double?

    /// Behavioral metrics dictionary containing:
    /// interactionIntensity, taskSwitchRate, taskSwitchCost, idleRatio,
    /// fragmentedIdleRatio, burstiness, notificationLoad, scrollJitterRate,
    /// behavioralDistractionScore, behavioralFocusHint
    public let behavioralMetrics: [String: Any]?

    /// Typing metrics dictionary containing:
    /// typingCadence, meanInterTapIntervalMs, typingCadenceVariability,
    /// typingBurstiness, typingActivityRatio
    public let typingMetrics: [String: Any]?

    /// Array of deep focus block dictionaries, each containing:
    /// startAt, endAt, durationMs
    public let deepFocusBlocks: [[String: Any]]?

    public init(
        sessionId: String,
        startTimestamp: Int64,
        endTimestamp: Int64,
        duration: Int64,
        eventCount: Int = 0,
        averageTypingCadence: Double? = nil,
        averageScrollVelocity: Double? = nil,
        appSwitchCount: Int = 0,
        stabilityIndex: Double? = nil,
        fragmentationIndex: Double? = nil,
        behavioralMetrics: [String: Any]? = nil,
        typingMetrics: [String: Any]? = nil,
        deepFocusBlocks: [[String: Any]]? = nil
    ) {
        self.sessionId = sessionId
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.duration = duration
        self.eventCount = eventCount
        self.averageTypingCadence = averageTypingCadence
        self.averageScrollVelocity = averageScrollVelocity
        self.appSwitchCount = appSwitchCount
        self.stabilityIndex = stabilityIndex
        self.fragmentationIndex = fragmentationIndex
        self.behavioralMetrics = behavioralMetrics
        self.typingMetrics = typingMetrics
        self.deepFocusBlocks = deepFocusBlocks
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "session_id": sessionId,
            "start_timestamp": startTimestamp,
            "end_timestamp": endTimestamp,
            "duration": duration,
            "event_count": eventCount,
            "average_typing_cadence": averageTypingCadence as Any,
            "average_scroll_velocity": averageScrollVelocity as Any,
            "app_switch_count": appSwitchCount,
            "stability_index": stabilityIndex as Any,
            "fragmentation_index": fragmentationIndex as Any,
        ]
        if let behavioralMetrics = behavioralMetrics {
            dict["behavioral_metrics"] = behavioralMetrics
        }
        if let typingMetrics = typingMetrics {
            dict["typing_metrics"] = typingMetrics
        }
        if let deepFocusBlocks = deepFocusBlocks {
            dict["deep_focus_blocks"] = deepFocusBlocks
        }
        return dict
    }
}
