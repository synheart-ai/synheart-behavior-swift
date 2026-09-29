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
/// The collector installs itself as the `UNUserNotificationCenter` delegate.
/// A host that already has a delegate should forward `willPresent` and
/// `didReceive` to ``noteDelivered(id:)`` / ``noteOpened(id:)`` instead of
/// starting this collector, or it will be displaced.
internal final class NotificationCollector: NSObject {
    private weak var sdk: SynheartBehavior?
    private weak var sessionManager: SessionManager?
    private var tracker = NotificationOutcomeTracker()
    private var pendingIgnored: [String: DispatchWorkItem] = [:]
    private var enabled: Bool
    private var installedDelegate = false

    /// How long an un-tapped notification waits before it is reported as ignored.
    let ignoredThresholdMs: Double

    init(sdk: SynheartBehavior, sessionManager: SessionManager, enabled: Bool, ignoredThresholdMs: Double = 30_000) {
        self.sdk = sdk
        self.sessionManager = sessionManager
        self.enabled = enabled
        self.ignoredThresholdMs = ignoredThresholdMs
        super.init()
    }

    func updateEnabled(_ enabled: Bool) {
        self.enabled = enabled
    }

    func start() {
        #if canImport(UserNotifications) && !os(macOS)
        UNUserNotificationCenter.current().delegate = self
        installedDelegate = true
        #endif
    }

    func stop() {
        #if canImport(UserNotifications) && !os(macOS)
        if installedDelegate, UNUserNotificationCenter.current().delegate === self {
            UNUserNotificationCenter.current().delegate = nil
        }
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

    /// The person tapped a notification. Reports `opened` and cancels its ignored timer.
    func noteOpened(id: String) {
        pendingIgnored[id]?.cancel()
        pendingIgnored[id] = nil
        _ = tracker.opened(id: id)
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
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        noteOpened(id: response.notification.request.identifier)
        completionHandler()
    }
}
#endif
