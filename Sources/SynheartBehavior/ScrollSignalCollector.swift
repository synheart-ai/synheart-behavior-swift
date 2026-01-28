import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects scroll dynamics signals including velocity, acceleration, and jitter.
internal class ScrollSignalCollector: NSObject {
    private weak var sdk: SynheartBehavior?
    private var sessionManager: SessionManager?

    // Scroll tracking
    private var scrollViews: NSHashTable<UIScrollView> = NSHashTable.weakObjects()
    private var scrollStartTime: Int64 = 0
    private var scrollStartPosition: CGFloat = 0
    private var scrollEndPosition: CGFloat = 0
    private var lastScrollTime: Int64 = 0
    private var lastScrollPosition: CGFloat = 0
    private var lastScrollDirection: String? = nil // "up" or "down"
    private var hasDirectionReversal = false
    private var scrollStopTimer: Timer? = nil
    private let scrollStopThresholdMs: Double = 1000.0 // Wait 1000ms after last scroll update
    private var nativeScrollVelocity: Double = 0 // Store native velocity from iOS when available

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

        // Discover scroll views immediately from all windows
        discoverScrollViewsFromAllWindows()
        
        // Observe when scroll views are added to view hierarchy
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeVisible(_:)),
            name: UIWindow.didBecomeVisibleNotification,
            object: nil
        )
        
        // Also discover when app becomes active (view controllers might have appeared)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// Stop collecting scroll signals.
    func stop() {
        NotificationCenter.default.removeObserver(self)
        scrollViews.removeAllObjects()
        scrollStopTimer?.invalidate()
        scrollStopTimer = nil
    }

    private func discoverScrollViewsFromAllWindows() {
        // Discover scroll views from all currently visible windows
        if #available(iOS 13.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    discoverScrollViews(in: window)
                }
            }
        } else {
            // Fallback for iOS 12 and earlier
            if let keyWindow = UIApplication.shared.keyWindow {
                discoverScrollViews(in: keyWindow)
            }
            // Also check all windows (if available)
            for window in UIApplication.shared.windows {
                discoverScrollViews(in: window)
            }
        }
    }
    
    @objc private func windowDidBecomeVisible(_ notification: Notification) {
        // This helps us discover new scroll views as they appear
        if let window = notification.object as? UIWindow {
            discoverScrollViews(in: window)
        }
    }
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        // When app becomes active, rediscover scroll views (views might have been added)
        discoverScrollViewsFromAllWindows()
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
            // Store original delegate if it exists, then set ourselves as delegate
            // Note: This replaces the delegate, but for the example app this is fine
            // In production, you might want to use a proxy pattern to forward calls
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
        // Return nil if no scroll is active
        guard scrollStartTime > 0 else { return (nil, nil, nil) }
        
        // Calculate current velocity if scroll is active
        let currentTime = currentTimestampMs()
        let timeDelta = currentTime - lastScrollTime
        let velocity: Double? = timeDelta > 0 ? nativeScrollVelocity : nil
        let acceleration: Double? = nil // Not calculated in real-time
        let jitter: Double? = hasDirectionReversal ? 1.0 : 0.0

        return (velocity, acceleration, jitter)
    }

    private func currentTimestampMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - UIScrollViewDelegate
