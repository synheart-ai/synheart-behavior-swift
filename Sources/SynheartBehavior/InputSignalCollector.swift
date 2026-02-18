import Foundation

#if canImport(UIKit)
import UIKit

/// Collects input interaction signals including keystroke timing and burst detection.
internal class InputSignalCollector {
    private weak var sdk: SynheartBehavior?
    private var sessionManager: SessionManager?

    // Keystroke timing tracking
    private var lastKeystrokeTime: Int64 = 0
    private var keystrokeBuffer: [Int64] = []
    private var currentBurstLength: Int = 0
    private let burstThresholdMs: Int64 = 2000  // 2 seconds
    private let cadenceWindowSize = 10

    init(sdk: SynheartBehavior, sessionManager: SessionManager) {
        self.sdk = sdk
        self.sessionManager = sessionManager
    }

    /// Start collecting input signals by swizzling text input methods.
    func start() {
        // Set up notification observers for text field changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: UITextField.textDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: UITextView.textDidChangeNotification,
            object: nil
        )
    }

    /// Stop collecting input signals.
    func stop() {
        NotificationCenter.default.removeObserver(self)
        keystrokeBuffer.removeAll()
        currentBurstLength = 0
        lastKeystrokeTime = 0
    }

    @objc private func textDidChange(_ notification: Notification) {
        let currentTime = currentTimestampMs()

        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            return
        }

        // Calculate inter-key latency
        var interKeyLatency: Int64 = 0
        if lastKeystrokeTime > 0 {
            interKeyLatency = currentTime - lastKeystrokeTime
        }

        lastKeystrokeTime = currentTime
        keystrokeBuffer.append(currentTime)

        // Keep only recent keystrokes for cadence calculation
        if keystrokeBuffer.count > cadenceWindowSize {
            keystrokeBuffer.removeFirst()
        }

        // Detect burst
        if interKeyLatency > 0 && interKeyLatency < burstThresholdMs {
            currentBurstLength += 1
        } else {
            // Burst ended, emit if significant
            if currentBurstLength >= 3 {
                emitBurstEvent(sessionId: sessionId, burstLength: currentBurstLength)
            }
            currentBurstLength = 1
        }

        // Calculate and emit typing cadence if we have enough data
        if keystrokeBuffer.count >= 3 {
            let cadence = calculateTypingCadence()
            emitTypingCadenceEvent(
                sessionId: sessionId,
                cadence: cadence,
                interKeyLatency: Double(interKeyLatency)
            )

            // Update session stats
            sessionManager?.recordKeystroke(
                cadence: cadence,
                interKeyLatency: Double(interKeyLatency)
            )
        }
    }

    private func calculateTypingCadence() -> Double {
        guard keystrokeBuffer.count >= 2 else {
            return 0.0
        }

        let timeSpanMs = keystrokeBuffer.last! - keystrokeBuffer.first!
        if timeSpanMs == 0 {
            return 0.0
        }

        let keysPerMs = Double(keystrokeBuffer.count - 1) / Double(timeSpanMs)
        return keysPerMs * 1000.0  // Convert to keys per second
    }

    private func emitTypingCadenceEvent(sessionId: String, cadence: Double, interKeyLatency: Double) {
        let event = BehaviorEvent(
            sessionId: sessionId,
            type: .typing,
            payload: [
                "typing_speed": cadence,
                "mean_inter_tap_interval_ms": interKeyLatency,
                "typing_tap_count": currentBurstLength
            ]
        )
        sdk?.emitEvent(event)
    }

    private func emitBurstEvent(sessionId: String, burstLength: Int) {
        let event = BehaviorEvent(
            sessionId: sessionId,
            type: .typing,
            payload: [
                "typing_tap_count": burstLength
            ]
        )
        sdk?.emitEvent(event)
    }

    /// Get current typing statistics.
    func getCurrentStats() -> (cadence: Double?, interKeyLatency: Double?, burstLength: Int?) {
        let cadence = keystrokeBuffer.count >= 2 ? calculateTypingCadence() : nil
        let latency = lastKeystrokeTime > 0 ? Double(currentTimestampMs() - lastKeystrokeTime) : nil
        let burst = currentBurstLength > 0 ? currentBurstLength : nil

        return (cadence, latency, burst)
    }

    private func currentTimestampMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}

#else

/// No-op fallback for platforms without UIKit (e.g. macOS SwiftPM tests).
internal class InputSignalCollector {
    init(sdk: SynheartBehavior, sessionManager: SessionManager) {}

    func start() {}
    func stop() {}

    func getCurrentStats() -> (cadence: Double?, interKeyLatency: Double?, burstLength: Int?) {
        (nil, nil, nil)
    }
}

#endif
