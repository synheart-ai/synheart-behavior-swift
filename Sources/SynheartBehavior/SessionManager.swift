import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SystemConfiguration)
import SystemConfiguration
#endif

#if canImport(UIKit)
private typealias SynheartDeviceOrientation = UIDeviceOrientation
#else
private enum SynheartDeviceOrientation {
    case unknown
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
    case faceUp
    case faceDown
}
#endif

/// Manages behavioral tracking sessions and aggregates statistics.
internal class SessionManager {
    private var currentSessionId: String?
    private var sessionStartTime: Int64 = 0
    private var eventCount = 0

    // Store events for HSI computation
    private var sessionEvents: [BehaviorEvent] = []

    // Aggregated statistics
    private var typingCadences: [Double] = []
    private var interKeyLatencies: [Double] = []
    private var scrollVelocities: [Double] = []
    private var tapRates: [Double] = []
    private var appSwitchCount = 0
    private var foregroundDurations: [Double] = []
    private var idleGaps: [Double] = []
    private var stabilityIndex: Double?
    private var fragmentationIndex: Double?

    // Real-time stats
    private var lastTypingCadence: Double?
    private var lastInterKeyLatency: Double?
    private var lastBurstLength: Int?
    private var lastScrollVelocity: Double?
    private var lastScrollAcceleration: Double?
    private var lastScrollJitter: Double?
    private var lastTapRate: Double?
    private var lastForegroundDuration: Double?
    private var lastIdleGapSeconds: Double?

    // Device context tracking
    private var startScreenBrightness: CGFloat = 0.5
    private var startOrientation: SynheartDeviceOrientation = .portrait
    private var lastOrientation: SynheartDeviceOrientation = .portrait
    private var orientationChangeCount: Int = 0

    // Session spacing tracking
    private var lastAppUseTime: Date?
    private var currentSessionSpacing: Int64 = 0

    // Flux processor for HSI computation (optional)
    private var fluxProcessor: FluxBehaviorProcessor?

    private let lock = NSLock()

    /// Start a new session.
    func startSession(sessionId: String) {
        lock.lock()
        defer { lock.unlock() }

        currentSessionId = sessionId
        
        // Capture device context at session start
        #if canImport(UIKit)
        // Note: UIScreen.main.brightness may not be available on simulators
        // It requires a physical device to get accurate brightness values
        startScreenBrightness = UIScreen.main.brightness
        startOrientation = UIDevice.current.orientation
        lastOrientation = startOrientation
        orientationChangeCount = 0
        
        // Register for orientation change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        #endif
        
        // Calculate session spacing (time between end of previous session and start of current session)
        let now = Date()
        if let lastUse = lastAppUseTime {
            let spacingMs = Int64((now.timeIntervalSince1970 - lastUse.timeIntervalSince1970) * 1000)
            currentSessionSpacing = spacingMs
        } else {
            currentSessionSpacing = 0
        }
        
        sessionStartTime = currentTimestampMs()
        eventCount = 0

        // Clear stored events
        sessionEvents.removeAll()

        // Reset aggregated statistics
        typingCadences.removeAll()
        interKeyLatencies.removeAll()
        scrollVelocities.removeAll()
        tapRates.removeAll()
        appSwitchCount = 0
        foregroundDurations.removeAll()
        idleGaps.removeAll()
        stabilityIndex = nil
        fragmentationIndex = nil

        // Reset real-time stats
        lastTypingCadence = nil
        lastInterKeyLatency = nil
        lastBurstLength = nil
        lastScrollVelocity = nil
        lastScrollAcceleration = nil
        lastScrollJitter = nil
        lastTapRate = nil
        lastForegroundDuration = nil
        lastIdleGapSeconds = nil

        // Initialize Flux processor if available
        if FluxBridge.shared.isAvailable && fluxProcessor == nil {
            do {
                fluxProcessor = try FluxBehaviorProcessor(baselineWindowSessions: 20)
            } catch {
                // Failed to create processor, will use stateless processing
            }
        }
    }

    /// Record an event for HSI computation.
    func recordEvent(_ event: BehaviorEvent) {
        lock.lock()
        defer { lock.unlock() }
        sessionEvents.append(event)
    }

