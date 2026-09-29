import Foundation

/// Pure state for the call collector: one event per call, at its outcome.
///
/// A call is `answered` when it connects, or `ignored` when it ends without
/// ever connecting. Its arrival and its hang-up are tracked but never
/// reported, so a consumer counting call events sees exactly one per call.
/// Kept free of CallKit so the rule is testable on any platform.
struct CallOutcomeTracker {
    private var incomingSince: [UUID: Double] = [:]
    private var connected: Set<UUID> = []

    /// Minimum ring time for an unanswered call to count as ignored. Filters
    /// system and accidental calls that end within a second.
    let minimumIgnoredRingMs: Double

    init(minimumIgnoredRingMs: Double = 1_000) {
        self.minimumIgnoredRingMs = minimumIgnoredRingMs
    }

    /// Feed one call-state observation. Returns the outcome to report
    /// (`"answered"` or `"ignored"`), or `nil` when nothing is reportable yet.
    mutating func update(
        id: UUID,
        isOutgoing: Bool,
        hasConnected: Bool,
        hasEnded: Bool,
        nowMs: Double
    ) -> String? {
        if isOutgoing {
            // Outgoing calls are the person's own action, not an interruption.
            if hasEnded { incomingSince[id] = nil; connected.remove(id) }
            return nil
        }
        if hasEnded {
            defer { incomingSince[id] = nil; connected.remove(id) }
            if connected.contains(id) { return nil }          // hang-up of an answered call
            guard let since = incomingSince[id] else { return nil }
            return (nowMs - since) >= minimumIgnoredRingMs ? "ignored" : nil
        }
        if hasConnected {
            guard incomingSince[id] != nil, !connected.contains(id) else { return nil }
            connected.insert(id)
            return "answered"
        }
        if incomingSince[id] == nil { incomingSince[id] = nowMs }
        return nil
    }
}

/// Pure state for the notification collector: an arrival, then exactly one
/// outcome (`opened`, or `ignored` after the threshold).
struct NotificationOutcomeTracker {
    private var pending: [String: Double] = [:]
    private var order: [String] = []
    let capacity: Int

    init(capacity: Int = 100) {
        self.capacity = capacity
    }

    /// Record an arrival. Returns `false` if this id is already pending, so a
    /// re-delivered notification is not counted as a second arrival.
    mutating func received(id: String, atMs: Double) -> Bool {
        if pending[id] != nil { return false }
        pending[id] = atMs
        order.append(id)
        if order.count > capacity, let oldest = order.first {
            order.removeFirst()
            pending[oldest] = nil
        }
        return true
    }

    /// Record an open. Returns `true` when the id was pending (its `ignored`
    /// timer must be cancelled), `false` for an open of something never seen.
    mutating func opened(id: String) -> Bool {
        guard pending.removeValue(forKey: id) != nil else { return false }
        order.removeAll { $0 == id }
        return true
    }

    /// The ignored timer fired. Returns `true` when the id was still pending,
    /// meaning an `ignored` outcome should be reported.
    mutating func expired(id: String) -> Bool {
        guard pending.removeValue(forKey: id) != nil else { return false }
        order.removeAll { $0 == id }
        return true
    }

    var pendingCount: Int { pending.count }
}
