import Foundation

#if canImport(UIKit)
import UIKit

/// Collects scroll dynamics signals including velocity, acceleration, and jitter.
internal class ScrollSignalCollector: NSObject {
    private weak var sdk: SynheartBehavior?
    private var sessionManager: SessionManager?

    // Scroll tracking
    private var scrollViews: NSHashTable<UIScrollView> = NSHashTable.weakObjects()
    private var scrollStartTime: Int64 = 0
    private var lastScrollTime: Int64 = 0
    private var lastScrollOffset: CGFloat = 0
    private var lastVelocity: Double = 0
    private var velocityBuffer: [Double] = []
    private let velocityWindowSize = 5

    // Swizzling state
    private static var hasSwizzled = false

    init(sdk: SynheartBehavior, sessionManager: SessionManager) {
        self.sdk = sdk
        self.sessionManager = sessionManager
        super.init()
    }

    /// Start collecting scroll signals by tracking scroll views.
    func start() {
        swizzleScrollViewMethods()

        // Observe when scroll views are added to view hierarchy
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeVisible(_:)),
            name: UIWindow.didBecomeVisibleNotification,
            object: nil
        )
    }

    /// Stop collecting scroll signals.
    func stop() {
        NotificationCenter.default.removeObserver(self)
        scrollViews.removeAllObjects()
        velocityBuffer.removeAll()
    }

    @objc private func windowDidBecomeVisible(_ notification: Notification) {
        // This helps us discover new scroll views as they appear
        if let window = notification.object as? UIWindow {
            discoverScrollViews(in: window)
        }
    }

    private func discoverScrollViews(in view: UIView) {
        if let scrollView = view as? UIScrollView {
            trackScrollView(scrollView)
        }

        for subview in view.subviews {
            discoverScrollViews(in: subview)
        }
    }

    private func trackScrollView(_ scrollView: UIScrollView) {
        if !scrollViews.contains(scrollView) {
            scrollViews.add(scrollView)
            scrollView.delegate = self
        }
    }

    private func swizzleScrollViewMethods() {
        guard !ScrollSignalCollector.hasSwizzled else { return }
        ScrollSignalCollector.hasSwizzled = true

        // Note: In production, you might want to use method swizzling
        // to intercept UIScrollView initialization. For now, we rely on
        // discovering scroll views through the window hierarchy.
    }

    /// Get current scroll statistics.
    func getCurrentStats() -> (velocity: Double?, acceleration: Double?, jitter: Double?) {
        let velocity = velocityBuffer.isEmpty ? nil : velocityBuffer.last
        let acceleration = calculateAcceleration()
        let jitter = calculateJitter()

        return (velocity, acceleration, jitter)
    }

    private func calculateAcceleration() -> Double? {
        guard velocityBuffer.count >= 2 else { return nil }

        let velocityChange = velocityBuffer.last! - velocityBuffer[velocityBuffer.count - 2]
        let timeDelta = 0.1  // Approximate time between samples

        return velocityChange / timeDelta
    }

    private func calculateJitter() -> Double? {
        guard velocityBuffer.count >= 3 else { return nil }

        let mean = velocityBuffer.reduce(0, +) / Double(velocityBuffer.count)
        let variance = velocityBuffer.map { pow($0 - mean, 2) }.reduce(0, +) / Double(velocityBuffer.count)

        return sqrt(variance)
    }

    private func currentTimestampMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - UIScrollViewDelegate
extension ScrollSignalCollector: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollStartTime = currentTimestampMs()
        lastScrollTime = scrollStartTime
        lastScrollOffset = scrollView.contentOffset.y
        velocityBuffer.removeAll()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            return
        }

        let currentTime = currentTimestampMs()
        let currentOffset = scrollView.contentOffset.y
        let timeDelta = currentTime - lastScrollTime

        guard timeDelta > 0 else { return }

        // Calculate velocity (pixels per second)
        let offsetDelta = currentOffset - lastScrollOffset
        let velocity = abs(Double(offsetDelta) / (Double(timeDelta) / 1000.0))

        velocityBuffer.append(velocity)
        if velocityBuffer.count > velocityWindowSize {
            velocityBuffer.removeFirst()
        }

        // Calculate acceleration if we have previous velocity
        var acceleration: Double = 0
        if !velocityBuffer.isEmpty && velocityBuffer.count >= 2 {
            let velocityChange = velocity - velocityBuffer[velocityBuffer.count - 2]
            acceleration = velocityChange / (Double(timeDelta) / 1000.0)
        }

        // Emit scroll velocity event
        if velocityBuffer.count >= 2 {
            let jitter = calculateJitter() ?? 0
            emitScrollVelocityEvent(
                sessionId: sessionId,
                velocity: velocity,
                acceleration: acceleration,
                jitter: jitter
            )

            // Update session stats
            sessionManager?.recordScroll(velocity: velocity)
        }

        lastScrollTime = currentTime
        lastScrollOffset = currentOffset
        lastVelocity = velocity
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            return
        }

        if !decelerate {
            emitScrollStopEvent(sessionId: sessionId)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            return
        }

        emitScrollStopEvent(sessionId: sessionId)
    }

    private func emitScrollVelocityEvent(sessionId: String, velocity: Double, acceleration: Double, jitter: Double) {
        let event = BehaviorEvent(
            sessionId: sessionId,
            type: .scroll,
            payload: [
                "velocity": velocity,
                "acceleration": acceleration,
                "jitter": jitter
            ]
        )
        sdk?.emitEvent(event)
    }

    private func emitScrollStopEvent(sessionId: String) {
        let event = BehaviorEvent(
            sessionId: sessionId,
            type: .scroll,
            payload: [
                "duration_ms": currentTimestampMs() - scrollStartTime,
                "final_velocity": lastVelocity
            ]
        )
        sdk?.emitEvent(event)
    }
}

#else

/// No-op fallback for platforms without UIKit (e.g. macOS SwiftPM tests).
internal class ScrollSignalCollector: NSObject {
    init(sdk: SynheartBehavior, sessionManager: SessionManager) {
        super.init()
    }

    func start() {}
    func stop() {}

    func getCurrentStats() -> (velocity: Double?, acceleration: Double?, jitter: Double?) {
        (nil, nil, nil)
    }
}

#endif
