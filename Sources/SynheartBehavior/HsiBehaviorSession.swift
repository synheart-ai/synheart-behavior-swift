import Foundation

// MARK: - HSI Behavioral Metrics

/// HSI-compliant behavioral metrics computed by synheart-flux.
public struct HsiBehavioralMetrics: Codable {
    /// Composite distraction score (0.0 to 1.0)
    public let distractionScore: Double

    /// Focus hint (inverse of distraction, 0.0 to 1.0)
    public let focusHint: Double

    /// Task switch rate (0.0 to 1.0, exponential saturation)
    public let taskSwitchRate: Double

    /// Notification load (0.0 to 1.0, exponential saturation)
    public let notificationLoad: Double

    /// Burstiness index (Barabási formula, 0.0 to 1.0)
    public let burstiness: Double

    /// Scroll jitter rate (direction reversals / scroll events)
    public let scrollJitterRate: Double

    /// Interaction intensity (events per second)
    public let interactionIntensity: Double

    /// Number of deep focus blocks (engagement >= 120s)
    public let deepFocusBlocks: Int

    /// Idle ratio (time in idle / session duration)
    public let idleRatio: Double

    /// Fragmented idle ratio (idle segments / duration)
    public let fragmentedIdleRatio: Double

    enum CodingKeys: String, CodingKey {
        case distractionScore = "distraction_score"
        case focusHint = "focus_hint"
        case taskSwitchRate = "task_switch_rate"
        case notificationLoad = "notification_load"
        case burstiness
        case scrollJitterRate = "scroll_jitter_rate"
        case interactionIntensity = "interaction_intensity"
        case deepFocusBlocks = "deep_focus_blocks"
        case idleRatio = "idle_ratio"
        case fragmentedIdleRatio = "fragmented_idle_ratio"
    }
}

/// Baseline data for behavioral metrics.
public struct HsiBehaviorBaseline: Codable {
    /// Baseline distraction score
    public let distraction: Double?

    /// Baseline focus score
    public let focus: Double?

    /// Deviation from baseline (percentage)
    public let distractionDeviationPct: Double?

    /// Number of sessions in baseline
    public let sessionsInBaseline: Int

    enum CodingKeys: String, CodingKey {
        case distraction
        case focus
        case distractionDeviationPct = "distraction_deviation_pct"
        case sessionsInBaseline = "sessions_in_baseline"
    }
}

/// Event summary for a behavioral session.
public struct HsiEventSummary: Codable {
    public let totalEvents: Int
    public let scrollEvents: Int
    public let tapEvents: Int
    public let appSwitches: Int
    public let notifications: Int

    enum CodingKeys: String, CodingKey {
        case totalEvents = "total_events"
        case scrollEvents = "scroll_events"
        case tapEvents = "tap_events"
        case appSwitches = "app_switches"
        case notifications
    }
}

/// A behavioral window in HSI format.
public struct HsiBehaviorWindow: Codable {
    public let sessionId: String
    public let startTimeUtc: String
    public let endTimeUtc: String
    public let durationSec: Double
    public let behavior: HsiBehavioralMetrics
    public let baseline: HsiBehaviorBaseline?
    public let eventSummary: HsiEventSummary

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case startTimeUtc = "start_time_utc"
        case endTimeUtc = "end_time_utc"
        case durationSec = "duration_sec"
        case behavior
        case baseline
        case eventSummary = "event_summary"
    }
}

/// HSI producer metadata.
public struct HsiProducer: Codable {
    public let name: String
    public let version: String
    public let instanceId: String

    enum CodingKeys: String, CodingKey {
        case name
        case version
        case instanceId = "instance_id"
    }
}

/// HSI provenance metadata.
public struct HsiProvenance: Codable {
    public let sourceDeviceId: String
    public let observedAtUtc: String
    public let computedAtUtc: String

    enum CodingKeys: String, CodingKey {
        case sourceDeviceId = "source_device_id"
        case observedAtUtc = "observed_at_utc"
        case computedAtUtc = "computed_at_utc"
    }
}

/// HSI quality metadata.
public struct HsiQuality: Codable {
    public let coverage: Double
    public let confidence: Double
    public let flags: [String]
}

/// Complete HSI behavioral payload.
public struct HsiBehaviorPayload: Codable {
    public let hsiVersion: String
    public let producer: HsiProducer
    public let provenance: HsiProvenance
    public let quality: HsiQuality
    public let behaviorWindows: [HsiBehaviorWindow]

    enum CodingKeys: String, CodingKey {
        case hsiVersion = "hsi_version"
        case producer
        case provenance
        case quality
        case behaviorWindows = "behavior_windows"
    }
}

// MARK: - Conversion Helpers

