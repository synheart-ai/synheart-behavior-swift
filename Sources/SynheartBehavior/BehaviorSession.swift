import Foundation

// MARK: - BehaviorSession

/// Represents an active behavioral tracking session. Sibling of the Kotlin /
/// Flutter `BehaviorSession` — returned from `SynheartBehavior.startSession()`.
public final class BehaviorSession {
    /// Unique session ID.
    public let sessionId: String

    /// Start timestamp in milliseconds since epoch.
    public let startTimestamp: Int64

    private weak var sdk: SynheartBehavior?

    init(sessionId: String, startTimestamp: Int64, sdk: SynheartBehavior) {
        self.sessionId = sessionId
        self.startTimestamp = startTimestamp
        self.sdk = sdk
    }

    /// End this session and generate a summary. Mirrors Kotlin `session.end()`.
    @discardableResult
    public func end() throws -> BehaviorSessionSummary {
        guard let sdk = sdk else { throw BehaviorError.notInitialized }
        return try sdk.endSession(sessionId: sessionId)
    }

    /// Current duration of this session in milliseconds.
    public func getCurrentDuration() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000) - startTimestamp
    }
}

// MARK: - Nested summary types (mirror Kotlin/Flutter SDK)

/// Motion state information. Mirrors Kotlin/Flutter `MotionState`.
public struct MotionState {
    public let state: [String]
    public let majorState: String
    public let majorStatePct: Double
    public let mlModel: String
    public let confidence: Double

    public init(
        state: [String] = [],
        majorState: String = "unknown",
        majorStatePct: Double = 0.0,
        mlModel: String = "motion_state_svc_classifier_v0.1",
        confidence: Double = 0.0
    ) {
        self.state = state
        self.majorState = majorState
        self.majorStatePct = majorStatePct
        self.mlModel = mlModel
        self.confidence = confidence
    }
}

/// Device context information.
public struct DeviceContext {
    public let avgScreenBrightness: Double
    public let startOrientation: String
    public let orientationChanges: Int

    public init(
        avgScreenBrightness: Double = 0.0,
        startOrientation: String = "portrait",
        orientationChanges: Int = 0
    ) {
        self.avgScreenBrightness = avgScreenBrightness
        self.startOrientation = startOrientation
        self.orientationChanges = orientationChanges
    }
}

/// Activity summary for the session.
public struct ActivitySummary {
    public let totalEvents: Int
    public let appSwitchCount: Int

    public init(totalEvents: Int = 0, appSwitchCount: Int = 0) {
        self.totalEvents = totalEvents
        self.appSwitchCount = appSwitchCount
    }
}

/// Deep focus block period.
public struct DeepFocusBlock {
    public let startAt: String
    public let endAt: String
    public let durationMs: Int

    public init(startAt: String, endAt: String, durationMs: Int) {
        self.startAt = startAt
        self.endAt = endAt
        self.durationMs = durationMs
    }
}

/// Behavioral metrics for the session.
public struct BehavioralMetricsStruct {
    public let interactionIntensity: Double
    public let taskSwitchRate: Double
    public let taskSwitchCost: Int
    public let idleTimeRatio: Double
    public let activeTimeRatio: Double
    public let notificationLoad: Double
    public let burstiness: Double
    public let behavioralDistractionScore: Double
    public let focusHint: Double
    public let fragmentedIdleRatio: Double
    public let scrollJitterRate: Double
    public let deepFocusBlocks: [DeepFocusBlock]

    public init(
        interactionIntensity: Double = 0.0,
        taskSwitchRate: Double = 0.0,
        taskSwitchCost: Int = 0,
        idleTimeRatio: Double = 0.0,
        activeTimeRatio: Double = 0.0,
        notificationLoad: Double = 0.0,
        burstiness: Double = 0.0,
        behavioralDistractionScore: Double = 0.0,
        focusHint: Double = 0.0,
        fragmentedIdleRatio: Double = 0.0,
        scrollJitterRate: Double = 0.0,
        deepFocusBlocks: [DeepFocusBlock] = []
    ) {
        self.interactionIntensity = interactionIntensity
        self.taskSwitchRate = taskSwitchRate
        self.taskSwitchCost = taskSwitchCost
        self.idleTimeRatio = idleTimeRatio
        self.activeTimeRatio = activeTimeRatio
        self.notificationLoad = notificationLoad
        self.burstiness = burstiness
        self.behavioralDistractionScore = behavioralDistractionScore
        self.focusHint = focusHint
        self.fragmentedIdleRatio = fragmentedIdleRatio
        self.scrollJitterRate = scrollJitterRate
        self.deepFocusBlocks = deepFocusBlocks
    }
}

