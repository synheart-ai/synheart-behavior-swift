import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects input interaction signals including keystroke timing and typing session tracking.
/// Tracks typing sessions from keyboard open (focus gain) to keyboard close (focus loss).
internal class InputSignalCollector {
    private weak var sdk: SynheartBehavior?
    private var sessionManager: SessionManager?

    // Typing session tracking
    private var currentTypingSession: TypingSession?
    
    // Constants from Dart SDK
    private let gapThresholdMs: Int64 = 5000  // 5 seconds for gap count
    private let activityThresholdMs: Int64 = 2000  // 2 seconds for activity ratio
    private let deepTypingDurationSeconds: Int64 = 60  // 1 minute
    private let vMax: Double = 10.0  // taps/s for speed normalization
    private let w1: Double = 0.4  // weight for typing speed
    private let w2: Double = 0.35  // weight for gap behavior
    private let w3: Double = 0.25  // weight for cadence stability

    private struct TypingSession {
        var startTime: Date
        var keystrokes: [Int64]  // Timestamps of keystrokes
        var interKeyLatencies: [Int64]  // Inter-key intervals in ms (only actual intervals, not 0 for first keystroke)
        var previousLength: Int = 0
        var backspaceCount: Int = 0   // Only actual backspace/delete taps; cut removals are not counted
        var lastDeletionAmount: Int = 0  // Last length decrease we attributed to backspace; undone when recordCut() is called
        var numberOfCopy: Int = 0    // Set via recordCopy() from custom text view
        var numberOfPaste: Int = 0   // Set via recordPaste() from custom text view
        var numberOfCut: Int = 0     // Set via recordCut() from custom text view
    }

    init(sdk: SynheartBehavior, sessionManager: SessionManager) {
        self.sdk = sdk
        self.sessionManager = sessionManager
    }

