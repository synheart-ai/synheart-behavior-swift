import UIKit
import SynheartBehavior

class SessionResultsViewController: UIViewController {
    let summary: BehaviorSessionSummary
    let hsiPayload: HsiBehaviorPayload?
    let behavior: SynheartBehavior?
    let rawHsiJson: String? // Store raw HSI JSON for extracting typing summary
    let events: [BehaviorEvent] // Store events for timeline display
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Time range selection
    private var selectedStartTime: Date?
    private var selectedEndTime: Date?
    
    init(summary: BehaviorSessionSummary, hsiPayload: HsiBehaviorPayload? = nil, behavior: SynheartBehavior? = nil, rawHsiJson: String? = nil, events: [BehaviorEvent] = []) {
        self.summary = summary
        self.hsiPayload = hsiPayload
        self.behavior = behavior
        self.rawHsiJson = rawHsiJson
        self.events = events
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize time range to session start/end
        let sessionStartMs = summary.startTimestamp
        let sessionEndMs = summary.endTimestamp
        selectedStartTime = Date(timeIntervalSince1970: Double(sessionStartMs) / 1000.0)
        selectedEndTime = Date(timeIntervalSince1970: Double(sessionEndMs) / 1000.0)
        
        setupUI()
        populateContent()
    }
    
    private func setupUI() {
        title = "Session Results"
        
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        
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
    }
    
    private func populateContent() {
        // Clear existing subviews
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        var lastView: UIView = contentView
        var topSpacing: CGFloat = 16
        
        // Time Range Selection Card
        let timeRangeCard = createCard(title: "Time Range Selection", content: createTimeRangeContent())
        contentView.addSubview(timeRangeCard)
        timeRangeCard.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            timeRangeCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: topSpacing),
            timeRangeCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            timeRangeCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        lastView = timeRangeCard
        topSpacing = 16
        
        // Session Information Card
        let sessionCard = createCard(title: "Session Information", content: createSessionInfoContent())
        contentView.addSubview(sessionCard)
        sessionCard.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sessionCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
            sessionCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sessionCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        lastView = sessionCard
        topSpacing = 16
        
        // Motion Data Debug Card
        let motionDebugCard = createCard(title: "Motion Data Debug", content: createMotionDataDebugContent(), backgroundColor: UIColor.orange.withAlphaComponent(0.1))
        contentView.addSubview(motionDebugCard)
        motionDebugCard.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            motionDebugCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
            motionDebugCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            motionDebugCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        lastView = motionDebugCard
        topSpacing = 16
        
        // Motion State Card (placeholder - data not available yet)
        let motionStateCard = createCard(title: "Motion State", content: createMotionStateContent())
        contentView.addSubview(motionStateCard)
        motionStateCard.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            motionStateCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
            motionStateCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            motionStateCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        lastView = motionStateCard
        topSpacing = 16
        
        // Motion Data (ML Features) Card (placeholder - data not available yet)
        let motionDataCard = createCard(title: "Motion Data (ML Features)", content: createMotionDataContent())
        contentView.addSubview(motionDataCard)
        motionDataCard.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            motionDataCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
            motionDataCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            motionDataCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        lastView = motionDataCard
        topSpacing = 16
        
        // Device Context Card
        let deviceContextCard = createCard(title: "Device Context", content: createDeviceContextContent())
        contentView.addSubview(deviceContextCard)
        deviceContextCard.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            deviceContextCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
            deviceContextCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            deviceContextCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        lastView = deviceContextCard
        topSpacing = 16
        
        // Activity Summary Card
        let activityCard = createCard(title: "Activity Summary", content: createActivitySummaryContent())
        contentView.addSubview(activityCard)
        activityCard.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
            activityCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            activityCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        lastView = activityCard
        