/// Notification summary for the session.
public struct NotificationSummary {
    public let notificationCount: Int
    public let notificationIgnored: Int
    public let notificationIgnoreRate: Double
    public let notificationClusteringIndex: Double
    public let callCount: Int
    public let callIgnored: Int

    public init(
        notificationCount: Int = 0,
        notificationIgnored: Int = 0,
        notificationIgnoreRate: Double = 0.0,
        notificationClusteringIndex: Double = 0.0,
        callCount: Int = 0,
        callIgnored: Int = 0
    ) {
        self.notificationCount = notificationCount
        self.notificationIgnored = notificationIgnored
        self.notificationIgnoreRate = notificationIgnoreRate
        self.notificationClusteringIndex = notificationClusteringIndex
        self.callCount = callCount
        self.callIgnored = callIgnored
    }
}

/// System state information.
public struct SystemState {
    public let internetState: Bool
    public let doNotDisturb: Bool
    public let charging: Bool

    public init(
        internetState: Bool = false,
        doNotDisturb: Bool = false,
        charging: Bool = false
    ) {
        self.internetState = internetState
        self.doNotDisturb = doNotDisturb
        self.charging = charging
    }
}

/// Typing metrics for a single typing session (keyboard open to close).
public struct TypingMetrics {
    public let startAt: String
    public let endAt: String
    public let duration: Int
    public let deepTyping: Bool
    public let typingTapCount: Int
    public let typingSpeed: Double
    public let meanInterTapIntervalMs: Double
    public let typingCadenceVariability: Double
    public let typingCadenceStability: Double
    public let typingGapCount: Int
    public let typingGapRatio: Double
    public let typingBurstiness: Double
    public let typingActivityRatio: Double
    public let typingInteractionIntensity: Double

    public init(
        startAt: String = "",
        endAt: String = "",
        duration: Int = 0,
        deepTyping: Bool = false,
        typingTapCount: Int = 0,
        typingSpeed: Double = 0.0,
        meanInterTapIntervalMs: Double = 0.0,
        typingCadenceVariability: Double = 0.0,
        typingCadenceStability: Double = 0.0,
        typingGapCount: Int = 0,
        typingGapRatio: Double = 0.0,
        typingBurstiness: Double = 0.0,
        typingActivityRatio: Double = 0.0,
        typingInteractionIntensity: Double = 0.0
    ) {
        self.startAt = startAt
        self.endAt = endAt
        self.duration = duration
        self.deepTyping = deepTyping
        self.typingTapCount = typingTapCount
        self.typingSpeed = typingSpeed
        self.meanInterTapIntervalMs = meanInterTapIntervalMs
        self.typingCadenceVariability = typingCadenceVariability
        self.typingCadenceStability = typingCadenceStability
        self.typingGapCount = typingGapCount
        self.typingGapRatio = typingGapRatio
        self.typingBurstiness = typingBurstiness
        self.typingActivityRatio = typingActivityRatio
        self.typingInteractionIntensity = typingInteractionIntensity
    }
}

/// Typing session summary. Mirrors Kotlin/Flutter `TypingSessionSummary`.
public struct TypingSessionSummary {
    public let typingSessionCount: Int
    public let averageKeystrokesPerSession: Double
    public let averageTypingSessionDuration: Double
    public let averageTypingSpeed: Double
    public let averageTypingGap: Double
    public let averageInterTapInterval: Double
    public let typingCadenceStability: Double
    public let burstinessOfTyping: Double
    public let totalTypingDuration: Int
    public let activeTypingRatio: Double
    public let typingContributionToInteractionIntensity: Double
    public let deepTypingBlocks: Int
    public let typingFragmentation: Double
    public let clipboardActivityRate: Double
    public let correctionRate: Double
    public let individualTypingSessions: [TypingMetrics]