    /// End the current session and return a summary.
    func endSession(sessionId: String) -> BehaviorSessionSummary? {
        lock.lock()
        defer { lock.unlock() }

        guard currentSessionId == sessionId else {
            return nil
        }

        let endTimestamp = currentTimestampMs()
        let duration = endTimestamp - sessionStartTime

        let summary = BehaviorSessionSummary(
            sessionId: sessionId,
            startTimestamp: sessionStartTime,
            endTimestamp: endTimestamp,
            duration: duration,
            eventCount: eventCount,
            averageTypingCadence: average(typingCadences),
            averageScrollVelocity: average(scrollVelocities),
            appSwitchCount: appSwitchCount,
            stabilityIndex: stabilityIndex,
            fragmentationIndex: fragmentationIndex
        )

        currentSessionId = nil
        return summary
    }

    /// End the current session and return HSI-compliant output using synheart-flux.
    ///
    /// Flux is required - throws if not available.
    /// Returns a tuple containing both the parsed payload and the raw JSON string.
    func endSessionWithHsi(sessionId: String) throws -> (payload: HsiBehaviorPayload, rawJson: String) {
        lock.lock()
        defer { lock.unlock() }

        guard currentSessionId == sessionId else {
            throw BehaviorError.sessionNotFound
        }

        guard FluxBridge.shared.isAvailable else {
            throw BehaviorError.fluxNotAvailable
        }

        let endTimestamp = currentTimestampMs()
        let startTime = Date(timeIntervalSince1970: Double(sessionStartTime) / 1000.0)
        let endTime = Date(timeIntervalSince1970: Double(endTimestamp) / 1000.0)

        // Get device ID
        #if canImport(UIKit)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios-device"
        #else
        let deviceId = "ios-device"
        #endif

        // Convert events to Flux JSON format
        let fluxJson = convertToFluxSessionJson(
            sessionId: sessionId,
            deviceId: deviceId,
            timezone: TimeZone.current.identifier,
            startTime: startTime,
            endTime: endTime,
            events: sessionEvents
        )

        // Compute HSI metrics using Rust
        var hsiPayload: HsiBehaviorPayload?
        var rawHsiJson: String?

        if let processor = fluxProcessor {
            // Use stateful processor with baselines
            do {
                let hsiJson = try processor.process(fluxJson)
                rawHsiJson = hsiJson  // Store raw JSON
                // Parse HSI 1.0 format manually (not using Codable)
                // Pass session info since it might not be in HSI JSON
                if let parsed = parseHsiJsonManually(hsiJson, sessionId: sessionId, startTime: startTime, endTime: endTime) {
                    hsiPayload = parsed
                }
            } catch {
                // Stateful processing failed, will fallback to stateless
            }
        }

        // Fallback to stateless if stateful failed
        if hsiPayload == nil {
            guard let hsiJson = FluxBridge.shared.behaviorToHsi(fluxJson) else {
                throw BehaviorError.fluxProcessingFailed
            }
            rawHsiJson = hsiJson  // Store raw JSON
            // Parse HSI 1.0 format manually (not using Codable)
            // Pass session info since it might not be in HSI JSON
            guard let parsed = parseHsiJsonManually(hsiJson, sessionId: sessionId, startTime: startTime, endTime: endTime) else {
                throw BehaviorError.fluxProcessingFailed
            }
            hsiPayload = parsed
        }

        // Update lastAppUseTime to session end time for next session's spacing calculation
        lastAppUseTime = endTime
        
        // Inject system state, device context, and session spacing into the raw HSI JSON meta section
        if var rawJson = rawHsiJson {
            rawJson = injectSystemStateIntoHsiJson(rawJson)
            rawJson = injectDeviceContextIntoHsiJson(rawJson)
            rawJson = injectSessionSpacingIntoHsiJson(rawJson)
            rawHsiJson = rawJson
        }
        
        // Clean up orientation notifications
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        #endif

        currentSessionId = nil
        
        guard let result = hsiPayload, let rawJson = rawHsiJson else {
            throw BehaviorError.fluxProcessingFailed
        }
        
        return (payload: result, rawJson: rawJson)
    }
    
    /// Inject system state data into HSI JSON meta section.
    private func injectSystemStateIntoHsiJson(_ hsiJson: String) -> String {
        guard let data = hsiJson.data(using: .utf8),
              var hsi = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return hsiJson
        }
        
        // Get or create meta section
        var meta = hsi["meta"] as? [String: Any] ?? [:]
        