        // Behavioral Metrics Card (if HSI available)
        if let hsi = hsiPayload, let window = hsi.behaviorWindows.first {
            let metricsCard = createCard(title: "Behavior Metrics", content: createBehavioralMetricsContent(window: window))
            contentView.addSubview(metricsCard)
            metricsCard.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                metricsCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
                metricsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                metricsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
            ])
            lastView = metricsCard
        }
        
        // Notification Summary Card (if HSI available)
        if let hsi = hsiPayload, let window = hsi.behaviorWindows.first {
            let notificationCard = createCard(title: "Notification Summary", content: createNotificationSummaryContent(window: window))
            contentView.addSubview(notificationCard)
            notificationCard.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                notificationCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
                notificationCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                notificationCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
            ])
            lastView = notificationCard
        }
        
        // Typing Session Summary Card (if available in raw JSON)
        if let rawJson = rawHsiJson {
            if let typingSummary = extractTypingSessionSummary(from: rawJson) {
                let typingCard = createCard(title: "Typing Session Summary", content: createTypingSessionSummaryContent(typingSummary: typingSummary))
                contentView.addSubview(typingCard)
                typingCard.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    typingCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
                    typingCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                    typingCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
                ])
                lastView = typingCard
                topSpacing = 16
            } else {
                // Show a placeholder card to indicate typing summary is not available
                let typingCard = createCard(title: "Typing Session Summary", content: createTypingSummaryPlaceholder())
                contentView.addSubview(typingCard)
                typingCard.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    typingCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
                    typingCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                    typingCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
                ])
                lastView = typingCard
                topSpacing = 16
            }
        }
        
        // System State Card
        let systemStateCard = createCard(title: "System State", content: createSystemStateContent())
        contentView.addSubview(systemStateCard)
        systemStateCard.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            systemStateCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
            systemStateCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            systemStateCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        lastView = systemStateCard
        topSpacing = 16
        
        // Events Timeline Card
        let eventsTimelineCard = createCard(title: "Events Timeline", content: createEventsTimelineContent())
        contentView.addSubview(eventsTimelineCard)
        eventsTimelineCard.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            eventsTimelineCard.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: topSpacing),
            eventsTimelineCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            eventsTimelineCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        lastView = eventsTimelineCard
        
        // Set bottom constraint
        NSLayoutConstraint.activate([
            lastView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func createCard(title: String, content: UIView, backgroundColor: UIColor? = nil) -> UIView {
        let card = UIView()
        if let bgColor = backgroundColor {
            card.backgroundColor = bgColor
        } else if #available(iOS 13.0, *) {
            card.backgroundColor = .secondarySystemBackground
        } else {
            card.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        }
        card.layer.cornerRadius = 8
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            
            content.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
    
    private func createSessionInfoContent() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        stack.addArrangedSubview(createInfoRow(label: "Session ID", value: summary.sessionId))
        stack.addArrangedSubview(createInfoRow(label: "Start Time", value: formatTimestamp(summary.startTimestamp)))
        stack.addArrangedSubview(createInfoRow(label: "End Time", value: formatTimestamp(summary.endTimestamp)))
        stack.addArrangedSubview(createInfoRow(label: "Duration", value: formatDuration(summary.duration)))
        stack.addArrangedSubview(createInfoRow(label: "Micro Session", value: "No")) // Not available in Swift SDK yet
        stack.addArrangedSubview(createInfoRow(label: "OS", value: "iOS"))
        // Extract session spacing from raw HSI JSON meta
        let sessionSpacing = extractSessionSpacing(from: rawHsiJson)
        if let spacing = sessionSpacing {
            stack.addArrangedSubview(createInfoRow(label: "Session Spacing", value: formatMs(spacing)))
        } else {
            stack.addArrangedSubview(createInfoRow(label: "Session Spacing", value: "N/A"))
        }
        // Count events that would be shown in timeline (excluding app_switch and unknown) for consistency
        let timelineEventCount = events.filter { event in
            let fluxType = mapEventTypeToFluxType(event.type)
            return fluxType != "unknown" && fluxType != "app_switch"
        }.count
        // Use timeline count if available, otherwise use summary count
        let displayEventCount = timelineEventCount > 0 ? timelineEventCount : summary.eventCount
        stack.addArrangedSubview(createInfoRow(label: "Total Events", value: "\(displayEventCount)"))
        
        return stack
    }
    
    private func createActivitySummaryContent() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        // Count events that would be shown in timeline (excluding app_switch and unknown)
        let timelineEventCount = events.filter { event in
            let fluxType = mapEventTypeToFluxType(event.type)
            return fluxType != "unknown" && fluxType != "app_switch"
        }.count
        
        if let hsi = hsiPayload, let window = hsi.behaviorWindows.first {
            // Always use SessionManager's app switch count (it's the source of truth)
            // Flux's count might be 0 if app_switch events aren't being counted in Flux's meta
            let appSwitchCount = summary.appSwitchCount
            // Show the actual timeline event count (events that are displayed, excluding app_switch and unknown)
            stack.addArrangedSubview(createInfoRow(label: "Total Events", value: "\(timelineEventCount)"))
            stack.addArrangedSubview(createInfoRow(label: "App Switch Count", value: "\(appSwitchCount)"))
        } else {
            // Fallback: use timeline count or summary count
            let displayCount = timelineEventCount > 0 ? timelineEventCount : summary.eventCount
            stack.addArrangedSubview(createInfoRow(label: "Total Events", value: "\(displayCount)"))
            stack.addArrangedSubview(createInfoRow(label: "App Switch Count", value: "\(summary.appSwitchCount)"))
        }
        
        return stack
    }
    
    private func createBehavioralMetricsContent(window: HsiBehaviorWindow) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        let metrics = window.behavior
        stack.addArrangedSubview(createInfoRow(label: "Interaction Intensity", value: String(format: "%.3f", metrics.interactionIntensity)))
        stack.addArrangedSubview(createInfoRow(label: "Task Switch Rate", value: String(format: "%.3f", metrics.taskSwitchRate)))
        stack.addArrangedSubview(createInfoRow(label: "Task Switch Cost", value: formatMs(Int(metrics.taskSwitchRate * 1000)))) // Approximate
        stack.addArrangedSubview(createInfoRow(label: "Idle Time Ratio", value: String(format: "%.3f", metrics.idleRatio)))
        stack.addArrangedSubview(createInfoRow(label: "Active Time Ratio", value: String(format: "%.3f", 1.0 - metrics.idleRatio)))
        stack.addArrangedSubview(createInfoRow(label: "Notification Load", value: String(format: "%.3f", metrics.notificationLoad)))
        stack.addArrangedSubview(createInfoRow(label: "Burstiness", value: String(format: "%.3f", metrics.burstiness)))
        stack.addArrangedSubview(createInfoRow(label: "Distraction Score", value: String(format: "%.3f", metrics.distractionScore)))
        stack.addArrangedSubview(createInfoRow(label: "Focus Hint", value: String(format: "%.3f", metrics.focusHint)))
        stack.addArrangedSubview(createInfoRow(label: "Fragmented Idle Ratio", value: String(format: "%.3f", metrics.fragmentedIdleRatio)))
        stack.addArrangedSubview(createInfoRow(label: "Scroll Jitter Rate", value: String(format: "%.3f", metrics.scrollJitterRate)))
        stack.addArrangedSubview(createInfoRow(label: "Deep Focus Blocks", value: "\(metrics.deepFocusBlocks)"))
        
        if let baseline = window.baseline {
            stack.addArrangedSubview(createSeparator())
            stack.addArrangedSubview(createInfoRow(label: "Baseline Distraction", value: baseline.distraction != nil ? String(format: "%.3f", baseline.distraction!) : "N/A"))
            stack.addArrangedSubview(createInfoRow(label: "Baseline Focus", value: baseline.focus != nil ? String(format: "%.3f", baseline.focus!) : "N/A"))
            stack.addArrangedSubview(createInfoRow(label: "Sessions in Baseline", value: "\(baseline.sessionsInBaseline)"))
            if let deviation = baseline.distractionDeviationPct {
                stack.addArrangedSubview(createInfoRow(label: "Distraction Deviation", value: String(format: "%.1f%%", deviation)))
            }
        }
        
        return stack
    }
    
    private func createNotificationSummaryContent(window: HsiBehaviorWindow) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        // Extract notification summary from raw HSI JSON meta
        let notificationSummary = extractNotificationSummary(from: rawHsiJson)
        
        stack.addArrangedSubview(createInfoRow(label: "Notification Count", value: "\(window.eventSummary.notifications)"))
        
        if let summary = notificationSummary {
            if let ignored = summary["notification_ignored"] as? Int {
                stack.addArrangedSubview(createInfoRow(label: "Notifications Ignored", value: "\(ignored)"))
            }
            if let ignoreRate = summary["notification_ignore_rate"] as? Double {
                stack.addArrangedSubview(createInfoRow(label: "Ignore Rate", value: String(format: "%.3f", ignoreRate)))
            }
            if let clusteringIndex = summary["notification_clustering_index"] as? Double {
                stack.addArrangedSubview(createInfoRow(label: "Clustering Index", value: String(format: "%.3f", clusteringIndex)))
            }
            if let callCount = summary["call_count"] as? Int {
                stack.addArrangedSubview(createInfoRow(label: "Call Count", value: "\(callCount)"))
            }
            if let callsIgnored = summary["call_ignored"] as? Int {
                stack.addArrangedSubview(createInfoRow(label: "Calls Ignored", value: "\(callsIgnored)"))
            }
        } else {
            // Fallback to event summary if meta not available
            stack.addArrangedSubview(createInfoRow(label: "Call Count", value: "\(window.eventSummary.tapEvents)")) // Approximate
        }
        
        return stack
    }
    
    private func createTypingSessionSummaryContent(typingSummary: [String: Any]) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        if let sessionCount = typingSummary["typing_session_count"] as? Int {
            stack.addArrangedSubview(createInfoRow(label: "Typing Sessions", value: "\(sessionCount)"))
        }
        if let avgKeystrokes = typingSummary["average_keystrokes_per_session"] as? Double {
            stack.addArrangedSubview(createInfoRow(label: "Avg Keystrokes/Session", value: String(format: "%.1f", avgKeystrokes)))
        }
        if let avgDuration = typingSummary["average_typing_session_duration"] as? Double {
            stack.addArrangedSubview(createInfoRow(label: "Avg Session Duration", value: formatMs(Int(avgDuration * 1000))))
        }
        if let avgSpeed = typingSummary["average_typing_speed"] as? Double {
            stack.addArrangedSubview(createInfoRow(label: "Avg Typing Speed", value: String(format: "%.2f taps/s", avgSpeed)))
        }
        if let avgGap = typingSummary["average_typing_gap"] as? Double {
            stack.addArrangedSubview(createInfoRow(label: "Avg Typing Gap", value: formatMs(Int(avgGap * 1000))))
        }
        if let avgInterTap = typingSummary["average_inter_tap_interval"] as? Double {
            stack.addArrangedSubview(createInfoRow(label: "Average Inter-tap Interval", value: formatMs(Int(avgInterTap))))
        }
        if let cadenceStability = typingSummary["typing_cadence_stability"] as? Double {
            stack.addArrangedSubview(createInfoRow(label: "Cadence Stability", value: String(format: "%.3f", cadenceStability)))
        }
        if let burstiness = typingSummary["burstiness_of_typing"] as? Double {
            stack.addArrangedSubview(createInfoRow(label: "Burstiness", value: String(format: "%.3f", burstiness)))
        }
        if let totalDuration = typingSummary["total_typing_duration"] as? Double {
            stack.addArrangedSubview(createInfoRow(label: "Total Typing Duration", value: formatMs(Int(totalDuration * 1000))))
        }
        if let activeRatio = typingSummary["active_typing_ratio"] as? Double {
            stack.addArrangedSubview(createInfoRow(label: "Active Typing Ratio", value: String(format: "%.3f", activeRatio)))
        }
        if let contribution = typingSummary["typing_contribution_to_interaction_intensity"] as? Double {
            stack.addArrangedSubview(createInfoRow(label: "Typing Contribution to Intensity", value: String(format: "%.3f", contribution)))
        }
        if let deepBlocks = typingSummary["deep_typing_blocks"] as? Int {
            stack.addArrangedSubview(createInfoRow(label: "Deep Typing Blocks", value: "\(deepBlocks)"))
        }
        if let fragmentation = typingSummary["typing_fragmentation"] as? Double {
            stack.addArrangedSubview(createInfoRow(label: "Typing Fragmentation", value: String(format: "%.3f", fragmentation)))
        }
        
        // Individual typing sessions (if available)
        if let individualSessions = typingSummary["individual_typing_sessions"] as? [[String: Any]], !individualSessions.isEmpty {
            stack.addArrangedSubview(createSeparator())
            let sessionsTitle = UILabel()
            sessionsTitle.text = "Individual Typing Sessions (\(individualSessions.count))"
            sessionsTitle.font = .systemFont(ofSize: 14, weight: .bold)
            stack.addArrangedSubview(sessionsTitle)
            
            for (index, session) in individualSessions.enumerated() {
                let sessionView = createIndividualTypingSessionView(session: session, index: index)
                stack.addArrangedSubview(sessionView)
            }
        }
        
        return stack
    }
    
    private func createIndividualTypingSessionView(session: [String: Any], index: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        let titleLabel = UILabel()
        let deepTyping = session["deep_typing"] as? Bool ?? false
        titleLabel.text = "Session \(index + 1)\(deepTyping ? " (Deep Typing)" : "")"
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        stack.addArrangedSubview(titleLabel)
        
        if let duration = session["duration"] as? Double,
           let tapCount = session["typing_tap_count"] as? Int {
            let subtitleLabel = UILabel()
            subtitleLabel.text = "\(formatMs(Int(duration * 1000))) • \(tapCount) keystrokes"
            subtitleLabel.font = .systemFont(ofSize: 12)
            if #available(iOS 13.0, *) {
                subtitleLabel.textColor = .secondaryLabel
            } else {
                subtitleLabel.textColor = .gray
            }
            stack.addArrangedSubview(subtitleLabel)
        }
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        
        return container
    }
    
    private func extractTypingSessionSummary(from hsiJson: String) -> [String: Any]? {
        guard let data = hsiJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Check if meta exists
        guard let meta = json["meta"] as? [String: Any] else {
            return nil
        }
        
        // Try to get typing_session_summary as nested object first (Kotlin SDK format)
        if let typingSummary = meta["typing_session_summary"] as? [String: Any] {
            return typingSummary
        }
        
        // Check windows array - typing summary might be in window meta
        if let windows = json["windows"] as? [[String: Any]] {
            for (index, window) in windows.enumerated() {
                // Check window meta
                if let windowMeta = window["meta"] as? [String: Any] {
                    if let typingSummary = windowMeta["typing_session_summary"] as? [String: Any] {
                        return typingSummary
                    }
                    
                    // Also check for typing fields directly in window meta
                    let typingSessionCount = windowMeta["typing_session_count"] as? Int ?? 0
                    if typingSessionCount > 0 || windowMeta["average_typing_speed"] != nil {
                        return extractTypingFieldsFromMeta(windowMeta)
                    }
                }
                
                // Check if typing summary is directly in window (not in meta)
                if let typingSummary = window["typing_session_summary"] as? [String: Any] {
                    return typingSummary
                }
            }
        }
        
        // Fallback: Extract typing fields directly from meta (Dart SDK iOS format)
        // Check if any typing-related fields exist in meta
        let typingSessionCount = meta["typing_session_count"] as? Int ?? 0
        let hasTypingSpeed = meta["average_typing_speed"] != nil
        let hasTypingMetrics = meta["typing_metrics"] != nil
        
        if typingSessionCount > 0 || hasTypingSpeed || hasTypingMetrics {
            return extractTypingFieldsFromMeta(meta)
        }
        
        return nil
    }
    
    private func extractTypingFieldsFromMeta(_ meta: [String: Any]) -> [String: Any] {
        var typingSummary: [String: Any] = [:]
        
        typingSummary["typing_session_count"] = meta["typing_session_count"] as? Int ?? 0
        typingSummary["average_keystrokes_per_session"] = meta["average_keystrokes_per_session"] as? Double ?? 0.0
        typingSummary["average_typing_session_duration"] = meta["average_typing_session_duration"] as? Double ?? 0.0
        typingSummary["average_typing_speed"] = meta["average_typing_speed"] as? Double ?? 0.0
        typingSummary["average_typing_gap"] = meta["average_typing_gap"] as? Double ?? 0.0
        typingSummary["average_inter_tap_interval"] = meta["average_inter_tap_interval"] as? Double ?? 0.0
        typingSummary["typing_cadence_stability"] = meta["typing_cadence_stability"] as? Double ?? 0.0
        typingSummary["burstiness_of_typing"] = meta["burstiness_of_typing"] as? Double ?? 0.0
        
        // Handle total_typing_duration (could be Int or Double)
        if let totalDurationInt = meta["total_typing_duration"] as? Int {
            typingSummary["total_typing_duration"] = Double(totalDurationInt)
        } else if let totalDurationDouble = meta["total_typing_duration"] as? Double {
            typingSummary["total_typing_duration"] = totalDurationDouble
        } else {
            typingSummary["total_typing_duration"] = 0.0
        }
        
        typingSummary["active_typing_ratio"] = meta["active_typing_ratio"] as? Double ?? 0.0
        typingSummary["typing_contribution_to_interaction_intensity"] = meta["typing_contribution_to_interaction_intensity"] as? Double ?? 0.0
        typingSummary["deep_typing_blocks"] = meta["deep_typing_blocks"] as? Int ?? 0
        typingSummary["typing_fragmentation"] = meta["typing_fragmentation"] as? Double ?? 0.0
        
        // Extract individual typing sessions from typing_metrics array
        if let typingMetrics = meta["typing_metrics"] as? [[String: Any]] {
            typingSummary["individual_typing_sessions"] = typingMetrics
        }
        
        return typingSummary
    }
    
    private func createTypingSummaryPlaceholder() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        let messageLabel = UILabel()
        messageLabel.text = "No typing events detected in this session.\n\nTo see typing metrics, type in the text field during a session."
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.numberOfLines = 0
        if #available(iOS 13.0, *) {
            messageLabel.textColor = .secondaryLabel
        } else {
            messageLabel.textColor = .gray
        }
        stack.addArrangedSubview(messageLabel)
        
        return stack
    }
    
    private func createInfoRow(label: String, value: String) -> UIView {
        let row = UIView()
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 14)
        if #available(iOS 13.0, *) {
            labelView.textColor = .secondaryLabel
        } else {
            labelView.textColor = .gray
        }
        labelView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(labelView)
        
        let valueView = UILabel()
        valueView.text = value
        valueView.font = .systemFont(ofSize: 14, weight: .medium)
        valueView.textAlignment = .right
        valueView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(valueView)
        
        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            labelView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            labelView.trailingAnchor.constraint(lessThanOrEqualTo: valueView.leadingAnchor, constant: -16),
            
            valueView.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            valueView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueView.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            row.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return row
    }
    
    private func createSeparator() -> UIView {
        let separator = UIView()
        if #available(iOS 13.0, *) {
            separator.backgroundColor = .separator
        } else {
            separator.backgroundColor = .lightGray
        }
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1),
            separator.widthAnchor.constraint(equalToConstant: 200)
        ])
        return separator
    }
    
    private func formatTimestamp(_ timestampMs: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestampMs) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ durationMs: Int64) -> String {
        let seconds = Double(durationMs) / 1000.0
        if seconds < 60 {
            return String(format: "%.1f sec", seconds)
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
    
    private func formatMs(_ milliseconds: Int) -> String {
        if milliseconds < 1000 {
            return "\(milliseconds)ms"
        } else if milliseconds < 60000 {
            return String(format: "%.1fs", Double(milliseconds) / 1000.0)
        } else {
            return String(format: "%.1fm", Double(milliseconds) / 60000.0)
        }
    }
    
    private func createMotionDataDebugContent() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        stack.addArrangedSubview(createInfoRow(label: "Motion Data Available", value: "No"))
        stack.addArrangedSubview(createInfoRow(label: "Motion Data Count", value: "0 windows"))
        stack.addArrangedSubview(createInfoRow(label: "Motion State Available", value: "No"))
        
        return stack
    }
    
    private func createMotionStateContent() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        stack.addArrangedSubview(createInfoRow(label: "Major State", value: "N/A"))
        stack.addArrangedSubview(createInfoRow(label: "Major State %", value: "N/A"))
        stack.addArrangedSubview(createInfoRow(label: "ML Model", value: "N/A"))
        stack.addArrangedSubview(createInfoRow(label: "Confidence", value: "N/A"))
        
        let noteLabel = UILabel()
        noteLabel.text = "Motion state data not yet available in Swift SDK"
        noteLabel.font = .systemFont(ofSize: 12)
        if #available(iOS 13.0, *) {
            noteLabel.textColor = .secondaryLabel
        } else {
            noteLabel.textColor = .gray
        }
        noteLabel.numberOfLines = 0
        stack.addArrangedSubview(noteLabel)
        
        return stack
    }
    
    private func createMotionDataContent() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        stack.addArrangedSubview(createInfoRow(label: "Data Points", value: "0 time windows"))
        stack.addArrangedSubview(createInfoRow(label: "Time Window", value: "5 seconds per window"))
        stack.addArrangedSubview(createInfoRow(label: "Features per Window", value: "561 ML features"))
        
        let noteLabel = UILabel()
        noteLabel.text = "Motion data (ML features) not yet available in Swift SDK"
        noteLabel.font = .systemFont(ofSize: 12)
        if #available(iOS 13.0, *) {
            noteLabel.textColor = .secondaryLabel
        } else {
            noteLabel.textColor = .gray
        }
        noteLabel.numberOfLines = 0
        stack.addArrangedSubview(noteLabel)
        
        return stack
    }
    
    private func createDeviceContextContent() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        // Extract device context from raw HSI JSON
        let deviceContext = extractDeviceContext(from: rawHsiJson)
        
        if let context = deviceContext {
            if let brightness = context["avg_screen_brightness"] as? Double {
                // Brightness may be 0.0 on simulators or if API is unavailable
                // On real devices, it should be between 0.0 and 1.0
                let brightnessValue = brightness > 0.0 ? String(format: "%.3f", brightness) : "N/A (requires physical device)"
                stack.addArrangedSubview(createInfoRow(label: "Avg Screen Brightness", value: brightnessValue))
            } else {
                stack.addArrangedSubview(createInfoRow(label: "Avg Screen Brightness", value: "N/A"))
            }
            
            if let orientation = context["start_orientation"] as? String {
                stack.addArrangedSubview(createInfoRow(label: "Start Orientation", value: orientation.capitalized))
            } else {
                stack.addArrangedSubview(createInfoRow(label: "Start Orientation", value: "N/A"))
            }
            
            if let changes = context["orientation_changes"] as? Int {
                stack.addArrangedSubview(createInfoRow(label: "Orientation Changes", value: "\(changes)"))
            } else {
                stack.addArrangedSubview(createInfoRow(label: "Orientation Changes", value: "N/A"))
            }
        } else {
            stack.addArrangedSubview(createInfoRow(label: "Avg Screen Brightness", value: "N/A"))
            stack.addArrangedSubview(createInfoRow(label: "Start Orientation", value: "N/A"))
            stack.addArrangedSubview(createInfoRow(label: "Orientation Changes", value: "N/A"))
            
            let noteLabel = UILabel()
            noteLabel.text = "Device context data not available in HSI JSON"
            noteLabel.font = .systemFont(ofSize: 12)
            if #available(iOS 13.0, *) {
                noteLabel.textColor = .secondaryLabel
            } else {
                noteLabel.textColor = .gray
            }
            noteLabel.numberOfLines = 0
            stack.addArrangedSubview(noteLabel)
        }
        
        return stack
    }
    
    private func extractDeviceContext(from hsiJson: String?) -> [String: Any]? {
        guard let json = hsiJson,
              let data = json.data(using: .utf8),
              let hsi = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let meta = hsi["meta"] as? [String: Any] else {
            return nil
        }
        
        var context: [String: Any] = [:]
        
        if let brightness = meta["avg_screen_brightness"] as? Double {
            context["avg_screen_brightness"] = brightness
        }
        if let orientation = meta["start_orientation"] as? String {
            context["start_orientation"] = orientation
        }
        if let changes = meta["orientation_changes"] as? Int {
            context["orientation_changes"] = changes
        }
        
        return context.isEmpty ? nil : context
    }
    
    private func createSystemStateContent() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        // Extract system state from raw HSI JSON
        let systemState = extractSystemState(from: rawHsiJson)
        
        if let state = systemState {
            if let internet = state["internet_state"] as? Bool {
                stack.addArrangedSubview(createInfoRow(label: "Internet", value: internet ? "Connected" : "Disconnected"))
            } else {
                stack.addArrangedSubview(createInfoRow(label: "Internet", value: "N/A"))
            }
            
            if let dnd = state["do_not_disturb"] as? Bool {
                stack.addArrangedSubview(createInfoRow(label: "Do Not Disturb", value: dnd ? "On" : "Off"))
            } else {
                stack.addArrangedSubview(createInfoRow(label: "Do Not Disturb", value: "N/A"))
            }
            
            if let charging = state["charging"] as? Bool {
                stack.addArrangedSubview(createInfoRow(label: "Charging", value: charging ? "Yes" : "No"))
            } else {
                stack.addArrangedSubview(createInfoRow(label: "Charging", value: "N/A"))
            }
        } else {
            stack.addArrangedSubview(createInfoRow(label: "Internet", value: "N/A"))
            stack.addArrangedSubview(createInfoRow(label: "Do Not Disturb", value: "N/A"))
            stack.addArrangedSubview(createInfoRow(label: "Charging", value: "N/A"))
            
            let noteLabel = UILabel()
            noteLabel.text = "System state data not available in HSI JSON"
            noteLabel.font = .systemFont(ofSize: 12)
            if #available(iOS 13.0, *) {
                noteLabel.textColor = .secondaryLabel
            } else {
                noteLabel.textColor = .gray
            }
            noteLabel.numberOfLines = 0
            stack.addArrangedSubview(noteLabel)
        }
        
        return stack
    }
    
    private func createEventsTimelineContent() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        
        // Use events passed to the view controller, or try to extract from raw HSI JSON as fallback
        var eventDicts: [[String: Any]] = []
        
        if !events.isEmpty {
            // Convert BehaviorEvent objects to dictionaries, filtering out unknown and app_switch event types
            eventDicts = events.compactMap { event in
                let fluxType = mapEventTypeToFluxType(event.type)
                
                // Filter out events that map to "unknown" or "app_switch" (app switches are counted separately, not shown in timeline)
                guard fluxType != "unknown" && fluxType != "app_switch" else {
                    return nil
                }
                
                var eventDict: [String: Any] = [
                    "timestamp": ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double(event.timestamp) / 1000.0)),
                    "event_type": fluxType,
                    "payload": event.payload
                ]
                
                // Add event-specific data based on type
                switch event.type {
                case .scrollVelocity, .scrollAcceleration, .scrollJitter, .scrollStop:
                    eventDict["scroll"] = [
                        "velocity": event.payload["velocity"] ?? 0.0,
                        "direction": event.payload["direction"] ?? "down",
                        "direction_reversal": event.payload["direction_reversal"] ?? false
                    ]
                case .tapRate, .longPressRate:
                    eventDict["tap"] = [
                        "tap_duration_ms": event.payload["duration_ms"] ?? event.payload["tap_duration_ms"] ?? 0,
                        "long_press": event.type == .longPressRate || (event.payload["long_press"] as? Bool ?? false)
                    ]
                case .dragVelocity:
                    eventDict["swipe"] = [
                        "velocity": event.payload["velocity"] ?? 0.0,
                        "direction": event.payload["direction"] ?? "unknown"
                    ]
                case .typingCadence, .typingBurst:
                    var typing: [String: Any] = [:]
                    if let tapCount = event.payload["typing_tap_count"] {
                        typing["typing_tap_count"] = tapCount
                    }
                    if let speed = event.payload["typing_speed"] {
                        typing["typing_speed"] = speed
                    }
                    if let meanInterval = event.payload["mean_inter_tap_interval_ms"] {
                        typing["mean_inter_tap_interval_ms"] = meanInterval
                    }
                    if let burstiness = event.payload["typing_burstiness"] {
                        typing["typing_burstiness"] = burstiness
                    }
                    if let startAt = event.payload["start_at"] {
                        typing["start_at"] = startAt
                    }
                    if let endAt = event.payload["end_at"] {
                        typing["end_at"] = endAt
                    }
                    if !typing.isEmpty {
                        eventDict["typing"] = typing
                    }
                // Note: appSwitch events are filtered out earlier (not shown in timeline, but still counted)
                default:
                    break
                }
                
                return eventDict
            }
        } else {
            // Fallback: try to extract from raw HSI JSON
            eventDicts = extractEvents(from: rawHsiJson)
        }
        
        // Filter out events with "unknown" or "app_switch" event_type
        // App switches are counted separately in the Activity Summary, not shown in timeline
        eventDicts = eventDicts.filter { event in
            let eventType = event["event_type"] as? String ?? ""
            return eventType != "unknown" && eventType != "app_switch"
        }
        
        // Sort events by timestamp
        let sortedEvents = eventDicts.sorted { (event1, event2) -> Bool in
            let time1 = event1["timestamp"] as? String ?? ""
            let time2 = event2["timestamp"] as? String ?? ""
            return time1 < time2
        }
        
        let countLabel = UILabel()
        countLabel.text = "Events Timeline (\(sortedEvents.count) events)"
        countLabel.font = .systemFont(ofSize: 16, weight: .medium)
        stack.addArrangedSubview(countLabel)
        
        if sortedEvents.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No events collected during this session."
            emptyLabel.textAlignment = .center
            emptyLabel.font = .systemFont(ofSize: 14)
            if #available(iOS 13.0, *) {
                emptyLabel.textColor = .secondaryLabel
            } else {
                emptyLabel.textColor = .gray
            }
            stack.addArrangedSubview(emptyLabel)
        } else {
            // Calculate session start time for relative time calculation
            let sessionStart = Date(timeIntervalSince1970: Double(summary.startTimestamp) / 1000.0)
            
            for (index, event) in sortedEvents.enumerated() {
                let eventView = createEventTimelineItem(event: event, index: index, sessionStart: sessionStart)
                stack.addArrangedSubview(eventView)
            }
        }
        
        return stack
    }
    
    private func mapEventTypeToFluxType(_ type: BehaviorEventType) -> String {
        switch type {
        case .scrollVelocity, .scrollAcceleration, .scrollJitter, .scrollStop:
            return "scroll"
        case .tapRate, .longPressRate:
            return "tap"
        case .dragVelocity:
            return "swipe"
        case .typingCadence, .typingBurst:
            return "typing"
        case .appSwitch:
            return "app_switch"
        default:
            return "unknown"
        }
    }
    
    // MARK: - Helper Functions for Data Extraction
    
    private func extractSessionSpacing(from hsiJson: String?) -> Int? {
        guard let json = hsiJson,
              let data = json.data(using: .utf8),
              let hsi = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let meta = hsi["meta"] as? [String: Any] else {
            return nil
        }
        
        // Handle both Int and Int64 (NSNumber) types
        if let spacing = meta["session_spacing"] as? Int {
            return spacing
        } else if let spacingNumber = meta["session_spacing"] as? NSNumber {
            return spacingNumber.intValue
        }
        
        return nil
    }
    
    private func extractNotificationSummary(from hsiJson: String?) -> [String: Any]? {
        guard let json = hsiJson,
              let data = json.data(using: .utf8),
              let hsi = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let meta = hsi["meta"] as? [String: Any] else {
            return nil
        }
        
        var summary: [String: Any] = [:]
        
        if let ignored = meta["notification_ignored"] as? Int {
            summary["notification_ignored"] = ignored
        }
        if let ignoreRate = meta["notification_ignore_rate"] as? Double {
            summary["notification_ignore_rate"] = ignoreRate
        }
        if let clusteringIndex = meta["notification_clustering_index"] as? Double {
            summary["notification_clustering_index"] = clusteringIndex
        }
        if let callCount = meta["call_count"] as? Int {
            summary["call_count"] = callCount
        }
        if let callsIgnored = meta["call_ignored"] as? Int {
            summary["call_ignored"] = callsIgnored
        }
        
        return summary.isEmpty ? nil : summary
    }
    
    private func extractSystemState(from hsiJson: String?) -> [String: Any]? {
        guard let json = hsiJson,
              let data = json.data(using: .utf8),
              let hsi = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let meta = hsi["meta"] as? [String: Any] else {
            return nil
        }
        
        var state: [String: Any] = [:]
        
        if let internet = meta["internet_state"] as? Bool {
            state["internet_state"] = internet
        }
        if let dnd = meta["do_not_disturb"] as? Bool {
            state["do_not_disturb"] = dnd
        }
        if let charging = meta["charging"] as? Bool {
            state["charging"] = charging
        }
        
        return state.isEmpty ? nil : state
    }
    
    private func extractEvents(from hsiJson: String?) -> [[String: Any]] {
        guard let json = hsiJson,
              let data = json.data(using: .utf8),
              let hsi = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        
        var allEvents: [[String: Any]] = []
        
        // Check if events are at the top level (from the original session JSON sent to Flux)
        if let events = hsi["events"] as? [[String: Any]] {
            allEvents.append(contentsOf: events)
        }
        
        // Also check windows (HSI format might have events in windows)
        if let windows = hsi["windows"] as? [String: Any] {
            for (_, windowValue) in windows {
                if let window = windowValue as? [String: Any],
                   let events = window["events"] as? [[String: Any]] {
                    allEvents.append(contentsOf: events)
                }
            }
        }
        
        // Check sources (events might be in source data)
        if let sources = hsi["sources"] as? [String: Any] {
            for (_, sourceValue) in sources {
                if let source = sourceValue as? [String: Any],
                   let events = source["events"] as? [[String: Any]] {
                    allEvents.append(contentsOf: events)
                }
            }
        }
        
        return allEvents
    }
    
    private func createEventTimelineItem(event: [String: Any], index: Int, sessionStart: Date) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 1
        if #available(iOS 13.0, *) {
            container.layer.borderColor = UIColor.separator.cgColor
        } else {
            container.layer.borderColor = UIColor.lightGray.cgColor
        }
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        // Event type and relative time
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        let eventTypeLabel = UILabel()
        let eventType = event["event_type"] as? String ?? "unknown"
        eventTypeLabel.text = eventType.uppercased()
        eventTypeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        eventTypeLabel.textColor = .white
        eventTypeLabel.backgroundColor = getEventTypeColor(eventType: eventType)
        eventTypeLabel.textAlignment = .center
        eventTypeLabel.layer.cornerRadius = 4
        eventTypeLabel.clipsToBounds = true
        eventTypeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            eventTypeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            eventTypeLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
        headerStack.addArrangedSubview(eventTypeLabel)
        
        // Calculate relative time
        if let timestampStr = event["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let eventTime = formatter.date(from: timestampStr) {
                let relativeTime = eventTime.timeIntervalSince(sessionStart)
            let relativeTimeLabel = UILabel()
            relativeTimeLabel.text = "+\(formatMs(Int(relativeTime * 1000)))"
            if #available(iOS 13.0, *) {
                relativeTimeLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
            } else {
                relativeTimeLabel.font = .systemFont(ofSize: 12, weight: .bold)
            }
                if #available(iOS 13.0, *) {
                    relativeTimeLabel.textColor = .secondaryLabel
                } else {
                    relativeTimeLabel.textColor = .gray
                }
                headerStack.addArrangedSubview(relativeTimeLabel)
            }
        }
        
        stack.addArrangedSubview(headerStack)
        
        // Timestamp
        if let timestampStr = event["timestamp"] as? String {
            let timeLabel = UILabel()
            timeLabel.text = "Time: \(formatTimestampString(timestampStr))"
            timeLabel.font = .systemFont(ofSize: 12)
            if #available(iOS 13.0, *) {
                timeLabel.textColor = .secondaryLabel
            } else {
                timeLabel.textColor = .gray
            }
            stack.addArrangedSubview(timeLabel)
        }
        
        // Metrics
        let metricsLabel = UILabel()
        metricsLabel.text = "Metrics:"
        metricsLabel.font = .systemFont(ofSize: 12, weight: .bold)
        stack.addArrangedSubview(metricsLabel)
        
        // Extract metrics from event (could be in tap, scroll, swipe, typing, interruption, etc.)
        var metrics: [String: Any] = [:]
        if let tap = event["tap"] as? [String: Any] {
            metrics.merge(tap) { (_, new) in new }
        }
        if let scroll = event["scroll"] as? [String: Any] {
            metrics.merge(scroll) { (_, new) in new }
        }
        if let swipe = event["swipe"] as? [String: Any] {
            metrics.merge(swipe) { (_, new) in new }
        }
        if let typing = event["typing"] as? [String: Any] {
            metrics.merge(typing) { (_, new) in new }
        }
        if let interruption = event["interruption"] as? [String: Any] {
            metrics.merge(interruption) { (_, new) in new }
        }
        
        for (key, value) in metrics.sorted(by: { $0.key < $1.key }) {
            let metricRow = UIStackView()
            metricRow.axis = .horizontal
            metricRow.spacing = 8
            metricRow.alignment = .leading
            
            let keyLabel = UILabel()
            keyLabel.text = "\(key):"
            if #available(iOS 13.0, *) {
                keyLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
            } else {
                keyLabel.font = UIFont(name: "Courier", size: 11) ?? .systemFont(ofSize: 11, weight: .medium)
            }
            keyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            
            let valueLabel = UILabel()
            valueLabel.text = "\(value)"
            if #available(iOS 13.0, *) {
                valueLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            } else {
                valueLabel.font = UIFont(name: "Courier", size: 11) ?? .systemFont(ofSize: 11)
            }
            valueLabel.numberOfLines = 2
            valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            metricRow.addArrangedSubview(keyLabel)
            metricRow.addArrangedSubview(valueLabel)
            stack.addArrangedSubview(metricRow)
        }
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            headerStack.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        
        return container
    }
    
    private func getEventTypeColor(eventType: String) -> UIColor {
        switch eventType.lowercased() {
        case "scroll":
            return .systemBlue
        case "tap":
            return .systemGreen
        case "swipe":
            return .systemOrange
        case "call":
            return .systemRed
        case "notification":
            return .systemPurple
        case "typing":
            return .systemTeal
        default:
            return .systemGray
        }
    }
    
    private func formatTimestampString(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return isoString
    }
    
    // MARK: - Time Range Selection
    
    private func createTimeRangeContent() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        
        // Start Time
        let startTimeStack = UIStackView()
        startTimeStack.axis = .vertical
        startTimeStack.spacing = 8
        
        let startTimeLabel = UILabel()
        startTimeLabel.text = "Start Time"
        startTimeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        startTimeStack.addArrangedSubview(startTimeLabel)
        
        let startTimeButton = UIButton(type: .system)
        startTimeButton.setTitle(formatDateTime(selectedStartTime ?? Date()), for: .normal)
        startTimeButton.addTarget(self, action: #selector(selectStartTime), for: .touchUpInside)
        startTimeButton.isUserInteractionEnabled = true
        if #available(iOS 13.0, *) {
            startTimeButton.backgroundColor = .secondarySystemBackground
        } else {
            startTimeButton.backgroundColor = .lightGray
        }
        startTimeButton.layer.cornerRadius = 8
        startTimeButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        startTimeStack.addArrangedSubview(startTimeButton)
        
        stack.addArrangedSubview(startTimeStack)
        
        // End Time
        let endTimeStack = UIStackView()
        endTimeStack.axis = .vertical
        endTimeStack.spacing = 8
        
        let endTimeLabel = UILabel()
        endTimeLabel.text = "End Time"
        endTimeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        endTimeStack.addArrangedSubview(endTimeLabel)
        
        let endTimeButton = UIButton(type: .system)
        endTimeButton.setTitle(formatDateTime(selectedEndTime ?? Date()), for: .normal)
        endTimeButton.addTarget(self, action: #selector(selectEndTime), for: .touchUpInside)
        endTimeButton.isUserInteractionEnabled = true
        if #available(iOS 13.0, *) {
            endTimeButton.backgroundColor = .secondarySystemBackground
        } else {
            endTimeButton.backgroundColor = .lightGray
        }
        endTimeButton.layer.cornerRadius = 8
        endTimeButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        endTimeStack.addArrangedSubview(endTimeButton)
        
        stack.addArrangedSubview(endTimeStack)
        
        // Calculate Button
        let calculateButton = UIButton(type: .system)
        calculateButton.setTitle("Calculate & Print Values", for: .normal)
        calculateButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        if #available(iOS 13.0, *) {
            calculateButton.backgroundColor = .systemBlue
            calculateButton.setTitleColor(.white, for: .normal)
        } else {
            calculateButton.backgroundColor = .blue
            calculateButton.setTitleColor(.white, for: .normal)
        }
        calculateButton.layer.cornerRadius = 8
        calculateButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        calculateButton.addTarget(self, action: #selector(calculateAndPrint), for: .touchUpInside)
        stack.addArrangedSubview(calculateButton)
        
        return stack
    }
    
    @objc private func selectStartTime() {
        presentDatePicker(
            title: "Select Start Time",
            initialDate: selectedStartTime ?? Date(),
            minimumDate: Date(timeIntervalSince1970: Double(summary.startTimestamp) / 1000.0),
            maximumDate: Date(timeIntervalSince1970: Double(summary.endTimestamp) / 1000.0),
            completion: { [weak self] date in
                self?.selectedStartTime = date
                self?.populateContent()
            }
        )
    }
    
    @objc private func selectEndTime() {
        presentDatePicker(
            title: "Select End Time",
            initialDate: selectedEndTime ?? Date(),
            minimumDate: Date(timeIntervalSince1970: Double(summary.startTimestamp) / 1000.0),
            maximumDate: Date(timeIntervalSince1970: Double(summary.endTimestamp) / 1000.0),
            completion: { [weak self] date in
                self?.selectedEndTime = date
                self?.populateContent()
            }
        )
    }
    
    private func presentDatePicker(title: String, initialDate: Date, minimumDate: Date, maximumDate: Date, completion: @escaping (Date) -> Void) {
        let pickerViewController = TimePickerViewController(
            initialDate: initialDate,
            minimumDate: minimumDate,
            maximumDate: maximumDate,
            title: title
        )
        
        pickerViewController.onDateSelected = { [weak self] date in
            completion(date)
            self?.dismiss(animated: true)
        }
        
        pickerViewController.onCancel = { [weak self] in
            self?.dismiss(animated: true)
        }
        
        let navController = UINavigationController(rootViewController: pickerViewController)
        
        // For iPad - use popover
        if UIDevice.current.userInterfaceIdiom == .pad {
            navController.modalPresentationStyle = .popover
            if let popover = navController.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        } else {
            navController.modalPresentationStyle = .pageSheet
        }
        
        present(navController, animated: true)
    }
    
    @objc private func calculateAndPrint() {
        guard let startTime = selectedStartTime, let endTime = selectedEndTime else {
            return
        }
        
        // Validate that start time is before end time
        if startTime > endTime {
            print("")
            print("========================================")
            print("ERROR: INVALID TIME RANGE")
            print("========================================")
            print("Start time must be before end time!")
            print("")
            print("Selected Start (UTC): \(formatDateTimeUTC(startTime))")
            print("Selected End (UTC): \(formatDateTimeUTC(endTime))")
            let duration = endTime.timeIntervalSince(startTime)
            print("Duration: \(formatMsDuration(Int(duration * 1000)))")
            print("========================================")
            print("")
            return
        }
        
        // Validate time range is within session duration (with 1 second tolerance)
        let sessionStartMs = summary.startTimestamp
        let sessionEndMs = summary.endTimestamp
        let sessionStart = Date(timeIntervalSince1970: Double(sessionStartMs) / 1000.0)
        let sessionEnd = Date(timeIntervalSince1970: Double(sessionEndMs) / 1000.0)
        let selectedStartMs = Int64(startTime.timeIntervalSince1970 * 1000)
        let selectedEndMs = Int64(endTime.timeIntervalSince1970 * 1000)
        let toleranceMs: Int64 = 1000 // 1 second tolerance
        
        if selectedStartMs < (sessionStartMs - toleranceMs) || selectedEndMs > (sessionEndMs + toleranceMs) {
            print("")
            print("========================================")
            print("ERROR: TIME RANGE OUT OF BOUNDS")
            print("========================================")
            print("Session ID: \(summary.sessionId)")
            print("Session Start (UTC): \(formatDateTimeUTC(sessionStart))")
            print("Session End (UTC): \(formatDateTimeUTC(sessionEnd))")
            print("Selected Start (UTC): \(formatDateTimeUTC(startTime))")
            print("Selected End (UTC): \(formatDateTimeUTC(endTime))")
            if selectedStartMs < (sessionStartMs - toleranceMs) {
                let diffMs = (sessionStartMs - toleranceMs) - selectedStartMs
                print("⚠ Start time is \(formatMsDuration(Int(diffMs))) before session start")
            }
            if selectedEndMs > (sessionEndMs + toleranceMs) {
                let diffMs = selectedEndMs - (sessionEndMs + toleranceMs)
                print("⚠ End time is \(formatMsDuration(Int(diffMs))) after session end")
            }
            print("========================================")
            print("")
            return
        }
        
        // Filter events by time range
        let filteredEvents = events.filter { event in
            // Convert Int64 timestamp (milliseconds) to Date
            let eventDate = Date(timeIntervalSince1970: Double(event.timestamp) / 1000.0)
            return eventDate >= startTime && eventDate <= endTime
        }
        
        // Print to console
        print("")
        print("========================================")
        print("CALCULATE METRICS FOR TIME RANGE")
        print("========================================")
        print("Session ID: \(summary.sessionId)")
        print("Start Time (UTC): \(formatDateTimeUTC(startTime))")
        print("End Time (UTC): \(formatDateTimeUTC(endTime))")
        print("Start Time (Local): \(formatDateTime(startTime))")
        print("End Time (Local): \(formatDateTime(endTime))")
        print("Start Timestamp (ms): \(selectedStartMs)")
        print("End Timestamp (ms): \(selectedEndMs)")
        let durationMs = Int(selectedEndMs - selectedStartMs)
        print("Duration: \(formatMsDuration(durationMs))")
        print("")
        print("Filtered Events Count: \(filteredEvents.count)")
        print("")
        
        // Compute HSI metrics for the filtered time range
        guard let behavior = behavior, behavior.isFluxAvailable else {
            return
        }
        
        // Get device ID and timezone
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios-device"
        let timezone = TimeZone.current.identifier
        
        // Convert filtered events to Flux JSON format
        let fluxJson = convertToFluxSessionJson(
            sessionId: summary.sessionId,
            deviceId: deviceId,
            timezone: timezone,
            startTime: startTime,
            endTime: endTime,
            events: filteredEvents
        )
        
        print("Flux JSON length: \(fluxJson.count) characters")
        print("")
        
        // Compute HSI using Flux
        guard let hsiJson = FluxBridge.shared.behaviorToHsi(fluxJson) else {
            return
        }
        
        print("HSI JSON computed successfully!")
        print("HSI JSON length: \(hsiJson.count) characters")
        print("")
        print("========================================")
        print("HSI OUTPUT (JSON)")
        print("========================================")
        print(hsiJson)
        print("")
        print("========================================")
        print("")
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDateTimeUTC(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    private func formatMsDuration(_ ms: Int) -> String {
        let seconds = ms / 1000
        let minutes = seconds / 60
        let hours = minutes / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m \(seconds % 60)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds % 60)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func parseISO8601Date(_ isoString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: isoString)
    }
}

