import Foundation
#if canImport(UIKit)
import UIKit
#endif

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
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delegate = self
        window.addGestureRecognizer(tapRecognizer)

        // Long press gesture recognizer
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressRecognizer.cancelsTouchesInView = false
        longPressRecognizer.delegate = self
        window.addGestureRecognizer(longPressRecognizer)

        // Pan gesture recognizer for drag tracking
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panRecognizer.cancelsTouchesInView = false
        panRecognizer.delegate = self
        window.addGestureRecognizer(panRecognizer)
    }

    private func removeGestureRecognizers(from window: UIWindow) {
        let recognizers = window.gestureRecognizers ?? []
        for recognizer in recognizers {
            if recognizer.target as? GestureSignalCollector === self {
                window.removeGestureRecognizer(recognizer)
            }
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            return
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

        let currentTime = currentTimestampMs()
        longPressTimes.append(currentTime)

        // Remove long presses outside the window
        longPressTimes.removeAll { currentTime - $0 > longPressWindowMs }

        // Calculate long press rate (presses per minute)
        let longPressRate = Double(longPressTimes.count) / 60.0

        emitLongPressRateEvent(sessionId: sessionId, rate: longPressRate)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            return
        }

        let currentTime = currentTimestampMs()
        let currentPoint = recognizer.location(in: recognizer.view)

        switch recognizer.state {
        case .began:
            dragStartTime = currentTime
            dragStartPoint = currentPoint
            dragLastPoint = currentPoint
            dragLastTime = currentTime

        case .changed:
            let timeDelta = currentTime - dragLastTime
            guard timeDelta > 0 else { return }

            let distance = sqrt(pow(currentPoint.x - dragLastPoint.x, 2) + pow(currentPoint.y - dragLastPoint.y, 2))
            let velocity = Double(distance) / (Double(timeDelta) / 1000.0)  // pixels per second

            if velocity > 10 {  // Only emit if significant movement
                emitDragVelocityEvent(sessionId: sessionId, velocity: velocity)
            }

            dragLastPoint = currentPoint
            dragLastTime = currentTime

        case .ended, .cancelled:
            let totalDistance = sqrt(pow(currentPoint.x - dragStartPoint.x, 2) + pow(currentPoint.y - dragStartPoint.y, 2))
            let totalTime = currentTime - dragStartTime
            let averageVelocity = totalTime > 0 ? Double(totalDistance) / (Double(totalTime) / 1000.0) : 0

            emitDragVelocityEvent(sessionId: sessionId, velocity: averageVelocity)

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
            timestamp: currentTimestampMs(),
            type: .tapRate,
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
            timestamp: currentTimestampMs(),
            type: .longPressRate,
            payload: [
                "rate": rate,
                "count": longPressTimes.count
            ]
        )
        sdk?.emitEvent(event)
    }

    private func emitDragVelocityEvent(sessionId: String, velocity: Double) {
        let event = BehaviorEvent(
            sessionId: sessionId,
            timestamp: currentTimestampMs(),
            type: .dragVelocity,
            payload: [
                "velocity": velocity
            ]
        )
        sdk?.emitEvent(event)
    }

    /// Get current gesture statistics.
    func getCurrentStats() -> (tapRate: Double?) {
        return (calculateTapRate())
    }

    private func currentTimestampMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension GestureSignalCollector: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our gesture recognizers to work alongside others
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Always receive touches without blocking
        return true
    }
}
