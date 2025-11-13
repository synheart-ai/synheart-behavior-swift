import Foundation

/// Types of behavioral events that can be emitted by the SDK.
public enum BehaviorEventType: String {
    /// Keystroke timing events
    case typingCadence
    case typingBurst
    
    /// Scroll dynamics events
    case scrollVelocity
    case scrollAcceleration
    case scrollJitter
    case scrollStop
    
    /// Gesture activity events
    case tapRate
    case longPressRate
    case dragVelocity
    
    /// App switching events
    case appSwitch
    case foregroundDuration
    
    /// Idle gap events
    case idleGap
    case microIdle
    case midIdle
    case taskDropIdle
    
    /// Session stability events
    case sessionStability
    case fragmentationIndex
    
    /// Motion-lite events (optional)
    case orientationShift
    case shakePattern
    case microMovement
}

/// A single behavioral event emitted by the SDK.
public struct BehaviorEvent {
    /// Unique session ID for this event.
    public let sessionId: String
    
    /// Timestamp in milliseconds since epoch.
    public let timestamp: Int64
    
    /// Type of behavioral event.
    public let type: BehaviorEventType
    
    /// Event payload containing signal-specific data.
    public let payload: [String: Any]
    
    public init(
        sessionId: String,
        timestamp: Int64,
        type: BehaviorEventType,
        payload: [String: Any]
    ) {
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.type = type
        self.payload = payload
    }
    
    /// Convert event to dictionary format for serialization.
    public func toDictionary() -> [String: Any] {
        return [
            "session_id": sessionId,
            "timestamp": timestamp,
            "type": type.rawValue,
            "payload": payload,
        ]
    }
}

