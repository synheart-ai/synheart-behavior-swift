import UIKit
import SynheartBehavior

class MainViewController: UIViewController {
    var behavior: SynheartBehavior?
    var sessionId: String?
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let statusCard = UIView()
    private let statusTitleLabel = UILabel()
    private let statusValueLabel = UILabel()
    private let sessionStatusLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let endButton = UIButton(type: .system)
    private let refreshStatsButton = UIButton(type: .system)
    private let notificationPermissionButton = UIButton(type: .system)
    private let callPermissionButton = UIButton(type: .system)
    private let statsCard = UIView()
    private let statsTitleLabel = UILabel()
    private let statsContentStack = UIStackView()
    private let typingTestCard = UIView()
    private let typingTestTitleLabel = UILabel()
    private let textField = BehaviorTrackingTextField()
    private let typingTestHintLabel = UILabel()
    private let testItemsStack = UIStackView()
    
    private var eventCount = 0
    private var isSessionActive = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismissal()
        
        // Update event count when events are received
        behavior?.setEventHandler { [weak self] event in
            DispatchQueue.main.async {
                self?.eventCount += 1
            }
        }
        // Wire text field so copy/paste/cut are reported to the SDK (clipboard_activity_rate)
        textField.behavior = behavior
    }
    
    private func setupKeyboardDismissal() {
        // Add tap gesture to dismiss keyboard when tapping outside text field
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false  // Allow other gestures (buttons, etc.) to work normally
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func setupUI() {
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        title = "Synheart Behavior Demo"
        
        // Setup scroll view
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Status Card
        setupStatusCard()
        
        // Buttons - Start and End side by side
        setupButtons()
        
        // Refresh Stats Button
        setupRefreshStatsButton()
        
        // Permission Buttons
        setupPermissionButtons()
        
        // Stats Card (only shown when session is not active)
        setupStatsCard()
        
        // Typing Test Card
        setupTypingTestCard()
        
        // Test Items List
        setupTestItemsList()
        
        // Layout all components
        layoutComponents()
        
        updateUI()
    }
    
    private func setupStatusCard() {
        if #available(iOS 13.0, *) {
            statusCard.backgroundColor = .secondarySystemBackground
        } else {
            statusCard.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        }
        statusCard.layer.cornerRadius = 8
        statusCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusCard)
        
        statusTitleLabel.text = "SDK Status"
        statusTitleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        statusTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(statusTitleLabel)
        
        statusValueLabel.font = .systemFont(ofSize: 16)
        statusValueLabel.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(statusValueLabel)
        
        sessionStatusLabel.font = .systemFont(ofSize: 16)
        sessionStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(sessionStatusLabel)
        
        NSLayoutConstraint.activate([
            statusTitleLabel.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 16),
            statusTitleLabel.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 16),
            statusTitleLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -16),
            
            statusValueLabel.topAnchor.constraint(equalTo: statusTitleLabel.bottomAnchor, constant: 8),
            statusValueLabel.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 16),
            statusValueLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -16),
            
            sessionStatusLabel.topAnchor.constraint(equalTo: statusValueLabel.bottomAnchor, constant: 8),
            sessionStatusLabel.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 16),
            sessionStatusLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -16),
            sessionStatusLabel.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupButtons() {
        startButton.setTitle("Start Session", for: .normal)
        startButton.addTarget(self, action: #selector(startSession), for: .touchUpInside)
        startButton.backgroundColor = .systemBlue
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 8
        startButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(startButton)
        
        endButton.setTitle("End Session", for: .normal)
        endButton.addTarget(self, action: #selector(endSession), for: .touchUpInside)
        endButton.backgroundColor = .systemRed
        endButton.setTitleColor(.white, for: .normal)
        endButton.layer.cornerRadius = 8
        endButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(endButton)
    }
    
    private func setupRefreshStatsButton() {
        refreshStatsButton.setTitle("Refresh Stats", for: .normal)
        refreshStatsButton.addTarget(self, action: #selector(getStats), for: .touchUpInside)
        refreshStatsButton.backgroundColor = .systemBlue
        refreshStatsButton.setTitleColor(.white, for: .normal)
        refreshStatsButton.layer.cornerRadius = 8
        refreshStatsButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(refreshStatsButton)
    }
    
    private func setupPermissionButtons() {
        notificationPermissionButton.setTitle("Request Notification Permission", for: .normal)
        notificationPermissionButton.addTarget(self, action: #selector(requestNotificationPermission), for: .touchUpInside)
        notificationPermissionButton.backgroundColor = .systemBlue
        notificationPermissionButton.setTitleColor(.white, for: .normal)
        notificationPermissionButton.layer.cornerRadius = 8
        notificationPermissionButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(notificationPermissionButton)
        
        callPermissionButton.setTitle("Request Call Permission", for: .normal)
        callPermissionButton.addTarget(self, action: #selector(requestCallPermission), for: .touchUpInside)
        callPermissionButton.backgroundColor = .systemBlue
        callPermissionButton.setTitleColor(.white, for: .normal)
        callPermissionButton.layer.cornerRadius = 8
        callPermissionButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(callPermissionButton)
    }
    
    private func setupStatsCard() {
        if #available(iOS 13.0, *) {
            statsCard.backgroundColor = .secondarySystemBackground
        } else {
            statsCard.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        }
        statsCard.layer.cornerRadius = 8
        statsCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statsCard)
        
        statsTitleLabel.text = "Current Stats"
        statsTitleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        statsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        statsCard.addSubview(statsTitleLabel)
        
        statsContentStack.axis = .vertical
        statsContentStack.spacing = 8
        statsContentStack.alignment = .leading
        statsContentStack.translatesAutoresizingMaskIntoConstraints = false
        statsCard.addSubview(statsContentStack)
        
        NSLayoutConstraint.activate([
            statsTitleLabel.topAnchor.constraint(equalTo: statsCard.topAnchor, constant: 16),
            statsTitleLabel.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: 16),
            statsTitleLabel.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: -16),
            
            statsContentStack.topAnchor.constraint(equalTo: statsTitleLabel.bottomAnchor, constant: 8),
            statsContentStack.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: 16),
            statsContentStack.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: -16),
            statsContentStack.bottomAnchor.constraint(equalTo: statsCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupTypingTestCard() {
        if #available(iOS 13.0, *) {
            typingTestCard.backgroundColor = .secondarySystemBackground
        } else {
            typingTestCard.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        }
        typingTestCard.layer.cornerRadius = 8
        typingTestCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(typingTestCard)
        
        typingTestTitleLabel.text = "Typing Test"
        typingTestTitleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        typingTestTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        typingTestCard.addSubview(typingTestTitleLabel)
        
        textField.placeholder = "Type here to test typing events..."
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        typingTestCard.addSubview(textField)
        
        typingTestHintLabel.text = "Type here to test typing events. Use Copy/Paste/Cut (long-press or Edit menu) to test clipboard counts."
        typingTestHintLabel.font = .systemFont(ofSize: 12)
        if #available(iOS 13.0, *) {
            typingTestHintLabel.textColor = .secondaryLabel
        } else {
            typingTestHintLabel.textColor = .gray
        }
        typingTestHintLabel.numberOfLines = 0
        typingTestHintLabel.translatesAutoresizingMaskIntoConstraints = false
        typingTestCard.addSubview(typingTestHintLabel)
        
        NSLayoutConstraint.activate([
            typingTestTitleLabel.topAnchor.constraint(equalTo: typingTestCard.topAnchor, constant: 16),
            typingTestTitleLabel.leadingAnchor.constraint(equalTo: typingTestCard.leadingAnchor, constant: 16),
            typingTestTitleLabel.trailingAnchor.constraint(equalTo: typingTestCard.trailingAnchor, constant: -16),
            
            textField.topAnchor.constraint(equalTo: typingTestTitleLabel.bottomAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: typingTestCard.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: typingTestCard.trailingAnchor, constant: -16),
            textField.heightAnchor.constraint(equalToConstant: 100),
            
            typingTestHintLabel.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 8),
            typingTestHintLabel.leadingAnchor.constraint(equalTo: typingTestCard.leadingAnchor, constant: 16),
            typingTestHintLabel.trailingAnchor.constraint(equalTo: typingTestCard.trailingAnchor, constant: -16),
            typingTestHintLabel.bottomAnchor.constraint(equalTo: typingTestCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupTestItemsList() {
        testItemsStack.axis = .vertical
        testItemsStack.spacing = 8
        testItemsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(testItemsStack)
        
        for i in 0..<10 {
            let itemCard = UIView()
            if #available(iOS 13.0, *) {
                itemCard.backgroundColor = .secondarySystemBackground
            } else {
                itemCard.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
            }
            itemCard.layer.cornerRadius = 8
            itemCard.translatesAutoresizingMaskIntoConstraints = false
            
            let itemLabel = UILabel()
            itemLabel.text = "Item \(i)"
            itemLabel.font = .systemFont(ofSize: 16)
            itemLabel.translatesAutoresizingMaskIntoConstraints = false
            itemCard.addSubview(itemLabel)
            
            NSLayoutConstraint.activate([
                itemLabel.topAnchor.constraint(equalTo: itemCard.topAnchor, constant: 16),
                itemLabel.leadingAnchor.constraint(equalTo: itemCard.leadingAnchor, constant: 16),
                itemLabel.trailingAnchor.constraint(equalTo: itemCard.trailingAnchor, constant: -16),
                itemLabel.bottomAnchor.constraint(equalTo: itemCard.bottomAnchor, constant: -16),
                itemCard.heightAnchor.constraint(equalToConstant: 60)
            ])
            
            testItemsStack.addArrangedSubview(itemCard)
        }
        
        let hintLabel = UILabel()
        hintLabel.text = "Scroll down to see more content"
        hintLabel.font = .systemFont(ofSize: 14)
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        testItemsStack.addArrangedSubview(hintLabel)
    }
    
    private func layoutComponents() {
        NSLayoutConstraint.activate([
            // Status Card
            statusCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            statusCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Buttons side by side
            startButton.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: 16),
            startButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            startButton.trailingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: -4),
            startButton.heightAnchor.constraint(equalToConstant: 44),
            
            endButton.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: 16),
            endButton.leadingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: 4),
            endButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            endButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Refresh Stats
            refreshStatsButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 8),
            refreshStatsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            refreshStatsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            refreshStatsButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Notification Permission
            notificationPermissionButton.topAnchor.constraint(equalTo: refreshStatsButton.bottomAnchor, constant: 8),
            notificationPermissionButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            notificationPermissionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            notificationPermissionButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Call Permission
            callPermissionButton.topAnchor.constraint(equalTo: notificationPermissionButton.bottomAnchor, constant: 8),
            callPermissionButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            callPermissionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            callPermissionButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Stats Card (conditionally shown)
            statsCard.topAnchor.constraint(equalTo: callPermissionButton.bottomAnchor, constant: 16),
            statsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Typing Test Card
            typingTestCard.topAnchor.constraint(equalTo: statsCard.bottomAnchor, constant: 16),
            typingTestCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            typingTestCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Test Items
            testItemsStack.topAnchor.constraint(equalTo: typingTestCard.bottomAnchor, constant: 16),
            testItemsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            testItemsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            testItemsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func updateUI() {
        let fluxStatus = behavior?.isFluxAvailable ?? false
        let isInitialized = behavior != nil
        
        // Status Card
        if isInitialized {
            statusValueLabel.text = "✓ Initialized"
            statusValueLabel.textColor = .systemGreen
        } else {
            statusValueLabel.text = "✗ Not Initialized"
            statusValueLabel.textColor = .systemRed
        }
        
        if isSessionActive {
            sessionStatusLabel.text = "▶ Session Active: \(sessionId ?? "Unknown")"
            sessionStatusLabel.textColor = .systemBlue
            sessionStatusLabel.isHidden = false
        } else {
            sessionStatusLabel.isHidden = true
        }
        
        // Buttons
        startButton.isEnabled = isInitialized && !isSessionActive
        startButton.alpha = startButton.isEnabled ? 1.0 : 0.5
        
        endButton.isEnabled = isInitialized && isSessionActive
        endButton.alpha = endButton.isEnabled ? 1.0 : 0.5
        if !endButton.isEnabled {
            endButton.setTitle("End Session (Disabled)", for: .normal)
        } else {
            endButton.setTitle("End Session", for: .normal)
        }
        
        // Stats Card visibility
        statsCard.isHidden = isSessionActive
        
        // Permission buttons
        notificationPermissionButton.isEnabled = isInitialized
        notificationPermissionButton.alpha = notificationPermissionButton.isEnabled ? 1.0 : 0.5
        
        callPermissionButton.isEnabled = isInitialized
        callPermissionButton.alpha = callPermissionButton.isEnabled ? 1.0 : 0.5
    }
    
    @objc private func startSession() {
        guard let behavior = behavior else {
            statusValueLabel.text = "✗ SDK not initialized"
            statusValueLabel.textColor = .systemRed
            return
        }
        
        do {
            if let existingSessionId = behavior.getCurrentSessionId() {
                do {
                    _ = try behavior.endSession(sessionId: existingSessionId)
                } catch {
                    // Failed to end existing session
                }
            }
            
            sessionId = try behavior.startSession()
            isSessionActive = true
            eventCount = 0
            updateUI()
        } catch {
            statusValueLabel.text = "✗ Error - \(error.localizedDescription)"
            statusValueLabel.textColor = .systemRed
        }
    }
    
    @objc private func endSession() {
        guard let behavior = behavior else {
            statusValueLabel.text = "✗ SDK not initialized"
            statusValueLabel.textColor = .systemRed
            return
        }
        
        guard let sessionId = behavior.getCurrentSessionId() else {
            statusValueLabel.text = "⚠ No active session"
            statusValueLabel.textColor = .systemOrange
            return
        }
        
        self.sessionId = sessionId
        
        do {
            var hsiPayload: HsiBehaviorPayload? = nil
            var summary: BehaviorSessionSummary? = nil
            
            let hsiResult = try behavior.endSessionWithHsi(sessionId: sessionId)
            hsiPayload = hsiResult.payload
            let rawHsiJson = hsiResult.rawJson
            
            if let window = hsiResult.payload.behaviorWindows.first {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let startTime = formatter.date(from: window.startTimeUtc) ?? Date()
                let endTime = formatter.date(from: window.endTimeUtc) ?? Date()
                // Use SessionManager's app switch count (source of truth) instead of Flux's count
                let appSwitchCount = behavior.getAppSwitchCount()
                summary = BehaviorSessionSummary(
                    sessionId: window.sessionId,
                    startTimestamp: Int64(startTime.timeIntervalSince1970 * 1000),
                    endTimestamp: Int64(endTime.timeIntervalSince1970 * 1000),
                    duration: Int64(window.durationSec * 1000),
                    eventCount: window.eventSummary.totalEvents,
                    averageTypingCadence: nil,
                    averageScrollVelocity: nil,
                    appSwitchCount: appSwitchCount,
                    stabilityIndex: nil,
                    fragmentationIndex: nil
                )
            }
            
            guard let finalSummary = summary else {
                statusValueLabel.text = "✗ Failed to get session summary"
                statusValueLabel.textColor = .systemRed
                return
            }
            
            // Get events from the session before ending
            let sessionEvents = behavior.getSessionEvents()
            
            isSessionActive = false
            updateUI()
            
            let resultsVC = SessionResultsViewController(
                summary: finalSummary,
                hsiPayload: hsiPayload,
                behavior: behavior,
                rawHsiJson: rawHsiJson,
                events: sessionEvents
            )
            navigationController?.pushViewController(resultsVC, animated: true)
            
            self.sessionId = nil
        } catch {
            let errorMessage: String
            if let behaviorError = error as? BehaviorError {
                switch behaviorError {
                case .notInitialized:
                    errorMessage = "SDK not initialized"
                case .invalidConfiguration:
                    errorMessage = "Invalid configuration"
                case .sessionNotFound:
                    errorMessage = "Session not found"
                case .fluxNotAvailable:
                    errorMessage = "Flux is required but not available"
                case .fluxProcessingFailed:
                    errorMessage = "Flux processing failed"
                }
            } else {
                errorMessage = "\(error)"
            }
            statusValueLabel.text = "✗ Error - \(errorMessage)"
            statusValueLabel.textColor = .systemRed
        }
    }
    
    @objc private func getStats() {
        do {
            let stats = try behavior?.getCurrentStats()
            
            // Clear existing stats
            statsContentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            if let stats = stats {
                if let scrollVelocity = stats.scrollVelocity {
                    statsContentStack.addArrangedSubview(createStatRow(label: "Scroll Velocity", value: String(format: "%.2f", scrollVelocity)))
                }
                statsContentStack.addArrangedSubview(createStatRow(label: "App Switches/min", value: "\(stats.appSwitchesPerMinute)"))
                if let stabilityIndex = stats.stabilityIndex {
                    statsContentStack.addArrangedSubview(createStatRow(label: "Stability Index", value: String(format: "%.2f", stabilityIndex)))
                }
            }
        } catch {
            // Error getting stats
        }
    }
    
    private func createStatRow(label: String, value: String) -> UIView {
        let row = UIView()
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 14)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(labelView)
        
        let valueView = UILabel()
        valueView.text = value
        valueView.font = .systemFont(ofSize: 14, weight: .bold)
        valueView.textAlignment = .right
        valueView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(valueView)
        
        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            labelView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            labelView.trailingAnchor.constraint(lessThanOrEqualTo: valueView.leadingAnchor, constant: -16),
            valueView.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            valueView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            row.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return row
    }
    
    @objc private func requestNotificationPermission() {
        // Notification permission request not implemented
    }
    
    @objc private func requestCallPermission() {
        // Call permission request not implemented
    }
}