// MARK: - TimePickerViewController

class TimePickerViewController: UIViewController {
    private let initialDate: Date
    private let minimumDate: Date
    private let maximumDate: Date
    private let pickerTitle: String
    
    private var selectedDate: Date
    private var datePicker: UIDatePicker!
    private var timePickerView: UIPickerView!
    
    var onDateSelected: ((Date) -> Void)?
    var onCancel: (() -> Void)?
    
    init(initialDate: Date, minimumDate: Date, maximumDate: Date, title: String) {
        self.initialDate = initialDate
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.pickerTitle = title
        self.selectedDate = initialDate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = pickerTitle
        
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        
        setupDatePicker()
        setupTimePicker()
        setupButtons()
    }
    
    private func setupDatePicker() {
        datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }
        datePicker.date = initialDate
        datePicker.minimumDate = minimumDate
        datePicker.maximumDate = maximumDate
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(datePicker)
        
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupTimePicker() {
        timePickerView = UIPickerView()
        timePickerView.delegate = self
        timePickerView.dataSource = self
        timePickerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(timePickerView)
        
        // Set initial time values
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: initialDate)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        
        // Extract milliseconds from nanoseconds
        let nanosecond = components.nanosecond ?? 0
        let millisecond = nanosecond / 1_000_000
        