/// Convert behavioral events to synheart-flux JSON format.
///
/// - Parameters:
///   - sessionId: Session identifier
///   - deviceId: Device identifier
///   - timezone: Timezone string (e.g., "America/New_York")
///   - startTime: Session start time
///   - endTime: Session end time
///   - events: Array of behavioral events
/// - Returns: JSON string in synheart-flux format
public func convertToFluxSessionJson(
    sessionId: String,
    deviceId: String,
    timezone: String,
    startTime: Date,
    endTime: Date,
    events: [BehaviorEvent]
) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var fluxEvents: [[String: Any]] = []

    for event in events {
        let timestamp = formatter.string(from: Date(timeIntervalSince1970: Double(event.timestamp) / 1000.0))

        var fluxEvent: [String: Any] = [
            "timestamp": timestamp,
            "event_type": mapEventType(event.type)
        ]

        // Map event-specific data
        switch event.type {
        case .scrollVelocity, .scrollAcceleration, .scrollJitter, .scrollStop:
            fluxEvent["scroll"] = [
                "velocity": event.payload["velocity"] ?? 0.0,
                "direction": event.payload["direction"] ?? "down"
            ]

        case .tapRate, .longPressRate:
            fluxEvent["tap"] = [
                "tap_duration_ms": event.payload["duration_ms"] ?? 0,
                "long_press": event.type == .longPressRate
            ]

        case .dragVelocity:
            fluxEvent["swipe"] = [
                "velocity": event.payload["velocity"] ?? 0.0,
                "direction": event.payload["direction"] ?? "unknown"
            ]

        case .appSwitch:
            fluxEvent["app_switch"] = [
                "from_app_id": event.payload["from_app"] ?? "",
                "to_app_id": event.payload["to_app"] ?? ""
            ]

        case .typingCadence, .typingBurst:
            fluxEvent["typing"] = [
                "typing_speed_cpm": event.payload["cadence"] ?? 0.0,
                "cadence_stability": event.payload["stability"] ?? 0.0
            ]

        default:
            // Other event types don't need special mapping
            break
        }

        fluxEvents.append(fluxEvent)
    }

    let session: [String: Any] = [
        "session_id": sessionId,
        "device_id": deviceId,
        "timezone": timezone,
        "start_time": formatter.string(from: startTime),
        "end_time": formatter.string(from: endTime),
        "events": fluxEvents
    ]

    do {
        let jsonData = try JSONSerialization.data(withJSONObject: session)
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    } catch {
        print("FluxBridge: Failed to serialize session: \(error)")
        return "{}"
    }
}

/// Map BehaviorEventType to synheart-flux event type string.
private func mapEventType(_ type: BehaviorEventType) -> String {
    switch type {
    case .scrollVelocity, .scrollAcceleration, .scrollJitter, .scrollStop:
        return "scroll"
    case .tapRate:
        return "tap"
    case .longPressRate:
        return "tap"
    case .dragVelocity:
        return "swipe"
    case .appSwitch:
        return "app_switch"
    case .typingCadence, .typingBurst:
        return "typing"
    case .foregroundDuration:
        return "app_switch"
    case .idleGap, .microIdle, .midIdle, .taskDropIdle:
        return "idle"
    default:
        return "unknown"
    }
}

/// Parse HSI JSON response into HsiBehaviorPayload.
///
/// - Parameter hsiJson: JSON string from synheart-flux
/// - Returns: Parsed HSI payload, or nil if parsing fails
public func parseHsiJson(_ hsiJson: String) -> HsiBehaviorPayload? {
    guard let data = hsiJson.data(using: .utf8) else {
        return nil
    }

    do {
        let decoder = JSONDecoder()
        return try decoder.decode(HsiBehaviorPayload.self, from: data)
    } catch {
        print("FluxBridge: Failed to parse HSI JSON: \(error)")
        return nil
    }
}

/// Extract behavioral metrics dictionary from HSI payload.
///
/// This returns metrics in a format compatible with the existing SDK output.
///
/// - Parameter hsi: Parsed HSI payload
/// - Returns: Dictionary of behavioral metrics
public func extractMetricsDictionary(from hsi: HsiBehaviorPayload) -> [String: Any]? {
    guard let window = hsi.behaviorWindows.first else {
        return nil
    }

    var metrics: [String: Any] = [
        "distraction_score": window.behavior.distractionScore,
        "focus_hint": window.behavior.focusHint,
        "task_switch_rate": window.behavior.taskSwitchRate,
        "notification_load": window.behavior.notificationLoad,
        "burstiness": window.behavior.burstiness,
        "scroll_jitter_rate": window.behavior.scrollJitterRate,
        "interaction_intensity": window.behavior.interactionIntensity,
        "deep_focus_blocks": window.behavior.deepFocusBlocks,
        "idle_ratio": window.behavior.idleRatio,
        "fragmented_idle_ratio": window.behavior.fragmentedIdleRatio,
        "total_events": window.eventSummary.totalEvents,
        "scroll_events": window.eventSummary.scrollEvents,
        "tap_events": window.eventSummary.tapEvents,
        "app_switches": window.eventSummary.appSwitches,
        "notifications": window.eventSummary.notifications
    ]

    if let baseline = window.baseline {
        if let distraction = baseline.distraction {
            metrics["baseline_distraction"] = distraction
        }
        if let focus = baseline.focus {
            metrics["baseline_focus"] = focus
        }
        if let deviation = baseline.distractionDeviationPct {
            metrics["distraction_deviation_pct"] = deviation
        }
        metrics["sessions_in_baseline"] = baseline.sessionsInBaseline
    }

    return metrics
}
