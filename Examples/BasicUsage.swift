import SynheartBehavior

// Initialize
let config = BehaviorConfig(
    enableInputSignals: true,
    enableAttentionSignals: true,
    consentBehavior: true
)
let behavior = SynheartBehavior(config: config)
try behavior.initialize()

// Start a session
let sessionId = try behavior.startSession()

// Send events using factory methods
behavior.sendEvent(.scroll(sessionId: sessionId, velocity: 120.5, direction: "down"))
behavior.sendEvent(.tap(sessionId: sessionId, tapDurationMs: 85))
behavior.sendEvent(.typing(sessionId: sessionId, typingTapCount: 45, typingSpeed: 3.2, typingBurstiness: 0.6))
behavior.sendEvent(.notification(sessionId: sessionId, action: "ignored"))
behavior.sendEvent(.appSwitch(sessionId: sessionId, action: "manual"))

// Get real-time stats
let stats = try behavior.getCurrentStats()
print("Stability: \(stats.stabilityIndex)")
print("Fragmentation: \(stats.fragmentationIndex)")

// End session
let summary = try behavior.endSession(sessionId: sessionId)
print("Session duration: \(summary.duration)ms")
print("Event count: \(summary.eventCount)")
if let metrics = summary.behavioralMetrics {
    print("Interaction intensity: \(metrics["interactionIntensity"] ?? "n/a")")
    print("Focus hint: \(metrics["behavioralFocusHint"] ?? "n/a")")
}

// Cleanup
behavior.dispose()
