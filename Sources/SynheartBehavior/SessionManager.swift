import Foundation

/// Manages behavioral tracking sessions and aggregates statistics.
internal class SessionManager {
    private var currentSessionId: String?
    private var sessionStartTime: Int64 = 0
    private var eventCount = 0

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

    private let lock = NSLock()

    /// Start a new session.
    func startSession(sessionId: String) {
        lock.lock()
        defer { lock.unlock() }

        currentSessionId = sessionId
        sessionStartTime = currentTimestampMs()
        eventCount = 0

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

    /// Get the current session ID.
    func getCurrentSessionId() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return currentSessionId
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
