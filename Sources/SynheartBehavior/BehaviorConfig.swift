import Foundation

/// Configuration for initializing the Synheart Behavioral SDK.
public struct BehaviorConfig {
    /// Enable input interaction signals (keystroke timing, scroll dynamics, gestures).
    public let enableInputSignals: Bool

    /// Enable attention and multitasking signals (app switching, idle gaps, session stability).
    public let enableAttentionSignals: Bool

    /// Enable motion-lite signals (device orientation, shake patterns, micro-movement).
    /// Note: This is optional and may have higher battery impact.
    public let enableMotionLite: Bool

    /// Custom session ID prefix. If nil, auto-generated.
    public let sessionIdPrefix: String?

    /// Event batch size for streaming. Default: 10 events per batch.
    public let eventBatchSize: Int

    /// Maximum idle gap duration in seconds before considering task dropped.
    /// Default: 10 seconds.
    public let maxIdleGapSeconds: Double

    /// Optional user identifier.
    public let userId: String?

    /// Optional device identifier.
    public let deviceId: String?

    /// SDK version.
    public let behaviorVersion: String

    /// Whether behavior tracking consent is granted.
    public let consentBehavior: Bool

    public init(
        enableInputSignals: Bool = true,
        enableAttentionSignals: Bool = true,
        enableMotionLite: Bool = false,
        sessionIdPrefix: String? = nil,
        eventBatchSize: Int = 10,
        maxIdleGapSeconds: Double = 10.0,
        userId: String? = nil,
        deviceId: String? = nil,
        behaviorVersion: String = "1.0.0",
        consentBehavior: Bool = true
    ) {
        self.enableInputSignals = enableInputSignals
        self.enableAttentionSignals = enableAttentionSignals
        self.enableMotionLite = enableMotionLite
        self.sessionIdPrefix = sessionIdPrefix
        self.eventBatchSize = eventBatchSize
        self.maxIdleGapSeconds = maxIdleGapSeconds
        self.userId = userId
        self.deviceId = deviceId
        self.behaviorVersion = behaviorVersion
        self.consentBehavior = consentBehavior
    }

    func toDictionary() -> [String: Any] {
        return [
            "enableInputSignals": enableInputSignals,
            "enableAttentionSignals": enableAttentionSignals,
            "enableMotionLite": enableMotionLite,
            "sessionIdPrefix": sessionIdPrefix as Any,
            "eventBatchSize": eventBatchSize,
            "maxIdleGapSeconds": maxIdleGapSeconds,
            "userId": userId as Any,
            "deviceId": deviceId as Any,
            "behaviorVersion": behaviorVersion,
            "consentBehavior": consentBehavior,
        ]
    }
}