        timePickerView.selectRow(hour, inComponent: 0, animated: false)
        timePickerView.selectRow(minute, inComponent: 1, animated: false)
        timePickerView.selectRow(second, inComponent: 2, animated: false)
        timePickerView.selectRow(millisecond, inComponent: 3, animated: false)
        
        NSLayoutConstraint.activate([
            timePickerView.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 20),
            timePickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            timePickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            timePickerView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func setupButtons() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
    }
    
    @objc private func dateChanged() {
        updateSelectedDate()
    }
    
    @objc private func cancelTapped() {
        onCancel?()
    }
    
    @objc private func doneTapped() {
        updateSelectedDate()
        onDateSelected?(selectedDate)
    }
    
    private func updateSelectedDate() {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: datePicker.date)
        
        let hour = timePickerView.selectedRow(inComponent: 0)
        let minute = timePickerView.selectedRow(inComponent: 1)
        let second = timePickerView.selectedRow(inComponent: 2)
        let millisecond = timePickerView.selectedRow(inComponent: 3)
        
        var components = DateComponents()
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.nanosecond = millisecond * 1_000_000
        
        if let newDate = calendar.date(from: components) {
            selectedDate = newDate
        }
    }
}

extension TimePickerViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 4 // Hour, Minute, Second, Millisecond
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0: return 24 // Hours: 0-23
        case 1: return 60 // Minutes: 0-59
        case 2: return 60 // Seconds: 0-59
        case 3: return 1000 // Milliseconds: 0-999
        default: return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch component {
        case 0: return String(format: "%02d", row) // Hour
        case 1: return String(format: "%02d", row) // Minute
        case 2: return String(format: "%02d", row) // Second
        case 3: return String(format: "%03d", row) // Millisecond
        default: return nil
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        updateSelectedDate()
    }
    
    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        switch component {
        case 0: return 60 // Hour
        case 1: return 60 // Minute
        case 2: return 60 // Second
        case 3: return 80 // Millisecond (needs more space for 3 digits)
        default: return 0
        }
    }
}