extension ScrollSignalCollector: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollStartTime = currentTimestampMs()
        scrollStartPosition = scrollView.contentOffset.y
        scrollEndPosition = scrollView.contentOffset.y
        lastScrollTime = scrollStartTime
        lastScrollPosition = scrollView.contentOffset.y
        lastScrollDirection = "down"
        hasDirectionReversal = false
        nativeScrollVelocity = 0
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            return
        }

        let currentTime = currentTimestampMs()
        let currentPosition = scrollView.contentOffset.y

        // If this is the start of a new scroll, initialize tracking
        if scrollStartTime == 0 {
            scrollStartTime = currentTime
            scrollStartPosition = currentPosition
            scrollEndPosition = currentPosition
            lastScrollPosition = currentPosition
            lastScrollTime = currentTime
            hasDirectionReversal = false
            lastScrollDirection = "down"
        } else {
            // For subsequent updates, determine direction from position change
            // Use a very low threshold (0.001) to catch direction changes even during fast scrolling
            let positionChange = currentPosition - lastScrollPosition
            let newDirection: String
            
            // Use very low threshold to catch fast direction reversals (matching Dart SDK)
            if positionChange > 0.001 {
                newDirection = "down"
            } else if positionChange < -0.001 {
                newDirection = "up"
            } else {
                // No significant movement, keep previous direction
                newDirection = lastScrollDirection ?? "down"
            }

            // Check for direction reversal: if direction changed from previous stored direction
            // IMPORTANT: Check even if positionChange is small, as direction changes often happen with small deltas
            // This is the key check - if newDirection differs from lastScrollDirection, we have a reversal
            if let lastDir = lastScrollDirection, lastDir != newDirection {
                hasDirectionReversal = true
            }

            // Update direction if we have a valid new direction
            // Always update direction when we detect a change, even if movement is small
            // This ensures we catch fast direction reversals
            if newDirection != lastScrollDirection {
                lastScrollDirection = newDirection
                // Update last position to track future direction changes
                lastScrollPosition = currentPosition
            } else if abs(positionChange) > 0.1 {
                // Update position even if direction didn't change, to track movement
                lastScrollPosition = currentPosition
            }
            scrollEndPosition = currentPosition
            lastScrollTime = currentTime
        }

        // Cancel previous timer and start a new one
        // Wait 1000ms after last scroll update before finalizing
        scrollStopTimer?.invalidate()
        scrollStopTimer = Timer.scheduledTimer(withTimeInterval: scrollStopThresholdMs / 1000.0, repeats: false) { [weak self] _ in
            self?.finalizeScroll()
        }
    }
    
    // Get native velocity when user lifts finger (iOS provides this)
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // Store native velocity from iOS (in points per second)
        nativeScrollVelocity = abs(velocity.y)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // Don't emit here - let the timer handle it
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Don't emit here - let the timer handle it
    }
    
    private func finalizeScroll() {
        guard scrollStartTime > 0 else { return }
        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            return
        }

        let now = currentTimestampMs()
        let durationMs = now - scrollStartTime
        let distancePx = abs(scrollEndPosition - scrollStartPosition)

        if durationMs > 0 && distancePx > 0 {
            // Calculate velocity in pixels per second
            let velocity: Double
            if nativeScrollVelocity > 0 {
                // Use native velocity from iOS (more accurate)
                velocity = min(max(nativeScrollVelocity, 0.0), 10000.0)
            } else {
                // Calculate average velocity (distance / time)
                velocity = min(max((Double(distancePx) / Double(durationMs) * 1000.0), 0.0), 10000.0)
            }

            // Calculate acceleration using proper physics formula
            let durationSeconds = Double(durationMs) / 1000.0
            let acceleration = durationSeconds > 0.1
                ? (2.0 * Double(distancePx)) / (durationSeconds * durationSeconds)
                : 0.0
            let clampedAcceleration = min(max(acceleration, 0.0), 50000.0)

            // Emit ONE scroll event when scroll stops
            emitScrollEvent(
                sessionId: sessionId,
                velocity: velocity,
                acceleration: clampedAcceleration,
                direction: lastScrollDirection ?? "down",
                directionReversal: hasDirectionReversal
            )

            // Update session stats
            sessionManager?.recordScroll(velocity: velocity)
        }
        
        // Reset scroll tracking
        scrollStartTime = 0
        scrollStartPosition = 0
        scrollEndPosition = 0
        lastScrollTime = 0
        lastScrollPosition = 0
        lastScrollDirection = nil
        hasDirectionReversal = false
        nativeScrollVelocity = 0
    }

    private func emitScrollEvent(sessionId: String, velocity: Double, acceleration: Double, direction: String, directionReversal: Bool) {
        let event = BehaviorEvent(
            sessionId: sessionId,
            timestamp: currentTimestampMs(),
            type: .scrollVelocity,
            payload: [
                "velocity": velocity,
                "acceleration": acceleration,
                "direction": direction,
                "direction_reversal": directionReversal
            ]
        )
        sdk?.emitEvent(event)
    }
}