    public init(
        typingSessionCount: Int = 0,
        averageKeystrokesPerSession: Double = 0.0,
        averageTypingSessionDuration: Double = 0.0,
        averageTypingSpeed: Double = 0.0,
        averageTypingGap: Double = 0.0,
        averageInterTapInterval: Double = 0.0,
        typingCadenceStability: Double = 0.0,
        burstinessOfTyping: Double = 0.0,
        totalTypingDuration: Int = 0,
        activeTypingRatio: Double = 0.0,
        typingContributionToInteractionIntensity: Double = 0.0,
        deepTypingBlocks: Int = 0,
        typingFragmentation: Double = 0.0,
        clipboardActivityRate: Double = 0.0,
        correctionRate: Double = 0.0,
        individualTypingSessions: [TypingMetrics] = []
    ) {
        self.typingSessionCount = typingSessionCount
        self.averageKeystrokesPerSession = averageKeystrokesPerSession
        self.averageTypingSessionDuration = averageTypingSessionDuration
        self.averageTypingSpeed = averageTypingSpeed
        self.averageTypingGap = averageTypingGap
        self.averageInterTapInterval = averageInterTapInterval
        self.typingCadenceStability = typingCadenceStability
        self.burstinessOfTyping = burstinessOfTyping
        self.totalTypingDuration = totalTypingDuration
        self.activeTypingRatio = activeTypingRatio
        self.typingContributionToInteractionIntensity = typingContributionToInteractionIntensity
        self.deepTypingBlocks = deepTypingBlocks
        self.typingFragmentation = typingFragmentation
        self.clipboardActivityRate = clipboardActivityRate
        self.correctionRate = correctionRate
        self.individualTypingSessions = individualTypingSessions
    }
}

// MARK: - BehaviorSessionSummary

/// Summary statistics for a completed behavioral session.
///
/// Mirrors the Kotlin/Flutter SDKs' `BehaviorSessionSummary`. Fields populated by the iOS
/// runtime today are: `sessionId`, `startTimestamp`, `endTimestamp`, `duration`, `eventCount`,
/// `averageTypingCadence`, `averageScrollVelocity`, `appSwitchCount`, `stabilityIndex`,
/// `fragmentationIndex`, plus `activitySummary` derived from those. The richer nested
/// structures (`motionState`, `notificationSummary`, `systemState`, `deviceContext`,
/// `typingSessionSummary`, full `behavioralMetricsStruct`) are exposed for API parity with the
/// other SDKs; on iOS they are populated with sensible defaults until the matching iOS
/// collectors land.
public struct BehaviorSessionSummary {
    public let sessionId: String
    public let startTimestamp: Int64
    public let endTimestamp: Int64
    public let duration: Int64
    public let eventCount: Int
    public let averageTypingCadence: Double?
    public let averageScrollVelocity: Double?
    public let appSwitchCount: Int
    public let stabilityIndex: Double?
    public let fragmentationIndex: Double?

    /// Raw behavioral metrics dictionary (legacy shape, kept for backwards compatibility).
    public let behavioralMetrics: [String: Any]?

    /// Raw typing metrics dictionary (legacy shape, kept for backwards compatibility).
    public let typingMetrics: [String: Any]?

    /// Raw deep focus block dictionaries (legacy shape, kept for backwards compatibility).
    public let deepFocusBlocks: [[String: Any]]?

    // ── Parity fields (Kotlin/Flutter siblings) ──────────────────────────────

    /// ISO 8601 start timestamp (sibling of Kotlin `startAt`).
    public var startAt: String { iso8601(startTimestamp) }

    /// ISO 8601 end timestamp (sibling of Kotlin `endAt`).
    public var endAt: String { iso8601(endTimestamp) }

    /// Duration in milliseconds (sibling of Kotlin `durationMs`).
    public var durationMs: Int { Int(duration) }

    /// Whether this is a micro session (< 30 seconds).
    public var microSession: Bool { duration < 30_000 }

    /// OS version string, e.g. "iOS 17.0".
    public let os: String