        // Collect system state data
        let internetState = isInternetConnected()
        let charging = isCharging()
        let doNotDisturb = isDoNotDisturbEnabled()
        
        // Add system state to meta
        meta["internet_state"] = internetState
        meta["charging"] = charging
        meta["do_not_disturb"] = doNotDisturb
        
        // Update meta in HSI JSON
        hsi["meta"] = meta
        
        // Convert back to JSON string
        if let jsonData = try? JSONSerialization.data(withJSONObject: hsi, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return hsiJson
    }
    
    /// Check if device is connected to internet.
    private func isInternetConnected() -> Bool {
        #if canImport(UIKit) && canImport(SystemConfiguration)
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return isReachable && !needsConnection
        #else
        return false
        #endif
    }
    
    /// Check if device is charging.
    private func isCharging() -> Bool {
        #if canImport(UIKit)
        // Ensure battery monitoring is enabled (should be enabled during SDK init)
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        let state = UIDevice.current.batteryState
        
        // Handle unknown state - on simulator or if monitoring not ready
        if state == .unknown {
            #if targetEnvironment(simulator)
            // Simulator doesn't support battery state
            return false
            #else
            // On real device, if state is unknown, it might not be ready yet
            return false
            #endif
        }
        
        return state == .charging || state == .full
        #else
        return false
        #endif
    }
    
    /// Check if Do Not Disturb is enabled.
    /// Note: iOS doesn't provide a public API to detect DND status.
    /// This always returns false as we can't reliably detect it.
    private func isDoNotDisturbEnabled() -> Bool {
        // On iOS, there is no public API to detect Do Not Disturb status
        // Apple restricts access to DND settings for privacy reasons
        // This would require private APIs which are not allowed in App Store apps
        // Therefore, we always return false (DND not detected)
        return false
    }
    
    #if canImport(UIKit)
    /// Handle orientation change notification.
    @objc private func orientationDidChange() {
        lock.lock()
        defer { lock.unlock() }

        let currentOrientation = UIDevice.current.orientation

        // Count orientation changes by comparing with last orientation
        // This ensures we count all changes (portrait->landscape->portrait = 2 changes)
        if currentOrientation != lastOrientation,
           currentOrientation.isValidInterfaceOrientation,
           currentSessionId != nil {
            orientationChangeCount += 1
            lastOrientation = currentOrientation
        }
    }
    #endif
    
    /// Inject device context data into HSI JSON meta section.
    private func injectDeviceContextIntoHsiJson(_ hsiJson: String) -> String {
        guard let data = hsiJson.data(using: .utf8),
              var hsi = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return hsiJson
        }
        
        // Get or create meta section
        var meta = hsi["meta"] as? [String: Any] ?? [:]
        
        #if canImport(UIKit)
        // Calculate average screen brightness (start + end) / 2
        // Note: UIScreen.main.brightness may return 0.0 or default values on simulators
        // It requires a physical device to get accurate brightness values
        let endScreenBrightness = UIScreen.main.brightness
        let avgScreenBrightness = Double((startScreenBrightness + endScreenBrightness) / 2.0)
        
        // Only add brightness if it's a valid value (not 0.0, which might indicate unavailable)
        // On real devices, brightness should be between 0.0 and 1.0
        // We'll still add it even if 0.0, as that might be the actual brightness
        // The UI can handle displaying it appropriately
        meta["avg_screen_brightness"] = avgScreenBrightness
        
        // Get orientation string
        let startOrientationStr: String
        switch startOrientation {
        case .landscapeLeft, .landscapeRight:
            startOrientationStr = "landscape"
        default:
            startOrientationStr = "portrait"
        }
        
        // Add device context to meta
        meta["start_orientation"] = startOrientationStr
        meta["orientation_changes"] = orientationChangeCount
        #endif
        
        // Update meta in HSI JSON
        hsi["meta"] = meta
        
        // Convert back to JSON string
        if let jsonData = try? JSONSerialization.data(withJSONObject: hsi, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return hsiJson
    }
    
    /// Inject session spacing into HSI JSON meta section.
    private func injectSessionSpacingIntoHsiJson(_ hsiJson: String) -> String {
        guard let data = hsiJson.data(using: .utf8),
              var hsi = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return hsiJson
        }
        
        // Get or create meta section
        var meta = hsi["meta"] as? [String: Any] ?? [:]
        
        // Add session spacing (time in milliseconds between end of previous session and start of current session)
        meta["session_spacing"] = currentSessionSpacing
        
