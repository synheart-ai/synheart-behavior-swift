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
    
    public init(
        enableInputSignals: Bool = true,
        enableAttentionSignals: Bool = true,
        enableMotionLite: Bool = false,
        sessionIdPrefix: String? = nil,
        eventBatchSize: Int = 10,
        maxIdleGapSeconds: Double = 10.0
    ) {
        self.enableInputSignals = enableInputSignals
        self.enableAttentionSignals = enableAttentionSignals
        self.enableMotionLite = enableMotionLite
        self.sessionIdPrefix = sessionIdPrefix
        self.eventBatchSize = eventBatchSize
        self.maxIdleGapSeconds = maxIdleGapSeconds
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "enableInputSignals": enableInputSignals,
            "enableAttentionSignals": enableAttentionSignals,
            "enableMotionLite": enableMotionLite,
            "sessionIdPrefix": sessionIdPrefix as Any,
            "eventBatchSize": eventBatchSize,
            "maxIdleGapSeconds": maxIdleGapSeconds,
        ]
    }
}

