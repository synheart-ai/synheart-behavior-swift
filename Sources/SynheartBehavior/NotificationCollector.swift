import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Collects notification interruptions for the host app's own notifications:
/// an arrival (`received`), then exactly one outcome — `opened` when tapped,
/// or `ignored` after ``ignoredThresholdMs`` without a response.
///
/// iOS exposes only the app's own notifications, so there is no source app to
/// report. Privacy: timing and outcome only, never title or body.
///
/// iOS reports an arrival only for a notification delivered while the app is
/// in the foreground (`willPresent`). A notification delivered in the
/// background and tapped later is not reported at all: an `opened` without
/// its arrival would break the one-arrival-one-outcome rule.
///
/// By default the collector does **not** touch `UNUserNotificationCenter`.
/// The host forwards its delegate callbacks through
/// ``SynheartBehavior/notificationDelivered(id:)`` and
/// ``SynheartBehavior/notificationOpened(id:)``. With
/// ``BehaviorConfig/installNotificationDelegate`` the collector installs
/// itself as the delegate instead, forwards every callback to the delegate it
/// replaced, and puts that delegate back when it stops.
internal final class NotificationCollector: NSObject {
    private weak var sdk: SynheartBehavior?
    private weak var sessionManager: SessionManager?
    private var tracker = NotificationOutcomeTracker()
    private var pendingIgnored: [String: DispatchWorkItem] = [:]
    private var enabled: Bool
    private let installDelegate: Bool
    private var installedDelegate = false

    #if canImport(UserNotifications) && !os(macOS)
    /// The delegate this collector replaced, forwarded to and restored on stop.
    private weak var previousDelegate: UNUserNotificationCenterDelegate?
    #endif

    /// How long an un-tapped notification waits before it is reported as ignored.
    let ignoredThresholdMs: Double

    init(
        sdk: SynheartBehavior,
        sessionManager: SessionManager,
        enabled: Bool,
        installDelegate: Bool,
        ignoredThresholdMs: Double = 30_000
    ) {
        self.sdk = sdk
        self.sessionManager = sessionManager
        self.enabled = enabled
        self.installDelegate = installDelegate
        self.ignoredThresholdMs = ignoredThresholdMs
        super.init()
    }

    func updateEnabled(_ enabled: Bool) {
        self.enabled = enabled
    }

    func start() {
        #if canImport(UserNotifications) && !os(macOS)
        guard installDelegate, !installedDelegate else { return }
        let center = UNUserNotificationCenter.current()
        if center.delegate !== self { previousDelegate = center.delegate }
        center.delegate = self
        installedDelegate = true
        #endif
    }

    func stop() {
        #if canImport(UserNotifications) && !os(macOS)
        if installedDelegate, UNUserNotificationCenter.current().delegate === self {
            UNUserNotificationCenter.current().delegate = previousDelegate
        }
        previousDelegate = nil
        installedDelegate = false
        #endif
        pendingIgnored.values.forEach { $0.cancel() }
        pendingIgnored.removeAll()
        tracker = NotificationOutcomeTracker()
    }

    /// A notification was delivered. Reports `received` and arms the ignored timer.
    func noteDelivered(id: String) {
        let nowMs = Date().timeIntervalSince1970 * 1_000
        guard tracker.received(id: id, atMs: nowMs) else { return }
        emit(action: "received")
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingIgnored[id] = nil
            if self.tracker.expired(id: id) { self.emit(action: "ignored") }
        }
        pendingIgnored[id]?.cancel()
        pendingIgnored[id] = task
        DispatchQueue.main.asyncAfter(deadline: .now() + ignoredThresholdMs / 1_000, execute: task)
    }

    /// The person tapped a notification. Reports `opened` and cancels its
    /// ignored timer — only for a notification whose arrival was reported.
    func noteOpened(id: String) {
        pendingIgnored[id]?.cancel()
        pendingIgnored[id] = nil
        guard tracker.opened(id: id) else { return }
        emit(action: "opened")
    }

    private func emit(action: String) {
        guard enabled, let sessionId = sessionManager?.getCurrentSessionId() else { return }
        sdk?.emitEvent(BehaviorEvent.notification(sessionId: sessionId, action: action))
    }
}

#if canImport(UserNotifications) && !os(macOS)
extension NotificationCollector: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        noteDelivered(id: notification.request.identifier)
        // The presentation is the host's choice. Without a previous delegate
        // that answers, keep the system default: nothing shown in the foreground.
        if let forward = previousDelegate?.userNotificationCenter(_:willPresent:withCompletionHandler:) {
            forward(center, notification, completionHandler)
        } else {
            completionHandler([])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        noteOpened(id: response.notification.request.identifier)
        if let forward = previousDelegate?.userNotificationCenter(_:didReceive:withCompletionHandler:) {
            forward(center, response, completionHandler)
        } else {
            completionHandler()
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        previousDelegate?.userNotificationCenter?(center, openSettingsFor: notification)
    }
}
#endif
