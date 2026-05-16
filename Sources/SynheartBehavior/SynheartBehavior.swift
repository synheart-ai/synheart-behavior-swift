import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

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

    // Event fan-out: user-set callback + any active AsyncStream consumers.
    private var userEventHandler: ((BehaviorEvent) -> Void)?
    private var userBatchHandler: (([BehaviorEvent]) -> Void)?
    private var streamContinuations: [UUID: AsyncStream<BehaviorEvent>.Continuation] = [:]
    private let streamLock = NSLock()

    public init(config: BehaviorConfig = BehaviorConfig()) {
        self.config = config
    }

    /// Initialize the SDK and start collecting behavioral signals.
    public func initialize() throws {
        guard !isInitialized else {
            return  // Already initialized
        }

        // Enable battery monitoring early so state is available when needed
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        #endif

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

        // Wire the batcher's fan-in callbacks to our fan-out layer, so
        // both `setEventHandler` and `events` consumers are served.
        eventBatcher?.setEventHandler { [weak self] event in
            self?.fanOutEvent(event)
        }
        eventBatcher?.setBatchHandler { [weak self] events in
            self?.userBatchHandler?(events)
        }

        isInitialized = true
    }

    /// Set event handler callback for receiving behavioral events.
    /// Coexists with the `events` AsyncStream — both are notified.
    public func setEventHandler(_ handler: @escaping (BehaviorEvent) -> Void) {
        userEventHandler = handler
    }

    /// Set batch event handler for receiving batches of events.
    public func setBatchEventHandler(_ handler: @escaping ([BehaviorEvent]) -> Void) {
        userBatchHandler = handler
    }

    /// AsyncStream of behavioral events. Mirrors the Kotlin `onEvent: Flow`
    /// and Flutter `onEvent: Stream`. Each access returns a fresh stream;
    /// the stream terminates when the SDK is disposed or the consumer
    /// cancels iteration.
    public var events: AsyncStream<BehaviorEvent> {
        AsyncStream { continuation in
            let id = UUID()
            streamLock.lock()
            streamContinuations[id] = continuation
            streamLock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.streamLock.lock()
                self.streamContinuations.removeValue(forKey: id)
                self.streamLock.unlock()
            }
        }
    }

    private func fanOutEvent(_ event: BehaviorEvent) {
        userEventHandler?(event)
        streamLock.lock()
        let conts = Array(streamContinuations.values)
        streamLock.unlock()
        for c in conts { c.yield(event) }
    }

    /// Start a new behavioral tracking session. Mirrors the Kotlin/Flutter
    /// SDKs: returns a `BehaviorSession` whose `.end()` method finalizes the
    /// session and returns a `BehaviorSessionSummary`.
    @discardableResult
    public func startSession(sessionId: String? = nil) throws -> BehaviorSession {
        guard isInitialized else {
            throw BehaviorError.notInitialized
        }

        let sessionIdToUse = sessionId ?? generateSessionId()
        sessionManager?.startSession(sessionId: sessionIdToUse)
        attentionCollector?.resetSessionTracking()

        return BehaviorSession(
            sessionId: sessionIdToUse,
            startTimestamp: Int64(Date().timeIntervalSince1970 * 1000),
            sdk: self
        )
    }

    /// End a session and return summary.
    public func endSession(sessionId: String) throws -> BehaviorSessionSummary {
        guard isInitialized else {
            throw BehaviorError.notInitialized
        }

        // End any active typing session before ending the behavior session
        inputCollector?.endActiveTypingSession()

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

    /// Get the current active session ID, if any.
    public func getCurrentSessionId() -> String? {
        guard isInitialized else {
            return nil
        }
        return sessionManager?.getCurrentSessionId()
    }
    
    /// Get all events for the current session.
    public func getSessionEvents() -> [BehaviorEvent] {
        guard isInitialized else {
            return []
        }
        return sessionManager?.getSessionEvents() ?? []
    }
    
    /// Get the current app switch count for the active session.
    public func getAppSwitchCount() -> Int {
        guard isInitialized else {
            return 0
        }
        return sessionManager?.getAppSwitchCount() ?? 0
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
    // MARK: - Permissions

    /// Check if notification permission is granted.
    /// Mirrors the Flutter / Kotlin SDKs. On iOS this queries
    /// `UNUserNotificationCenter.getNotificationSettings`.
    public func checkNotificationPermission() async -> Bool {
        #if canImport(UserNotifications)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status = settings.authorizationStatus
        if status == .authorized || status == .provisional { return true }
        #if os(iOS)
        if #available(iOS 14.0, *) {
            if status == .ephemeral { return true }
        }
        #endif
        return false
        #else
        return false
        #endif
    }

    /// Request notification permission. Returns the granted state.
    /// On iOS this calls `UNUserNotificationCenter.requestAuthorization`.
    @discardableResult
    public func requestNotificationPermission() async -> Bool {
        #if canImport(UserNotifications)
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    /// Check if call permission is granted. iOS doesn't require explicit
    /// runtime permission for call monitoring (handled at framework level),
    /// so this returns `true` for parity with Flutter/Kotlin.
    public func checkCallPermission() async -> Bool {
        return true
    }

    /// Request call permission. No-op on iOS; returns `true`.
    @discardableResult
    public func requestCallPermission() async -> Bool {
        return true
    }

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

        // Terminate any active AsyncStream consumers.
        streamLock.lock()
        for c in streamContinuations.values { c.finish() }
        streamContinuations.removeAll()
        streamLock.unlock()
        userEventHandler = nil
        userBatchHandler = nil

        isInitialized = false
    }

    private func generateSessionId() -> String {
        let prefix = config.sessionIdPrefix ?? "SESS"
        return "\(prefix)-\(Int64(Date().timeIntervalSince1970 * 1000))"
    }

    /// Send an event using factory methods (public API).
    public func sendEvent(_ event: BehaviorEvent) {
        emitEvent(event)
    }

    /// Emit an event to registered handlers.
    internal func emitEvent(_ event: BehaviorEvent) {
        eventBatcher?.addEvent(event)
        sessionManager?.incrementEventCount()
        // Record event so it's reachable via getSessionEvents()
        sessionManager?.recordEvent(event)
    }
}

/// Errors that can be thrown by the SDK.
public enum BehaviorError: Error, Equatable {
    case notInitialized
    case invalidConfiguration
    case sessionNotFound
}

