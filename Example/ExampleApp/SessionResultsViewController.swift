import UIKit
import SynheartBehavior

/// Displays a finished `BehaviorSessionSummary` and the raw event timeline for the session.
/// Uses only the public SDK surface — `BehaviorSessionSummary` fields and `[BehaviorEvent]`.
final class SessionResultsViewController: UIViewController {

    let summary: BehaviorSessionSummary
    let events: [BehaviorEvent]

    private let scrollView = UIScrollView()
    private let contentView = UIStackView()

    init(summary: BehaviorSessionSummary, events: [BehaviorEvent] = []) {
        self.summary = summary
        self.events = events
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Session Results"
        view.backgroundColor = .white
        setupLayout()
        populate()
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .vertical
        contentView.spacing = 12
        contentView.alignment = .fill
        contentView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        contentView.isLayoutMarginsRelativeArrangement = true

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Population

    private func populate() {
        contentView.addArrangedSubview(sessionInfoCard())

        let metrics = collectBehavioralMetrics()
        if !metrics.isEmpty {
            contentView.addArrangedSubview(card(title: "Behavioral Metrics", rows: metrics))
        }

        let typing = collectTypingMetrics()
        if !typing.isEmpty {
            contentView.addArrangedSubview(card(title: "Typing Metrics", rows: typing))
        }

        if let blocks = summary.deepFocusBlocks, !blocks.isEmpty {
            contentView.addArrangedSubview(deepFocusBlocksCard(blocks))
        }

        if !events.isEmpty {
            contentView.addArrangedSubview(eventsTimelineCard())
        }
    }

    private func sessionInfoCard() -> UIView {
        var rows: [(String, String)] = [
            ("Session ID", summary.sessionId),
            ("Duration", "\(summary.duration) ms"),
            ("Total Events", "\(summary.eventCount)"),
            ("App Switches", "\(summary.appSwitchCount)"),
        ]
        if let stab = summary.stabilityIndex {
            rows.append(("Stability Index", String(format: "%.3f", stab)))
        }
        if let frag = summary.fragmentationIndex {
            rows.append(("Fragmentation Index", String(format: "%.3f", frag)))
        }
        if let cad = summary.averageTypingCadence {
            rows.append(("Avg Typing Cadence", String(format: "%.1f", cad)))
        }
        if let vel = summary.averageScrollVelocity {
            rows.append(("Avg Scroll Velocity", String(format: "%.1f", vel)))
        }
        return card(title: "Session Info", rows: rows)
    }

    private func collectBehavioralMetrics() -> [(String, String)] {
        guard let dict = summary.behavioralMetrics else { return [] }
        let keys: [(String, String)] = [
            ("interaction_intensity", "Interaction Intensity"),
            ("behavioral_distraction_score", "Distraction Score"),
            ("behavioral_focus_hint", "Focus Hint"),
            ("task_switch_rate", "Task Switch Rate"),
            ("idle_ratio", "Idle Ratio"),
            ("fragmented_idle_ratio", "Fragmented Idle Ratio"),
            ("burstiness", "Burstiness"),
            ("notification_load", "Notification Load"),
            ("scroll_jitter_rate", "Scroll Jitter Rate"),
        ]
        return keys.compactMap { key, label in
            guard let v = dict[key] else { return nil }
            return (label, format(v))
        }
    }

    private func collectTypingMetrics() -> [(String, String)] {
        guard let dict = summary.typingMetrics else { return [] }
        let keys: [(String, String)] = [
            ("typing_cadence", "Typing Cadence"),
            ("mean_inter_tap_interval_ms", "Mean Inter-Tap Interval (ms)"),
            ("typing_cadence_variability", "Cadence Variability"),
            ("typing_burstiness", "Typing Burstiness"),
            ("typing_activity_ratio", "Active Typing Ratio"),
        ]
        return keys.compactMap { key, label in
            guard let v = dict[key] else { return nil }
            return (label, format(v))
        }
    }

    // MARK: - Cards

    private func card(title: String, rows: [(String, String)]) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        container.layer.cornerRadius = 12

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        stack.isLayoutMarginsRelativeArrangement = true
        container.addSubview(stack)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        stack.addArrangedSubview(titleLabel)

        for (label, value) in rows {
            stack.addArrangedSubview(metricRow(label: label, value: value))
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func metricRow(label: String, value: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .equalSpacing

        let l = UILabel()
        l.text = label
        l.font = .preferredFont(forTextStyle: .footnote)
        l.textColor = .gray

        let v = UILabel()
        v.text = value
        v.font = .preferredFont(forTextStyle: .footnote)
        v.textAlignment = .right

        row.addArrangedSubview(l)
        row.addArrangedSubview(v)
        return row
    }

    private func deepFocusBlocksCard(_ blocks: [[String: Any]]) -> UIView {
        var rows: [(String, String)] = [("Block Count", "\(blocks.count)")]
        for (i, block) in blocks.prefix(5).enumerated() {
            let dur = block["durationMs"].flatMap { "\($0)" } ?? "?"
            rows.append(("Block #\(i + 1) duration", "\(dur) ms"))
        }
        return card(title: "Deep Focus Blocks", rows: rows)
    }

    private func eventsTimelineCard() -> UIView {
        let visible = events.suffix(50)
        var rows: [(String, String)] = [("Total in session", "\(events.count)")]
        for event in visible {
            rows.append((event.timestamp, "\(event.eventType)"))
        }
        return card(title: "Events Timeline (last \(visible.count))", rows: rows)
    }

    // MARK: - Helpers

    private func format(_ value: Any) -> String {
        if let d = value as? Double { return String(format: "%.3f", d) }
        if let i = value as? Int { return "\(i)" }
        if let s = value as? String { return s }
        return "\(value)"
    }
}
