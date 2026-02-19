import Foundation

#if canImport(UIKit)
import UIKit

/// Collects gesture activity signals including tap rate, long press, and drag velocity.
internal class GestureSignalCollector: NSObject {
    private weak var sdk: SynheartBehavior?
    private var sessionManager: SessionManager?

    // Gesture tracking
    private var windows: NSHashTable<UIWindow> = NSHashTable.weakObjects()
    private var tapTimes: [Int64] = []
    private var longPressTimes: [Int64] = []
    private let tapWindowMs: Int64 = 60000  // 1 minute window for tap rate
    private let longPressWindowMs: Int64 = 60000

    // Drag tracking
    private var dragStartTime: Int64 = 0
    private var dragStartPoint: CGPoint = .zero
    private var dragLastPoint: CGPoint = .zero
    private var dragLastTime: Int64 = 0

    init(sdk: SynheartBehavior, sessionManager: SessionManager) {
        self.sdk = sdk
        self.sessionManager = sessionManager
        super.init()
    }

    /// Start collecting gesture signals.
    func start() {
        // Set up window observation to attach gesture recognizers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeVisible(_:)),
            name: UIWindow.didBecomeVisibleNotification,
            object: nil
        )

        // Attach to existing windows
        for window in UIApplication.shared.windows {
            attachGestureRecognizers(to: window)
        }
    }

    /// Stop collecting gesture signals.
    func stop() {
        NotificationCenter.default.removeObserver(self)

        // Remove gesture recognizers
        for window in windows.allObjects {
            removeGestureRecognizers(from: window)
        }

        windows.removeAllObjects()
        tapTimes.removeAll()
        longPressTimes.removeAll()
    }

    @objc private func windowDidBecomeVisible(_ notification: Notification) {
        if let window = notification.object as? UIWindow {
            attachGestureRecognizers(to: window)
        }
    }

    private func attachGestureRecognizers(to window: UIWindow) {
        guard !windows.contains(window) else { return }

        windows.add(window)

        // Tap gesture recognizer
        // Set a small movement tolerance to avoid detecting taps during scrolling
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delegate = self
        // Allow small movement (10 points) to account for finger movement during tap
        tapRecognizer.numberOfTapsRequired = 1
        tapRecognizer.numberOfTouchesRequired = 1
        window.addGestureRecognizer(tapRecognizer)

        // Long press gesture recognizer
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressRecognizer.cancelsTouchesInView = false
        longPressRecognizer.delegate = self
        window.addGestureRecognizer(longPressRecognizer)

        // Pan gesture recognizer for drag tracking (horizontal swipes only)
        // Note: This should not interfere with scroll views which handle vertical scrolling
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panRecognizer.cancelsTouchesInView = false
        panRecognizer.delegate = self
        // Set minimum number of touches to 1 (default) and maximum to 1 (single finger swipes only)
        panRecognizer.maximumNumberOfTouches = 1
        window.addGestureRecognizer(panRecognizer)
    }

    private func removeGestureRecognizers(from window: UIWindow) {
        let recognizers = window.gestureRecognizers ?? []
        for recognizer in recognizers {
            if recognizer.delegate === self {
                window.removeGestureRecognizer(recognizer)
            }
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let sessionId = sessionManager?.getCurrentSessionId(),
              let view = recognizer.view else {
            return
        }

        // Don't count taps while keyboard is open (user is typing; taps are part of typing, not UI taps)
        if isTextInputFirstResponder() {
            return
        }

        // Check if this tap occurred on a scroll view - if so, it's likely a scroll, not a tap
        var currentView: UIView? = view
        while let checkView = currentView {
            if checkView is UIScrollView {
                // Don't record tap if it's on a scroll view (likely a scroll gesture)
                return
            }
            currentView = checkView.superview
        }

        let currentTime = currentTimestampMs()
        tapTimes.append(currentTime)

        // Remove taps outside the window
        tapTimes.removeAll { currentTime - $0 > tapWindowMs }

        // Calculate tap rate (taps per second)
        let tapRate = calculateTapRate()

        emitTapRateEvent(sessionId: sessionId, tapRate: tapRate)
        sessionManager?.recordTap(rate: tapRate)
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            return
        }
        // Don't count long press while keyboard is open (same as tap)
        if isTextInputFirstResponder() {
            return
        }

        let currentTime = currentTimestampMs()
        longPressTimes.append(currentTime)

        // Remove long presses outside the window
        longPressTimes.removeAll { currentTime - $0 > longPressWindowMs }

        // Calculate long press rate (presses per minute)
        let longPressRate = Double(longPressTimes.count) / 60.0

        emitLongPressRateEvent(sessionId: sessionId, rate: longPressRate)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let sessionId = sessionManager?.getCurrentSessionId(),
              let view = recognizer.view else {
            return
        }

        let currentTime = currentTimestampMs()
        let currentPoint = recognizer.location(in: view)

        switch recognizer.state {
        case .began:
            // Check if we're starting on a scroll view - if so, don't track as swipe
            var currentView: UIView? = view
            var isOnScrollView = false
            while let checkView = currentView {
                if checkView is UIScrollView {
                    isOnScrollView = true
                    break
                }
                currentView = checkView.superview
            }
            
            // Only track if not on scroll view (scroll views handle their own gestures)
            if !isOnScrollView {
                dragStartTime = currentTime
                dragStartPoint = currentPoint
                dragLastPoint = currentPoint
                dragLastTime = currentTime
            }

        case .changed:
            // Don't emit events during .changed - only track position
            // Only track if we started tracking (not on scroll view)
            guard dragStartTime > 0 else {
                return
            }
            dragLastPoint = currentPoint
            dragLastTime = currentTime

        case .ended, .cancelled:
            // Only emit ONE swipe event when gesture ends
            // Only process if we were tracking (not on scroll view)
            guard dragStartTime > 0 else {
                return
            }
            
            let totalDistance = sqrt(pow(currentPoint.x - dragStartPoint.x, 2) + pow(currentPoint.y - dragStartPoint.y, 2))
            let totalTime = currentTime - dragStartTime
            
            // Calculate movement deltas
            let deltaX = currentPoint.x - dragStartPoint.x
            let deltaY = currentPoint.y - dragStartPoint.y
            
            // Only treat as swipe if:
            // 1. Significant movement (> 50px)
            // 2. Sufficient duration (>= 100ms)
            // 3. Primarily horizontal movement (horizontal movement > vertical movement)
            // This prevents vertical scrolling from being detected as swipes
            let isHorizontalSwipe = abs(deltaX) > abs(deltaY) && abs(deltaX) > 50.0 && totalTime >= 100
            
            if isHorizontalSwipe && totalTime > 0 {
                // Use native velocity from UIPanGestureRecognizer
                let nativeVelocity = recognizer.velocity(in: view)
                let velocityX = nativeVelocity.x
                let velocity = abs(velocityX) // Use horizontal velocity for horizontal swipes
                
                // Calculate acceleration
                let durationSeconds = Double(totalTime) / 1000.0
                let acceleration = durationSeconds > 0.05
                    ? (2.0 * abs(deltaX)) / (durationSeconds * durationSeconds)
                    : 0.0
                
                // Determine swipe direction (horizontal only)
                let direction: String = deltaX > 0 ? "right" : "left"
                
                emitSwipeEvent(
                    sessionId: sessionId,
                    direction: direction,
                    distancePx: abs(deltaX), // Use horizontal distance
                    durationMs: Int(totalTime),
                    velocity: velocity,
                    acceleration: acceleration
                )
            }

        default:
            break
        }
    }

    private func calculateTapRate() -> Double {
        guard !tapTimes.isEmpty else { return 0.0 }

        // Calculate taps per second over the window
        return Double(tapTimes.count) / (Double(tapWindowMs) / 1000.0)
    }

    private func emitTapRateEvent(sessionId: String, tapRate: Double) {
        let event = BehaviorEvent(
            sessionId: sessionId,
            type: .tap,
            payload: [
                "rate": tapRate,
                "count": tapTimes.count
            ]
        )
        sdk?.emitEvent(event)
    }

    private func emitLongPressRateEvent(sessionId: String, rate: Double) {
        let event = BehaviorEvent(
            sessionId: sessionId,
            type: .tap,
            payload: [
                "rate": rate,
                "count": longPressTimes.count,
                "long_press": true
            ]
        )
        sdk?.emitEvent(event)
    }

    private func emitSwipeEvent(sessionId: String, direction: String, distancePx: Double, durationMs: Int, velocity: Double, acceleration: Double) {
        let event = BehaviorEvent(
            sessionId: sessionId,
            type: .swipe,
            payload: [
                "velocity": velocity,
                "direction": direction,
                "distance": distancePx,
                "duration_ms": durationMs,
                "acceleration": acceleration
            ]
        )
        sdk?.emitEvent(event)
    }

    /// Get current gesture statistics.
    func getCurrentStats() -> Double {
        return calculateTapRate()
    }

    private func currentTimestampMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// True when the current first responder is a text field or text view (keyboard open).
    /// Taps/long presses are not counted in that case so they aren't double-counted as tap events.
    private func isTextInputFirstResponder() -> Bool {
        guard let window = Self.keyWindow() else { return false }
        guard let firstResponder = window.findFirstResponder() else { return false }
        return firstResponder is UITextField || firstResponder is UITextView
    }
}

