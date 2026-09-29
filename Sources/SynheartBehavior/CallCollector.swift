import Foundation
#if canImport(CallKit) && os(iOS)
import CallKit
#endif

/// Collects phone-call interruptions: one event per call, at its outcome.
///
/// `answered` when an incoming call connects, `ignored` when it ends without
/// connecting. Outgoing calls are the person's own action and are not
/// reported. Privacy: timing and outcome only, never a number or a contact.
///
/// Emits only while a session is running and attention signals are enabled.
/// Inert off iOS, where CallKit is unavailable.
internal final class CallCollector: NSObject {
    private weak var sdk: SynheartBehavior?
    private weak var sessionManager: SessionManager?
    private var tracker = CallOutcomeTracker()
    private var enabled: Bool

    #if canImport(CallKit) && os(iOS)
    private var observer: CXCallObserver?
    #endif

    init(sdk: SynheartBehavior, sessionManager: SessionManager, enabled: Bool) {
        self.sdk = sdk
        self.sessionManager = sessionManager
        self.enabled = enabled
        super.init()
    }

    func updateEnabled(_ enabled: Bool) {
        self.enabled = enabled
    }

    func start() {
        #if canImport(CallKit) && os(iOS)
        guard observer == nil else { return }
        let observer = CXCallObserver()
        observer.setDelegate(self, queue: nil)
        self.observer = observer
        #endif
    }

    func stop() {
        #if canImport(CallKit) && os(iOS)
        observer?.setDelegate(nil, queue: nil)
        observer = nil
        #endif
        tracker = CallOutcomeTracker()
    }

    /// Feed one observation. Exposed for the platform delegate and for tests.
    func observe(id: UUID, isOutgoing: Bool, hasConnected: Bool, hasEnded: Bool) {
        let nowMs = Date().timeIntervalSince1970 * 1_000
        guard let outcome = tracker.update(
            id: id, isOutgoing: isOutgoing, hasConnected: hasConnected, hasEnded: hasEnded, nowMs: nowMs
        ) else { return }
        guard enabled, let sessionId = sessionManager?.getCurrentSessionId() else { return }
        sdk?.emitEvent(BehaviorEvent.call(sessionId: sessionId, action: outcome))
    }
}

#if canImport(CallKit) && os(iOS)
extension CallCollector: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        observe(
            id: call.uuid,
            isOutgoing: call.isOutgoing,
            hasConnected: call.hasConnected,
            hasEnded: call.hasEnded
        )
    }
}
#endif
