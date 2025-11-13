import Foundation

/// Main entry point for the Synheart Behavioral SDK.
///
/// This SDK collects digital behavioral signals from smartphones without
/// collecting any text, content, or PII - only timing-based signals.
public class SynheartBehavior {
    private var config: BehaviorConfig
    private var isInitialized = false

    // Core managers
    private var sessionManager: SessionManager?
    private var eventBatcher: EventBatcher?

    // Signal collectors
    private var inputCollector: InputSignalCollector?
    private var scrollCollector: ScrollSignalCollector?
    private var gestureCollector: GestureSignalCollector?
    private var attentionCollector: AttentionSignalCollector?

    public init(config: BehaviorConfig = BehaviorConfig()) {
        self.config = config
    }

    /// Initialize the SDK and start collecting behavioral signals.
    public func initialize() throws {
        guard !isInitialized else {
            return  // Already initialized
        }

        // Initialize core managers
        sessionManager = SessionManager()
        eventBatcher = EventBatcher(batchSize: config.eventBatchSize)

        // Initialize signal collectors based on configuration
        if config.enableInputSignals {
            guard let sessionMgr = sessionManager else {
                throw BehaviorError.invalidConfiguration
            }
            inputCollector = InputSignalCollector(sdk: self, sessionManager: sessionMgr)
            scrollCollector = ScrollSignalCollector(sdk: self, sessionManager: sessionMgr)
            gestureCollector = GestureSignalCollector(sdk: self, sessionManager: sessionMgr)

            inputCollector?.start()
            scrollCollector?.start()
            gestureCollector?.start()
        }

        if config.enableAttentionSignals {
            guard let sessionMgr = sessionManager else {
                throw BehaviorError.invalidConfiguration
            }
            attentionCollector = AttentionSignalCollector(
                sdk: self,
                sessionManager: sessionMgr,
                maxIdleGapSeconds: config.maxIdleGapSeconds
            )
            attentionCollector?.start()
        }

        if config.enableMotionLite {
            // Motion-lite is not yet implemented
            // Future implementation would go here
        }

        isInitialized = true
    }

    /// Set event handler callback for receiving behavioral events.
    public func setEventHandler(_ handler: @escaping (BehaviorEvent) -> Void) {
        eventBatcher?.setEventHandler(handler)
    }

    /// Set batch event handler for receiving batches of events.
    public func setBatchEventHandler(_ handler: @escaping ([BehaviorEvent]) -> Void) {
        eventBatcher?.setBatchHandler(handler)
    }

    /// Start a new behavioral tracking session.
    public func startSession(sessionId: String? = nil) throws -> String {
        guard isInitialized else {
            throw BehaviorError.notInitialized
        }

        let sessionIdToUse = sessionId ?? generateSessionId()
        sessionManager?.startSession(sessionId: sessionIdToUse)
        attentionCollector?.resetSessionTracking()

        return sessionIdToUse
    }

    /// End a session and return summary.
    public func endSession(sessionId: String) throws -> BehaviorSessionSummary {
        guard isInitialized else {
            throw BehaviorError.notInitialized
        }

        // Emit final session stability metrics
        attentionCollector?.emitSessionStability(sessionId: sessionId)

        // Flush any pending events
        eventBatcher?.flush()

        // Get session summary from manager
        guard let summary = sessionManager?.endSession(sessionId: sessionId) else {
            throw BehaviorError.sessionNotFound
        }

        return summary
    }

    /// Get current rolling statistics snapshot.
    public func getCurrentStats() throws -> BehaviorStats {
        guard isInitialized else {
            throw BehaviorError.notInitialized
        }

        guard let sessionManager = sessionManager else {
            throw BehaviorError.invalidConfiguration
        }

        // Get base stats from session manager
        var stats = sessionManager.getCurrentStats()

        // Enhance with real-time collector data
        if let inputStats = inputCollector?.getCurrentStats() {
            if let scrollStats = scrollCollector?.getCurrentStats() {
                sessionManager.updateScrollMetrics(
                    acceleration: scrollStats.acceleration,
                    jitter: scrollStats.jitter
                )
            }
            if let burstLength = inputStats.burstLength {
                sessionManager.updateBurstLength(burstLength)
            }

            // Refresh stats with updated values
            stats = sessionManager.getCurrentStats()
        }

        return stats
    }

    /// Update configuration at runtime.
    public func updateConfig(_ config: BehaviorConfig) throws {
        guard isInitialized else {
            throw BehaviorError.notInitialized
        }

        let wasInputEnabled = self.config.enableInputSignals
        let wasAttentionEnabled = self.config.enableAttentionSignals

        self.config = config

        // Update event batch size
        eventBatcher?.updateBatchSize(config.eventBatchSize)

        // Handle enabling/disabling collectors
        if config.enableInputSignals && !wasInputEnabled {
            // Enable input collectors
            guard let sessionMgr = sessionManager else {
                throw BehaviorError.invalidConfiguration
            }
            inputCollector = InputSignalCollector(sdk: self, sessionManager: sessionMgr)
            scrollCollector = ScrollSignalCollector(sdk: self, sessionManager: sessionMgr)
            gestureCollector = GestureSignalCollector(sdk: self, sessionManager: sessionMgr)

            inputCollector?.start()
            scrollCollector?.start()
            gestureCollector?.start()
        } else if !config.enableInputSignals && wasInputEnabled {
            // Disable input collectors
            inputCollector?.stop()
            scrollCollector?.stop()
            gestureCollector?.stop()
            inputCollector = nil
            scrollCollector = nil
            gestureCollector = nil
        }

        if config.enableAttentionSignals && !wasAttentionEnabled {
            // Enable attention collector
            guard let sessionMgr = sessionManager else {
                throw BehaviorError.invalidConfiguration
            }
            attentionCollector = AttentionSignalCollector(
                sdk: self,
                sessionManager: sessionMgr,
                maxIdleGapSeconds: config.maxIdleGapSeconds
            )
            attentionCollector?.start()
        } else if !config.enableAttentionSignals && wasAttentionEnabled {
            // Disable attention collector
            attentionCollector?.stop()
            attentionCollector = nil
        }
    }

    /// Dispose of the SDK instance and clean up resources.
    public func dispose() {
        // Stop all collectors
        inputCollector?.stop()
        scrollCollector?.stop()
        gestureCollector?.stop()
        attentionCollector?.stop()

        // Clear event batcher
        eventBatcher?.clear()

        // Clean up references
        inputCollector = nil
        scrollCollector = nil
        gestureCollector = nil
        attentionCollector = nil
        sessionManager = nil
        eventBatcher = nil

        isInitialized = false
    }

    private func generateSessionId() -> String {
        let prefix = config.sessionIdPrefix ?? "SESS"
        return "\(prefix)-\(Int64(Date().timeIntervalSince1970 * 1000))"
    }

    /// Emit an event to registered handlers.
    internal func emitEvent(_ event: BehaviorEvent) {
        eventBatcher?.addEvent(event)
        sessionManager?.incrementEventCount()
    }
}

/// Errors that can be thrown by the SDK.
public enum BehaviorError: Error {
    case notInitialized
    case invalidConfiguration
    case sessionNotFound
}

