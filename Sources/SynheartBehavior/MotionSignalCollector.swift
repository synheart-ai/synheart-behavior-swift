import Foundation
#if canImport(CoreMotion) && os(iOS)
import CoreMotion
#endif

/// Collects raw accelerometer samples at 50 Hz and hands them out in 1 s
/// batches, for a consumer that runs its own motion classification.
///
/// Samples are in **m/s² with gravity included**, matching the documented
/// motion-sample contract across platforms (Android's raw accelerometer
/// reports m/s²). CoreMotion reports g, so the collector converts.
///
/// Runs only while a session is running and either ``BehaviorConfig/enableMotionLite``
/// or ``BehaviorConfig/emitRawMotionSamples`` is set; batches are emitted only
/// for the latter, and only when a handler is registered. Inert off iOS.
/// Privacy: raw motion values and timing only, never location.
internal final class MotionSignalCollector {
    /// One raw sample as handed to the batch handler: `ts_ms`, `ax`, `ay`, `az`.
    typealias RawSample = [String: Any]

    private var config: BehaviorConfig
    private var batchHandler: (([RawSample]) -> Void)?
    private var batchTimer: Timer?
    private var sessionStartMs: Double = 0
    private var lastBatchEndMs: Double = 0
    private var isCollecting = false

    private let sampleQueue = DispatchQueue(label: "ai.synheart.behavior.motion", attributes: .concurrent)
    private var samples: [(ts: Double, x: Double, y: Double, z: Double)] = []

    /// 50 Hz.
    static let updateInterval: TimeInterval = 0.02
    static let batchIntervalMs: Double = 1_000
    static let retainedHistoryMs: Double = 10_000
    static let gravity: Double = 9.80665

    #if canImport(CoreMotion) && os(iOS)
    private var motionManager: CMMotionManager?
    #endif

    init(config: BehaviorConfig) {
        self.config = config
    }

    var shouldCollect: Bool { config.enableMotionLite || config.emitRawMotionSamples }

    func updateConfig(_ newConfig: BehaviorConfig) {
        config = newConfig
        if !shouldCollect, isCollecting {
            stopCollecting()
        } else if shouldCollect, !isCollecting, sessionStartMs > 0 {
            startCollecting()
        }
        updateBatchTimer()
    }

    /// Register a handler for 1 s batches of raw 50 Hz samples. Fires only
    /// when ``BehaviorConfig/emitRawMotionSamples`` is set and a session runs.
    func setRawSampleBatchHandler(_ handler: (([RawSample]) -> Void)?) {
        batchHandler = handler
        updateBatchTimer()
    }

    func startSession(startMs: Double) {
        sessionStartMs = startMs
        lastBatchEndMs = startMs
        sampleQueue.async(flags: .barrier) { self.samples.removeAll() }
        if shouldCollect { startCollecting() }
        updateBatchTimer()
    }

    func endSession() {
        stopCollecting()
        flushBatch()
        stopBatchTimer()
        sessionStartMs = 0
    }

    func dispose() {
        stopCollecting()
        stopBatchTimer()
        batchHandler = nil
        sampleQueue.async(flags: .barrier) { self.samples.removeAll() }
    }

    /// Feed one sample already in m/s². Used by the platform source and by tests.
    func ingest(tsMs: Double, x: Double, y: Double, z: Double) {
        sampleQueue.async(flags: .barrier) {
            self.samples.append((tsMs, x, y, z))
        }
    }

    // MARK: - Platform source

    private func startCollecting() {
        guard !isCollecting else { return }
        #if canImport(CoreMotion) && os(iOS)
        let manager = CMMotionManager()
        guard manager.isAccelerometerAvailable else { return }
        manager.accelerometerUpdateInterval = Self.updateInterval
        manager.startAccelerometerUpdates(to: OperationQueue()) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            let g = Self.gravity
            self.ingest(
                tsMs: Date().timeIntervalSince1970 * 1_000,
                x: data.acceleration.x * g,
                y: data.acceleration.y * g,
                z: data.acceleration.z * g
            )
        }
        motionManager = manager
        #endif
        isCollecting = true
    }

    private func stopCollecting() {
        guard isCollecting else { return }
        #if canImport(CoreMotion) && os(iOS)
        motionManager?.stopAccelerometerUpdates()
        motionManager = nil
        #endif
        isCollecting = false
    }

    // MARK: - Batch emission

    private func updateBatchTimer() {
        let shouldEmit = config.emitRawMotionSamples && batchHandler != nil && sessionStartMs > 0
        if shouldEmit, batchTimer == nil {
            startBatchTimer()
        } else if !shouldEmit {
            stopBatchTimer()
        }
    }

    private func startBatchTimer() {
        let interval = Self.batchIntervalMs / 1_000
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.batchTimer?.invalidate()
            self.batchTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.flushBatch()
            }
        }
    }

    private func stopBatchTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.batchTimer?.invalidate()
            self?.batchTimer = nil
        }
    }

    /// Hand every sample since the last flush to the handler, oldest first,
    /// and trim the buffer to the last ``retainedHistoryMs``.
    func flushBatch() {
        guard let handler = batchHandler, config.emitRawMotionSamples else { return }
        let nowMs = Date().timeIntervalSince1970 * 1_000
        let batch: [RawSample] = sampleQueue.sync(flags: .barrier) {
            let since = lastBatchEndMs
            let recent = samples.filter { $0.ts > since && $0.ts <= nowMs }
            let cutoff = nowMs - Self.retainedHistoryMs
            samples.removeAll { $0.ts < cutoff }
            lastBatchEndMs = nowMs
            return recent.map { ["ts_ms": Int64($0.ts), "ax": $0.x, "ay": $0.y, "az": $0.z] }
        }
        if batch.isEmpty { return }
        handler(batch)
    }
}
