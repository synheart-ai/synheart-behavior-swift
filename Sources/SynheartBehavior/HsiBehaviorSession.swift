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
    var scrollEventCount = 0
    var scrollEventsWithReversal = 0
    var scrollEventsWithoutReversal = 0

    for event in events {
        // Map event type - skip events that Flux doesn't support
        let eventType = mapEventType(event.type)
        // Flux only accepts: scroll, tap, swipe, notification, call, typing, app_switch
        // Skip "unknown" and "idle" (idle is calculated by Flux internally from event gaps)
        if eventType == "unknown" || eventType == "idle" {
            continue
        }
        
        let timestamp = formatter.string(from: Date(timeIntervalSince1970: Double(event.timestamp) / 1000.0))

        var fluxEvent: [String: Any] = [
            "timestamp": timestamp,
            "event_type": eventType
        ]

        // Map event-specific data
        switch event.type {
        case .scrollVelocity, .scrollAcceleration, .scrollJitter, .scrollStop:
            scrollEventCount += 1
            // Scroll direction must be "up" or "down" (Flux doesn't accept "unknown")
            let scrollDirection = event.payload["direction"] as? String ?? "down"
            let validDirection = (scrollDirection == "up" || scrollDirection == "down") ? scrollDirection : "down"
            var scroll: [String: Any] = [
                "velocity": event.payload["velocity"] ?? 0.0,
                "direction": validDirection
            ]
            // Include direction_reversal if available (Flux accepts this field)
            // IMPORTANT: Always include direction_reversal, even if false, so Flux can calculate scroll jitter correctly
            let directionReversal = event.payload["direction_reversal"] as? Bool ?? false
            scroll["direction_reversal"] = directionReversal
            
            if directionReversal {
                scrollEventsWithReversal += 1
            } else {
                scrollEventsWithoutReversal += 1
            }
            
            fluxEvent["scroll"] = scroll

        case .tapRate, .longPressRate:
            fluxEvent["tap"] = [
                "tap_duration_ms": event.payload["duration_ms"] ?? event.payload["tap_duration_ms"] ?? 0,
                "long_press": event.type == .longPressRate || (event.payload["long_press"] as? Bool ?? false)
            ]

        case .dragVelocity:
            // Swipe direction must be "left" or "right" (Flux doesn't accept "unknown")
            let swipeDirection = event.payload["direction"] as? String ?? "right"
            let validDirection = (swipeDirection == "left" || swipeDirection == "right") ? swipeDirection : "right"
            fluxEvent["swipe"] = [
                "velocity": event.payload["velocity"] ?? 0.0,
                "direction": validDirection
            ]

        case .appSwitch:
            fluxEvent["app_switch"] = [
                "from_app_id": event.payload["from_app_id"] ?? event.payload["from_app"] ?? "",
                "to_app_id": event.payload["to_app_id"] ?? event.payload["to_app"] ?? ""
            ]

        case .typingCadence, .typingBurst:
            var typing: [String: Any] = [:]
            
            // Convert typing speed from taps/second to characters per minute (CPM)
            // typing_speed is in taps/second, multiply by 60 to get CPM
            if let typingSpeed = event.payload["typing_speed"] as? Double {
                typing["typing_speed_cpm"] = typingSpeed * 60.0
            } else if let typingSpeedCpm = event.payload["typing_speed_cpm"] {
                typing["typing_speed_cpm"] = typingSpeedCpm
            } else if let cadence = event.payload["cadence"] {
                typing["typing_speed_cpm"] = cadence
            } else {
                typing["typing_speed_cpm"] = 0.0
            }
            
            // Include cadence stability
            if let cadenceStability = event.payload["typing_cadence_stability"] {
                typing["cadence_stability"] = cadenceStability
            } else if let stability = event.payload["stability"] {
                typing["cadence_stability"] = stability
            } else {
                typing["cadence_stability"] = 0.0
            }
            
            // Include duration_sec if available
            if let duration = event.payload["duration"] {
                typing["duration_sec"] = duration
            } else if let durationSec = event.payload["duration_sec"] {
                typing["duration_sec"] = durationSec
            }
            
            // Include pause_count if available (mapped from typing_gap_count)
            if let pauseCount = event.payload["pause_count"] ?? event.payload["typing_gap_count"] {
                typing["pause_count"] = pauseCount
            }
            
            // Include detailed typing metrics that Flux uses for aggregation
            if let typingTapCount = event.payload["typing_tap_count"] {
                typing["typing_tap_count"] = typingTapCount
            }
            if let meanInterTapInterval = event.payload["mean_inter_tap_interval_ms"] {
                typing["mean_inter_tap_interval_ms"] = meanInterTapInterval
            }
            if let typingBurstiness = event.payload["typing_burstiness"] {
                typing["typing_burstiness"] = typingBurstiness
            }
            
            // Include session boundaries if available
            if let startAt = event.payload["start_at"] {
                typing["start_at"] = startAt
            }
            if let endAt = event.payload["end_at"] {
                typing["end_at"] = endAt
            }
            
            // Correction and clipboard counts for Flux (clipboard_activity_rate, correction_rate)
            typing["number_of_backspace"] = event.payload["backspace_count"] ?? event.payload["number_of_backspace"] ?? 0
            typing["number_of_delete"] = event.payload["number_of_delete"] ?? 0
            typing["number_of_copy"] = event.payload["number_of_copy"] ?? 0
            typing["number_of_paste"] = event.payload["number_of_paste"] ?? 0
            typing["number_of_cut"] = event.payload["number_of_cut"] ?? 0
            
            fluxEvent["typing"] = typing

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

/// Parse HSI 1.0 JSON response into HsiBehaviorPayload (manual parsing).
///
/// Flux returns HSI 1.0 format with axes.behavior.readings structure.
/// This function manually parses it and converts to HsiBehaviorPayload.
///
/// - Parameters:
///   - hsiJson: JSON string from synheart-flux
///   - sessionId: Session ID (if not in HSI JSON)
///   - startTime: Session start time (if not in HSI JSON)
///   - endTime: Session end time (if not in HSI JSON)
/// - Returns: Parsed HSI payload, or nil if parsing fails
public func parseHsiJsonManually(_ hsiJson: String, sessionId: String? = nil, startTime: Date? = nil, endTime: Date? = nil) -> HsiBehaviorPayload? {
    guard let data = hsiJson.data(using: .utf8),
          let hsi = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    
    // HSI 1.0 format: axes.behavior.readings array
    guard let axes = hsi["axes"] as? [String: Any],
          let behavior = axes["behavior"] as? [String: Any],
          let readings = behavior["readings"] as? [[String: Any]] else {
        return nil
    }
    
    // Extract metrics from axis readings
    var metricsMap: [String: Double] = [:]
    for reading in readings {
        if let axis = reading["axis"] as? String,
           let score = reading["score"] as? Double {
            metricsMap[axis] = score
        }
    }
    
    // Extract meta information
    let meta = hsi["meta"] as? [String: Any]
    
    // Extract producer info
    let producerJson = hsi["producer"] as? [String: Any]
    let producer = HsiProducer(
        name: producerJson?["name"] as? String ?? "synheart-flux",
        version: producerJson?["version"] as? String ?? "0.3.0",
        instanceId: producerJson?["instance_id"] as? String ?? ""
    )
    
    // Extract provenance info (may be missing in some Flux versions)
    let provenanceJson = hsi["provenance"] as? [String: Any]
    let provenance = HsiProvenance(
        sourceDeviceId: provenanceJson?["source_device_id"] as? String ?? "",
        observedAtUtc: provenanceJson?["observed_at_utc"] as? String ?? "",
        computedAtUtc: provenanceJson?["computed_at_utc"] as? String ?? ""
    )
    
    // Extract quality info
    let qualityJson = hsi["quality"] as? [String: Any]
    let flagsArray = qualityJson?["flags"] as? [String] ?? []
    let quality = HsiQuality(
        coverage: qualityJson?["coverage"] as? Double ?? 0.0,
        confidence: qualityJson?["confidence"] as? Double ?? 0.0,
        flags: flagsArray
    )
    
    // Build behavior metrics from readings
    let behaviorMetrics = HsiBehavioralMetrics(
        distractionScore: metricsMap["distraction"] ?? 0.0,
        focusHint: metricsMap["focus"] ?? 0.0,
        taskSwitchRate: metricsMap["task_switch_rate"] ?? 0.0,
        notificationLoad: metricsMap["notification_load"] ?? 0.0,
        burstiness: metricsMap["burstiness"] ?? 0.0,
        scrollJitterRate: metricsMap["scroll_jitter_rate"] ?? 0.0,
        interactionIntensity: metricsMap["interaction_intensity"] ?? 0.0,
        deepFocusBlocks: meta?["deep_focus_blocks"] as? Int ?? 0,
        idleRatio: metricsMap["idle_ratio"] ?? 0.0,
        fragmentedIdleRatio: metricsMap["fragmented_idle_ratio"] ?? 0.0
    )
    
    // Build baseline (if available)
    let baseline: HsiBehaviorBaseline?
    if let baselineDistraction = meta?["baseline_distraction"] as? Double,
       let baselineFocus = meta?["baseline_focus"] as? Double {
        baseline = HsiBehaviorBaseline(
            distraction: baselineDistraction,
            focus: baselineFocus,
            distractionDeviationPct: meta?["distraction_deviation_pct"] as? Double,
            sessionsInBaseline: meta?["sessions_in_baseline"] as? Int ?? 0
        )
    } else {
        baseline = nil
    }
    
    // Build event summary from meta
    let eventSummary = HsiEventSummary(
        totalEvents: meta?["total_events"] as? Int ?? 0,
        scrollEvents: meta?["scroll_events"] as? Int ?? 0,
        tapEvents: meta?["tap_events"] as? Int ?? 0,
        appSwitches: meta?["app_switches"] as? Int ?? 0,
        notifications: meta?["notifications"] as? Int ?? 0
    )
    
    // Get session info from parameters, meta, or use defaults
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    let sessionIdValue = sessionId ?? meta?["session_id"] as? String ?? ""
    let startTimeUtc: String
    let endTimeUtc: String
    let durationSec: Double
    
    if let startTime = startTime, let endTime = endTime {
        startTimeUtc = formatter.string(from: startTime)
        endTimeUtc = formatter.string(from: endTime)
        durationSec = endTime.timeIntervalSince(startTime)
    } else if let startTimeStr = meta?["start_time_utc"] as? String,
              let endTimeStr = meta?["end_time_utc"] as? String {
        startTimeUtc = startTimeStr
        endTimeUtc = endTimeStr
        durationSec = meta?["duration_sec"] as? Double ?? 0.0
    } else {
        // Use current time as fallback
        let now = Date()
        startTimeUtc = formatter.string(from: now)
        endTimeUtc = formatter.string(from: now)
        durationSec = 0.0
    }
    
    let window = HsiBehaviorWindow(
        sessionId: sessionIdValue,
        startTimeUtc: startTimeUtc,
        endTimeUtc: endTimeUtc,
        durationSec: durationSec,
        behavior: behaviorMetrics,
        baseline: baseline,
        eventSummary: eventSummary
    )
    
    return HsiBehaviorPayload(
        hsiVersion: hsi["hsi_version"] as? String ?? "1.0.0",
        producer: producer,
        provenance: provenance,
        quality: quality,
        behaviorWindows: [window]
    )
}

/// Parse HSI JSON response into HsiBehaviorPayload (legacy Codable method).
///
/// - Parameter hsiJson: JSON string from synheart-flux
/// - Returns: Parsed HSI payload, or nil if parsing fails
public func parseHsiJson(_ hsiJson: String) -> HsiBehaviorPayload? {
    // Try manual parsing first (HSI 1.0 format)
    if let result = parseHsiJsonManually(hsiJson) {
        return result
    }
    
    // Fallback to Codable parsing (for older HSI formats)
    guard let data = hsiJson.data(using: .utf8) else {
        return nil
    }

    do {
        let decoder = JSONDecoder()
        return try decoder.decode(HsiBehaviorPayload.self, from: data)
    } catch {
        return nil
    }
}

/// Extract typing session summary from HSI JSON meta section.
/// Flux puts typing summary fields directly in top-level meta (clipboard_activity_rate,
/// correction_rate, typing_session_count, typing_metrics, etc.), not under a nested key.
///
/// - Parameter hsiJson: Raw HSI JSON string
/// - Returns: Typing session summary dictionary, or nil if meta missing
private func extractTypingSessionSummary(from hsiJson: String) -> [String: Any]? {
    guard let data = hsiJson.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let meta = json["meta"] as? [String: Any] else {
        return nil
    }
    var typingSummary: [String: Any] = [:]
    typingSummary["typing_session_count"] = meta["typing_session_count"] as? Int ?? 0
    typingSummary["average_keystrokes_per_session"] = meta["average_keystrokes_per_session"] as? Double ?? 0.0
    typingSummary["average_typing_session_duration"] = meta["average_typing_session_duration"] as? Double ?? 0.0
    typingSummary["average_typing_speed"] = meta["average_typing_speed"] as? Double ?? 0.0
    typingSummary["average_typing_gap"] = meta["average_typing_gap"] as? Double ?? 0.0
    typingSummary["average_inter_tap_interval"] = meta["average_inter_tap_interval"] as? Double ?? 0.0
    typingSummary["typing_cadence_stability"] = meta["typing_cadence_stability"] as? Double ?? 0.0
    typingSummary["burstiness_of_typing"] = meta["burstiness_of_typing"] as? Double ?? 0.0
    if let totalInt = meta["total_typing_duration"] as? Int {
        typingSummary["total_typing_duration"] = Double(totalInt)
    } else {
        typingSummary["total_typing_duration"] = meta["total_typing_duration"] as? Double ?? 0.0
    }
    typingSummary["active_typing_ratio"] = meta["active_typing_ratio"] as? Double ?? 0.0
    typingSummary["typing_contribution_to_interaction_intensity"] = meta["typing_contribution_to_interaction_intensity"] as? Double ?? 0.0
    typingSummary["deep_typing_blocks"] = meta["deep_typing_blocks"] as? Int ?? 0
    typingSummary["typing_fragmentation"] = meta["typing_fragmentation"] as? Double ?? 0.0
    typingSummary["clipboard_activity_rate"] = meta["clipboard_activity_rate"] as? Double ?? 0.0
    typingSummary["correction_rate"] = meta["correction_rate"] as? Double ?? 0.0
    if let typingMetrics = meta["typing_metrics"] as? [[String: Any]] {
        typingSummary["typing_metrics"] = typingMetrics
    }
    return typingSummary
}

/// Extract behavioral metrics dictionary from HSI payload.
///
/// This returns metrics in a format compatible with the existing SDK output.
///
/// - Parameters:
///   - hsi: Parsed HSI payload
///   - hsiJson: Optional raw HSI JSON string for extracting typing_session_summary from meta
/// - Returns: Dictionary of behavioral metrics
public func extractMetricsDictionary(from hsi: HsiBehaviorPayload, hsiJson: String? = nil) -> [String: Any]? {
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
    
    // Extract typing_session_summary from meta section if raw JSON is provided
    if let hsiJson = hsiJson, let typingSummary = extractTypingSessionSummary(from: hsiJson) {
        metrics["typing_session_summary"] = typingSummary
    }

    return metrics
}