    /// Start collecting input signals.
    func start() {
        // Listen for text field/text view focus changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textFieldDidBeginEditing(_:)),
            name: UITextField.textDidBeginEditingNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textFieldDidEndEditing(_:)),
            name: UITextField.textDidEndEditingNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textViewDidBeginEditing(_:)),
            name: UITextView.textDidBeginEditingNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textViewDidEndEditing(_:)),
            name: UITextView.textDidEndEditingNotification,
            object: nil
        )

        // Listen for text changes
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
        // End any active typing session
        endCurrentTypingSession()
    }
    
    @objc private func textFieldDidBeginEditing(_ notification: Notification) {
        startTypingSession()
    }
    
    @objc private func textFieldDidEndEditing(_ notification: Notification) {
        endCurrentTypingSession()
    }
    
    @objc private func textViewDidBeginEditing(_ notification: Notification) {
        startTypingSession()
    }
    
    @objc private func textViewDidEndEditing(_ notification: Notification) {
        endCurrentTypingSession()
    }
    
    private func startTypingSession() {
        // Start a new typing session
        currentTypingSession = TypingSession(
            startTime: Date(),
            keystrokes: [],
            interKeyLatencies: [],
            previousLength: 0
        )
    }
    
    /// End any active typing session (called when behavior session ends)
    func endActiveTypingSession() {
        endCurrentTypingSession()
    }
    
    private func endCurrentTypingSession() {
        guard var session = currentTypingSession else {
            return
        }
        
        // Only emit if we have keystrokes
        guard !session.interKeyLatencies.isEmpty else {
            currentTypingSession = nil
            return
        }
        
        // Calculate all typing metrics
        let typingTapCount = session.keystrokes.count
        let durationMs = Int64(Date().timeIntervalSince(session.startTime) * 1000)
        let durationSeconds = Double(durationMs) / 1000.0
        
        // Calculate mean inter-tap interval
        let meanInterTapIntervalMs = session.interKeyLatencies.isEmpty ? 0.0 : Double(session.interKeyLatencies.reduce(0, +)) / Double(session.interKeyLatencies.count)
        
        // Calculate typing speed (taps per second)
        let typingSpeed = durationSeconds > 0 ? Double(typingTapCount) / durationSeconds : 0.0
        
        // Calculate typing gap count (gaps >= 5 seconds)
        let typingGapCount = session.interKeyLatencies.filter { $0 >= gapThresholdMs }.count
        
        // Calculate typing gap ratio
        let typingGapRatio = session.interKeyLatencies.isEmpty ? 0.0 : Double(typingGapCount) / Double(session.interKeyLatencies.count)
        
        // Calculate typing burstiness (coefficient of variation of inter-key intervals)
        let typingBurstiness = calculateBurstiness(session.interKeyLatencies)
        
        // Calculate typing cadence stability (inverse of coefficient of variation)
        let typingCadenceStability = calculateCadenceStability(session.interKeyLatencies)
        
        // Typing cadence variability: standard deviation of inter-tap intervals (ms), aligned with Kotlin/Dart
        let typingCadenceVariability = calculateCadenceVariability(session.interKeyLatencies)
        
        // Calculate typing activity ratio (time spent typing vs total session time)
        let activeTimeMs = session.interKeyLatencies.filter { $0 < activityThresholdMs }.reduce(0) { $0 + $1 }
        let typingActivityRatio = durationMs > 0 ? Double(activeTimeMs) / Double(durationMs) : 0.0
        
        // Calculate typing interaction intensity (weighted combination)
        let normalizedSpeed = min(typingSpeed / vMax, 1.0)
        let gapScore = 1.0 - typingGapRatio
        let cadenceScore = typingCadenceStability
        let typingInteractionIntensity = (w1 * normalizedSpeed) + (w2 * gapScore) + (w3 * cadenceScore)
        
        // Check if deep typing (>= 60 seconds)
        let deepTyping = durationSeconds >= Double(deepTypingDurationSeconds)
        
        // Format timestamps
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startAt = formatter.string(from: session.startTime)
        let endAt = formatter.string(from: Date())
        
        guard let sessionId = sessionManager?.getCurrentSessionId() else {
            currentTypingSession = nil
            return
        }
        
        // Emit typing event with all metrics (aligned with Kotlin/Dart; correction/clipboard for Flux)
        var payload: [String: Any] = [
            "typing_tap_count": typingTapCount,
            "typing_speed": typingSpeed,
            "mean_inter_tap_interval_ms": meanInterTapIntervalMs,
            "typing_cadence_variability": typingCadenceVariability,
            "typing_cadence_stability": typingCadenceStability,
            "typing_gap_count": typingGapCount,
            "typing_gap_ratio": typingGapRatio,
            "typing_burstiness": typingBurstiness,
            "typing_activity_ratio": typingActivityRatio,
            "typing_interaction_intensity": typingInteractionIntensity,
            "duration": durationSeconds,
            "start_at": startAt,
            "end_at": endAt,
            "deep_typing": deepTyping,
            "backspace_count": session.backspaceCount,
            "number_of_delete": 0,  // iOS has no forward-delete key
            "number_of_copy": session.numberOfCopy,
            "number_of_paste": session.numberOfPaste,
            "number_of_cut": session.numberOfCut
        ]
        let event = BehaviorEvent(
            sessionId: sessionId,
            timestamp: currentTimestampMs(),
            type: .typingCadence,
            payload: payload
        )
        
        sdk?.emitEvent(event)
        currentTypingSession = nil
    }

    @objc private func textDidChange(_ notification: Notification) {
        guard var session = currentTypingSession else {
            // No active typing session - this is normal if user is typing without focus
            return
        }
        
        // Get current text length from the notification object
        let currentLength: Int
        if let textField = notification.object as? UITextField {
            currentLength = textField.text?.count ?? 0
        } else if let textView = notification.object as? UITextView {
            currentLength = textView.text.count
        } else {
            return
        }
        
        if currentLength > session.previousLength {
            let now = currentTimestampMs()
            if let lastKeystroke = session.keystrokes.last {
                let latency = now - lastKeystroke
                session.interKeyLatencies.append(latency)
            }
            session.keystrokes.append(now)
            session.previousLength = currentLength
            currentTypingSession = session
        } else if currentLength < session.previousLength {
            let deleted = session.previousLength - currentLength
            session.backspaceCount += deleted
            session.lastDeletionAmount = deleted  // So recordCut() can subtract this (cut shouldn't count as backspace)
            session.previousLength = currentLength
            currentTypingSession = session
        } else {
            session.previousLength = currentLength
            currentTypingSession = session
        }
    }
    
    /// Record a copy action (call from custom UITextView/UITextField that overrides copy).
    func recordCopy() {
        guard var session = currentTypingSession else { return }
        session.numberOfCopy += 1
        currentTypingSession = session
    }
    
    /// Record a paste action (call from custom UITextView/UITextField that overrides paste).
    func recordPaste() {
        guard var session = currentTypingSession else { return }
        session.numberOfPaste += 1
        currentTypingSession = session
    }
    
    /// Record a cut action (call from custom UITextView/UITextField that overrides cut).
    /// Also undoes the last backspace count for the removed length so cut is not counted as backspace.
    func recordCut() {
        guard var session = currentTypingSession else { return }
        session.numberOfCut += 1
        // That length decrease was a cut, not backspace — don't count it toward correction_rate
        session.backspaceCount = max(0, session.backspaceCount - session.lastDeletionAmount)
        session.lastDeletionAmount = 0
        currentTypingSession = session
    }
    
    private func calculateBurstiness(_ latencies: [Int64]) -> Double {
        guard latencies.count > 1 else {
            return 0.0
        }
        
        let doubles = latencies.map { Double($0) }
        let mean = doubles.reduce(0, +) / Double(doubles.count)
        let variance = doubles.map { pow($0 - mean, 2) }.reduce(0, +) / Double(doubles.count)
        let stdDev = sqrt(variance)
        
        return mean > 0 ? stdDev / mean : 0.0  // Coefficient of variation
    }
    
    private func calculateCadenceStability(_ latencies: [Int64]) -> Double {
        guard latencies.count > 1 else {
            return 1.0  // Perfect stability for single keystroke
        }
        
        let burstiness = calculateBurstiness(latencies)
        // Stability is inverse of burstiness, normalized to 0-1
        return 1.0 / (1.0 + burstiness)
    }
    
    /// Standard deviation of inter-tap intervals in ms (typing_cadence_variability), aligned with Kotlin/Dart.
    private func calculateCadenceVariability(_ latencies: [Int64]) -> Double {
        guard latencies.count > 1 else {
            return 0.0
        }
        let doubles = latencies.map { Double($0) }
        let mean = doubles.reduce(0, +) / Double(doubles.count)
        let variance = doubles.map { pow($0 - mean, 2) }.reduce(0, +) / Double(doubles.count)
        return sqrt(variance)
    }

    /// Get current typing statistics.
    func getCurrentStats() -> (cadence: Double?, interKeyLatency: Double?, burstLength: Int?) {
        guard let session = currentTypingSession, !session.keystrokes.isEmpty else {
            return (nil, nil, nil)
        }
        
        let durationSeconds = Date().timeIntervalSince(session.startTime)
        let cadence = durationSeconds > 0 ? Double(session.keystrokes.count) / durationSeconds : nil
        let latency = session.interKeyLatencies.last.map { Double($0) }
        let burst = session.keystrokes.count
        
        return (cadence, latency, burst)
    }

    private func currentTimestampMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}
