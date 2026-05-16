import Foundation

/// Manages event batching and delivery to registered handlers.
internal class EventBatcher {
    private var eventHandler: ((BehaviorEvent) -> Void)?
    private var batchHandler: (([BehaviorEvent]) -> Void)?
    private var eventBuffer: [BehaviorEvent] = []
    private var batchSize: Int
    private let lock = NSLock()

    init(batchSize: Int) {
        self.batchSize = batchSize
    }

    /// Set the single event handler.
    func setEventHandler(_ handler: @escaping (BehaviorEvent) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.eventHandler = handler
    }

    /// Set the batch event handler.
    func setBatchHandler(_ handler: @escaping ([BehaviorEvent]) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.batchHandler = handler
    }

    /// Add an event to the batch.
    func addEvent(_ event: BehaviorEvent) {
        lock.lock()
        defer { lock.unlock() }

        eventBuffer.append(event)

        // Always call single event handler immediately
        eventHandler?(event)

        // Check if we should flush the batch
        if eventBuffer.count >= batchSize {
            flushBatch()
        }
    }

    /// Force flush the current batch.
    func flush() {
        lock.lock()
        defer { lock.unlock() }
        flushBatch()
    }

    private func flushBatch() {
        guard !eventBuffer.isEmpty else { return }
        guard let batchHandler = batchHandler else {
            // No batch handler, just clear buffer
            eventBuffer.removeAll()
            return
        }

        let batch = eventBuffer
        eventBuffer.removeAll()

        // Call batch handler outside the lock to avoid deadlock
        lock.unlock()
        batchHandler(batch)
        lock.lock()
    }

    /// Update batch size.
    func updateBatchSize(_ newSize: Int) {
        lock.lock()
        defer { lock.unlock() }
        self.batchSize = newSize
    }

    /// Clear all pending events.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        eventBuffer.removeAll()
    }

    /// Get current buffer count.
    func getBufferCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return eventBuffer.count
    }
}