    /// Bundle identifier of the host app.
    public let appId: String?

    /// Display name of the host app.
    public let appName: String?

    /// Session spacing in milliseconds (time since the last app use). Defaults to 0 on iOS.
    public let sessionSpacing: Int

    public let motionState: MotionState?
    public let deviceContext: DeviceContext
    public let activitySummary: ActivitySummary
    public let behavioralMetricsStruct: BehavioralMetricsStruct?
    public let notificationSummary: NotificationSummary
    public let systemState: SystemState
    public let typingSessionSummary: TypingSessionSummary?

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
        deepFocusBlocks: [[String: Any]]? = nil,
        os: String? = nil,
        appId: String? = nil,
        appName: String? = nil,
        sessionSpacing: Int = 0,
        motionState: MotionState? = nil,
        deviceContext: DeviceContext? = nil,
        activitySummary: ActivitySummary? = nil,
        behavioralMetricsStruct: BehavioralMetricsStruct? = nil,
        notificationSummary: NotificationSummary? = nil,
        systemState: SystemState? = nil,
        typingSessionSummary: TypingSessionSummary? = nil
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
        self.os = os ?? Self.defaultOS()
        self.appId = appId ?? Bundle.main.bundleIdentifier
        self.appName = appName ?? Self.defaultAppName()
        self.sessionSpacing = sessionSpacing
        self.motionState = motionState
        self.deviceContext = deviceContext ?? DeviceContext()
        self.activitySummary = activitySummary ?? ActivitySummary(
            totalEvents: eventCount,
            appSwitchCount: appSwitchCount
        )
        self.behavioralMetricsStruct = behavioralMetricsStruct
            ?? Self.metricsStructFromDict(behavioralMetrics)
        self.notificationSummary = notificationSummary ?? NotificationSummary()
        self.systemState = systemState ?? SystemState()
        self.typingSessionSummary = typingSessionSummary
            ?? Self.typingSummaryFromDict(typingMetrics)
    }

    private static func defaultOS() -> String {
        #if canImport(UIKit)
        return "iOS \(UIDevice.current.systemVersion)"
        #else
        return "macOS"
        #endif
    }

    private static func defaultAppName() -> String? {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
    }

    private static func metricsStructFromDict(_ dict: [String: Any]?) -> BehavioralMetricsStruct? {
        guard let d = dict, !d.isEmpty else { return nil }
        func dbl(_ key: String) -> Double {
            (d[key] as? Double) ?? (d[key] as? NSNumber)?.doubleValue ?? 0.0
        }
        func int(_ key: String) -> Int {
            (d[key] as? Int) ?? (d[key] as? NSNumber)?.intValue ?? 0
        }
        return BehavioralMetricsStruct(
            interactionIntensity: dbl("interactionIntensity"),
            taskSwitchRate: dbl("taskSwitchRate"),
            taskSwitchCost: int("taskSwitchCost"),
            idleTimeRatio: dbl("idleRatio"),
            activeTimeRatio: dbl("activeTimeRatio"),
            notificationLoad: dbl("notificationLoad"),
            burstiness: dbl("burstiness"),
            behavioralDistractionScore: dbl("behavioralDistractionScore"),
            focusHint: dbl("behavioralFocusHint"),
            fragmentedIdleRatio: dbl("fragmentedIdleRatio"),
            scrollJitterRate: dbl("scrollJitterRate")
        )
    }

    private static func typingSummaryFromDict(_ dict: [String: Any]?) -> TypingSessionSummary? {
        guard let d = dict, !d.isEmpty else { return nil }
        func dbl(_ key: String) -> Double {
            (d[key] as? Double) ?? (d[key] as? NSNumber)?.doubleValue ?? 0.0
        }
        return TypingSessionSummary(
            averageTypingSpeed: dbl("typingCadence"),
            averageInterTapInterval: dbl("meanInterTapIntervalMs"),
            typingCadenceStability: dbl("typingCadenceVariability"),
            burstinessOfTyping: dbl("typingBurstiness"),
            activeTypingRatio: dbl("typingActivityRatio")
        )
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

#if canImport(UIKit)
import UIKit
#endif

private func iso8601(_ epochMs: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000.0)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}