        // Update meta in HSI JSON
        hsi["meta"] = meta
        
        // Convert back to JSON string
        if let jsonData = try? JSONSerialization.data(withJSONObject: hsi, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return hsiJson
    }

    /// Get the current session ID.
    func getCurrentSessionId() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return currentSessionId
    }
    
    /// Get all events for the current session.
    func getSessionEvents() -> [BehaviorEvent] {
        lock.lock()
        defer { lock.unlock() }
        return sessionEvents
    }
    
    /// Get the current app switch count for the session.
    func getAppSwitchCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return appSwitchCount
    }

    /// Increment event count.
    func incrementEventCount() {
        lock.lock()
        defer { lock.unlock() }
        eventCount += 1
    }

    /// Record keystroke data.
    func recordKeystroke(cadence: Double, interKeyLatency: Double) {
        lock.lock()
        defer { lock.unlock() }

        typingCadences.append(cadence)
        interKeyLatencies.append(interKeyLatency)
        lastTypingCadence = cadence
        lastInterKeyLatency = interKeyLatency

        // Keep only recent data (last 100 samples)
        if typingCadences.count > 100 {
            typingCadences.removeFirst()
        }
        if interKeyLatencies.count > 100 {
            interKeyLatencies.removeFirst()
        }
    }

    /// Record scroll data.
    func recordScroll(velocity: Double) {
        lock.lock()
        defer { lock.unlock() }

        scrollVelocities.append(velocity)
        lastScrollVelocity = velocity

        // Keep only recent data (last 100 samples)
        if scrollVelocities.count > 100 {
            scrollVelocities.removeFirst()
        }
    }

    /// Record tap data.
    func recordTap(rate: Double) {
        lock.lock()
        defer { lock.unlock() }

        tapRates.append(rate)
        lastTapRate = rate

        // Keep only recent data (last 50 samples)
        if tapRates.count > 50 {
            tapRates.removeFirst()
        }
    }

    /// Record app switch.
    func recordAppSwitch() {
        lock.lock()
        defer { lock.unlock() }
        appSwitchCount += 1
    }

    /// Record foreground duration.
    func recordForegroundDuration(_ duration: Double) {
        lock.lock()
        defer { lock.unlock() }

        foregroundDurations.append(duration)
        lastForegroundDuration = duration

        // Keep only recent data (last 50 samples)
        if foregroundDurations.count > 50 {
            foregroundDurations.removeFirst()
        }
    }

    /// Record idle gap.
    func recordIdleGap(_ seconds: Double) {
        lock.lock()
        defer { lock.unlock() }

        idleGaps.append(seconds)
        lastIdleGapSeconds = seconds

        // Keep only recent data (last 50 samples)
        if idleGaps.count > 50 {
            idleGaps.removeFirst()
        }
    }

    /// Record stability metrics.
    func recordStability(stabilityIndex: Double, fragmentationIndex: Double) {
        lock.lock()
        defer { lock.unlock() }

        self.stabilityIndex = stabilityIndex
        self.fragmentationIndex = fragmentationIndex
    }

    /// Update scroll acceleration and jitter.
    func updateScrollMetrics(acceleration: Double?, jitter: Double?) {
        lock.lock()
        defer { lock.unlock() }

        lastScrollAcceleration = acceleration
        lastScrollJitter = jitter
    }

    /// Update burst length.
    func updateBurstLength(_ length: Int) {
        lock.lock()
        defer { lock.unlock() }
        lastBurstLength = length
    }

    /// Get current real-time statistics.
    func getCurrentStats() -> BehaviorStats {
        lock.lock()
        defer { lock.unlock() }

        return BehaviorStats(
            typingCadence: lastTypingCadence,
            interKeyLatency: lastInterKeyLatency,
            burstLength: lastBurstLength,
            scrollVelocity: lastScrollVelocity,
            scrollAcceleration: lastScrollAcceleration,
            scrollJitter: lastScrollJitter,
            tapRate: lastTapRate,
            appSwitchesPerMinute: appSwitchCount,
            foregroundDuration: lastForegroundDuration,
            idleGapSeconds: lastIdleGapSeconds,
            stabilityIndex: stabilityIndex,
            fragmentationIndex: fragmentationIndex,
            timestamp: currentTimestampMs()
        )
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func currentTimestampMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}
