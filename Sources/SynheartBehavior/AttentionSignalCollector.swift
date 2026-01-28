import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects attention and multitasking signals including app switching, idle gaps, and session stability.
internal class AttentionSignalCollector {
    private weak var sdk: SynheartBehavior?
    private var sessionManager: SessionManager?

    // App lifecycle tracking
    private var foregroundStartTime: Int64 = 0
    private var backgroundStartTime: Int64 = 0
    private var appSwitchTimes: [Int64] = []
    private let appSwitchWindowMs: Int64 = 60000  // 1 minute window
    private var isInForeground = true  // Track foreground state to avoid double-counting

    // Idle gap tracking
    private var lastActivityTime: Int64 = 0
    private var idleStartTime: Int64 = 0
    private var isIdle = false
    private var maxIdleGapSeconds: Double

    // Stability tracking
    private var sessionStartTime: Int64 = 0
    private var totalForegroundDuration: Int64 = 0
    private var fragmentationCount = 0

    init(sdk: SynheartBehavior, sessionManager: SessionManager, maxIdleGapSeconds: Double) {
        self.sdk = sdk
        self.sessionManager = sessionManager
        self.maxIdleGapSeconds = maxIdleGapSeconds
    }

    /// Start collecting attention signals.
    func start() {
        let notificationCenter = NotificationCenter.default

        // App lifecycle notifications
        notificationCenter.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Activity tracking - monitor any user interaction
        notificationCenter.addObserver(
            self,
            selector: #selector(userDidInteract),
            name: UITextField.textDidChangeNotification,
            object: nil
        )

        // Start tracking
        // Set foreground start time - if app is already active, use current time
        // This ensures app switches are counted correctly
        foregroundStartTime = currentTimestampMs()
        sessionStartTime = foregroundStartTime
        lastActivityTime = foregroundStartTime
        isInForeground = true  // App starts in foreground
        updateActivityTime()
    }

    /// Stop collecting attention signals.
    func stop() {
        NotificationCenter.default.removeObserver(self)
        appSwitchTimes.removeAll()
    }

    @objc private func appDidBecomeActive() {
        onAppForegrounded()
    }
    
    @objc private func appWillEnterForeground() {
        onAppForegrounded()
    }
    
    private func onAppForegrounded() {
        let currentTime = currentTimestampMs()

        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            return
        }
        
        // Only process if we were actually in background
        guard !isInForeground else {
            return
        }
        
        isInForeground = true
        foregroundStartTime = currentTime

        // Emit app switch event if we had a background period (not on initial launch)
        if backgroundStartTime > 0 {
            let backgroundDuration = currentTime - backgroundStartTime
            fragmentationCount += 1

            emitAppSwitchEvent(
                sessionId: sessionId,
                backgroundDuration: backgroundDuration,
                switchCount: appSwitchTimes.count
            )
        }