// MARK: - Key window and first responder (keyboard-open check)
private extension GestureSignalCollector {
    static func keyWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }
}

private extension UIWindow {
    func findFirstResponder() -> UIView? {
        if let r = rootViewController?.view?.findFirstResponderInHierarchy() { return r }
        if let presented = rootViewController?.presentedViewController?.view?.findFirstResponderInHierarchy() { return presented }
        return nil
    }
}

private extension UIView {
    func findFirstResponderInHierarchy() -> UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let r = subview.findFirstResponderInHierarchy() { return r }
        }
        return nil
    }
}

// MARK: - UIGestureRecognizerDelegate
extension GestureSignalCollector: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our gesture recognizers to work alongside others, but not with scroll view pan recognizers
        // Scroll views have their own pan gesture recognizers that should take priority
        if otherGestureRecognizer.view is UIScrollView {
            return false
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view = touch.view else {
            return true
        }
        
        // Don't interfere with scroll views - let them handle their own gestures
        // Check if the touch is on a scroll view or any of its subviews
        var currentView: UIView? = view
        while let checkView = currentView {
            if checkView is UIScrollView {
                // If it's a pan gesture recognizer and we're on a scroll view, don't handle it
                // (scroll views should handle vertical scrolling)
                if gestureRecognizer is UIPanGestureRecognizer {
                    return false
                }
                // For tap/long press, still allow but be more careful
                break
            }
            currentView = checkView.superview
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Our pan gesture should fail if a scroll view's pan gesture recognizes
        // This ensures scroll views get priority for vertical scrolling
        if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer.view is UIScrollView {
            return true
        }
        return false
    }
}

#else

/// No-op fallback for platforms without UIKit (e.g. macOS SwiftPM tests).
internal class GestureSignalCollector: NSObject {
    init(sdk: SynheartBehavior, sessionManager: SessionManager) {
        super.init()
    }

    func start() {}
    func stop() {}

    func getCurrentStats() -> Double { 0.0 }
}

#endif