        backgroundStartTime = 0  // Reset background start time
        updateActivityTime()
    }

    @objc private func appWillResignActive() {
        // Also handle backgrounding here (matching Dart SDK - both willResignActive and didEnterBackground call onAppBackgrounded)
        // This ensures app switches are counted even if didEnterBackground doesn't fire
        onAppBackgrounded()
    }
    
    private func onAppBackgrounded() {
        let currentTime = currentTimestampMs()
        
        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            return
        }
        
        // Only process if we were actually in foreground (avoid double-counting)
        guard isInForeground else {
            return
        }
        
        isInForeground = false
        backgroundStartTime = currentTime
        
        // Calculate and emit foreground duration
        if foregroundStartTime > 0 {
            let foregroundDuration = currentTime - foregroundStartTime
            totalForegroundDuration += foregroundDuration
            
            emitForegroundDurationEvent(
                sessionId: sessionId,
                duration: foregroundDuration
            )
            
            sessionManager?.recordForegroundDuration(Double(foregroundDuration) / 1000.0)
        }
        
        // Count app switch when going to background (matching Dart SDK behavior)
        // Only count if we were actually in foreground (not on initial launch)
        // This ensures app switch is counted even if session ends while in background
        if foregroundStartTime > 0 {
            appSwitchTimes.append(currentTime)
            appSwitchTimes.removeAll { currentTime - $0 > appSwitchWindowMs }
            sessionManager?.recordAppSwitch()
        }
    }

    @objc private func appDidEnterBackground() {
        // Also handle backgrounding here (matching Dart SDK - both willResignActive and didEnterBackground call onAppBackgrounded)
        // The onAppBackgrounded method will check isInForeground to avoid double-counting
        onAppBackgrounded()
    }


    @objc private func userDidInteract() {
        updateActivityTime()
    }

    /// Manually mark user activity (call this from other collectors).
    func markActivity() {
        updateActivityTime()
    }

    private func updateActivityTime() {
        let currentTime = currentTimestampMs()
        let timeSinceLastActivity = currentTime - lastActivityTime

        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            lastActivityTime = currentTime
            return
        }

        // Check for idle gap
        if timeSinceLastActivity > Int64(maxIdleGapSeconds * 1000) {
            if !isIdle {
                idleStartTime = lastActivityTime
                isIdle = true
            }

            let idleGapSeconds = Double(timeSinceLastActivity) / 1000.0
            emitIdleGapEvent(sessionId: sessionId, idleGapSeconds: idleGapSeconds)

            sessionManager?.recordIdleGap(idleGapSeconds)
        } else {
            if isIdle {
                isIdle = false
            }
        }

        lastActivityTime = currentTime
    }

    private func emitAppSwitchEvent(sessionId: String, backgroundDuration: Int64, switchCount: Int) {
        let event = BehaviorEvent(
            sessionId: sessionId,
            timestamp: currentTimestampMs(),
            type: .appSwitch,
            payload: [
                "background_duration_ms": backgroundDuration,
                "switch_count": switchCount,
                "switches_per_minute": Double(switchCount) / (Double(appSwitchWindowMs) / 60000.0)
            ]
        )
        sdk?.emitEvent(event)
    }

    private func emitForegroundDurationEvent(sessionId: String, duration: Int64) {
        let event = BehaviorEvent(
            sessionId: sessionId,
            timestamp: currentTimestampMs(),
            type: .foregroundDuration,
            payload: [
                "duration_ms": duration,
                "duration_seconds": Double(duration) / 1000.0
            ]
        )
        sdk?.emitEvent(event)
    }

    private func emitIdleGapEvent(sessionId: String, idleGapSeconds: Double) {
        // Classify idle gap type
        var eventType: BehaviorEventType = .idleGap

        if idleGapSeconds < 3 {
            eventType = .microIdle
        } else if idleGapSeconds < 10 {
            eventType = .midIdle
        } else {
            eventType = .taskDropIdle
        }

        let event = BehaviorEvent(
            sessionId: sessionId,
            timestamp: currentTimestampMs(),
            type: eventType,
            payload: [
                "idle_gap_seconds": idleGapSeconds
            ]
        )
        sdk?.emitEvent(event)
    }

    /// Calculate and emit session stability metrics.
    func emitSessionStability(sessionId: String) {
        let currentTime = currentTimestampMs()
        let totalSessionTime = currentTime - sessionStartTime

        guard totalSessionTime > 0 else { return }

        // Stability index: ratio of foreground time to total time
        let stabilityIndex = Double(totalForegroundDuration) / Double(totalSessionTime)

        // Fragmentation index: normalized fragmentation count
        let fragmentationIndex = min(1.0, Double(fragmentationCount) / 10.0)

        let event = BehaviorEvent(
            sessionId: sessionId,
            timestamp: currentTime,
            type: .sessionStability,
            payload: [
                "stability_index": stabilityIndex,
                "fragmentation_index": fragmentationIndex,
                "total_foreground_duration_ms": totalForegroundDuration,
                "fragmentation_count": fragmentationCount
            ]
        )
        sdk?.emitEvent(event)

        sessionManager?.recordStability(stabilityIndex: stabilityIndex, fragmentationIndex: fragmentationIndex)
    }

    /// Get current attention statistics.
    func getCurrentStats() -> (
        appSwitchesPerMinute: Int,
        foregroundDuration: Double?,
        idleGapSeconds: Double?
    ) {
        let appSwitchesPerMinute = appSwitchTimes.count

        let foregroundDuration = foregroundStartTime > 0
            ? Double(currentTimestampMs() - foregroundStartTime) / 1000.0
            : nil

        let idleGapSeconds = lastActivityTime > 0
            ? Double(currentTimestampMs() - lastActivityTime) / 1000.0
            : nil

        return (appSwitchesPerMinute, foregroundDuration, idleGapSeconds)
    }

    /// Reset session tracking for a new session.
    func resetSessionTracking() {
        sessionStartTime = currentTimestampMs()
        totalForegroundDuration = 0
        fragmentationCount = 0
    }

    private func currentTimestampMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}
