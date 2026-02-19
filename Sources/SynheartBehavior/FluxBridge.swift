import Foundation

/// Bridge to synheart-flux Rust library for HSI-compliant behavioral metrics computation.
///
/// This class provides C FFI bindings to the Rust implementation of behavioral metrics,
/// ensuring consistent HSI-compliant output across all platforms.
///
/// When synheart-flux is available, it computes:
/// - Distraction score
/// - Focus hint
/// - Burstiness (Barabási formula)
/// - Task switch rate
/// - Notification load
/// - Scroll jitter rate
/// - Deep focus blocks
/// - Interaction intensity
/// - Rolling baselines
public final class FluxBridge {

    /// Shared singleton instance
    public static let shared = FluxBridge()

    private var initialized = false

    private init() {
        initialized = checkRustLibraryAvailable()
    }

    private func checkRustLibraryAvailable() -> Bool {
        // For static libraries, we can't use dlsym to check availability
        // Instead, we'll try to call a simple function to see if it's linked
        // If the symbol is not linked, this will cause a linker error at build time
        // At runtime, if the function returns a valid result or doesn't crash, the library is available
        // We use a test call to flux_version() which is always available and safe
        return testFluxAvailability()
    }
    
    private func testFluxAvailability() -> Bool {
        // Try to get the version string - if this works, the library is linked
        // For static libraries, if not linked, this will cause a linker error at build time
        // At runtime, if we get here, the library should be available
        if let versionPtr = flux_version() {
            let version = String(cString: versionPtr)
            return !version.isEmpty
        }
        return false
    }

    /// Check if synheart-flux is available.
    public var isAvailable: Bool {
        return initialized
    }

    // MARK: - Stateless API

    /// Convert behavioral session to HSI JSON (stateless, one-shot).
    ///
    /// - Parameter sessionJson: JSON string containing the behavioral session data
    ///   in synheart-flux format
    /// - Returns: HSI JSON string, or nil if computation failed
    public func behaviorToHsi(_ sessionJson: String) -> String? {
        guard initialized else {
            return nil
        }

        guard let jsonCString = sessionJson.cString(using: .utf8) else {
            return nil
        }

        guard let resultPtr = flux_behavior_to_hsi(jsonCString) else {
            return nil
        }

        let result = String(cString: resultPtr)
        flux_free_string(resultPtr)
        return result
    }

    // MARK: - Stateful Processor API

    /// Create a stateful behavioral processor with rolling baselines.
    ///
    /// - Parameter baselineWindowSessions: Number of sessions in the rolling baseline (default: 20)
    /// - Returns: Processor handle, or nil if creation failed
    public func createProcessor(baselineWindowSessions: Int = 20) -> OpaquePointer? {
        guard initialized else { return nil }
        return flux_behavior_processor_new(Int32(baselineWindowSessions))
    }

    /// Free a processor created with createProcessor.
    ///
    /// - Parameter handle: Processor handle to free
    public func freeProcessor(_ handle: OpaquePointer) {
        guard initialized else { return }
        flux_behavior_processor_free(handle)
    }

    /// Process a behavioral session with the stateful processor.
    ///
    /// This updates the internal baselines and returns HSI-compliant JSON.
    ///
    /// - Parameters:
    ///   - handle: Processor handle from createProcessor
    ///   - sessionJson: JSON string containing the behavioral session data
    /// - Returns: HSI JSON string, or nil if computation failed
    public func processSession(_ handle: OpaquePointer, sessionJson: String) -> String? {
        guard initialized else { return nil }

        guard let jsonCString = sessionJson.cString(using: .utf8) else {
            return nil
        }

        guard let resultPtr = flux_behavior_processor_process(handle, jsonCString) else {
            return nil
        }

        let result = String(cString: resultPtr)
        flux_free_string(resultPtr)
        return result
    }

    /// Save baselines from a processor to JSON for persistence.
    ///
    /// - Parameter handle: Processor handle
    /// - Returns: JSON string containing baseline data, or nil if failed
    public func saveBaselines(_ handle: OpaquePointer) -> String? {
        guard initialized else { return nil }

        guard let resultPtr = flux_behavior_processor_save_baselines(handle) else {
            return nil
        }

        let result = String(cString: resultPtr)
        flux_free_string(resultPtr)
        return result
    }

    /// Load baselines into a processor from JSON.
    ///
    /// - Parameters:
    ///   - handle: Processor handle
    ///   - baselinesJson: JSON string containing baseline data
    /// - Returns: true if loading succeeded, false otherwise
    public func loadBaselines(_ handle: OpaquePointer, baselinesJson: String) -> Bool {
        guard initialized else { return false }

        guard let jsonCString = baselinesJson.cString(using: .utf8) else {
            return false
        }

        return flux_behavior_processor_load_baselines(handle, jsonCString) == 0
    }
}

// MARK: - C FFI Declarations

// These functions are provided by the synheart-flux static library (XCFramework)
// For static libraries, symbols must be linked at compile time.
// The app target must link against the XCFramework for these to be available.

@_silgen_name("flux_behavior_to_hsi")
private func flux_behavior_to_hsi(_ json: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("flux_free_string")
private func flux_free_string(_ s: UnsafeMutablePointer<CChar>?)

@_silgen_name("flux_behavior_processor_new")
private func flux_behavior_processor_new(_ baselineWindowSessions: Int32) -> OpaquePointer?

@_silgen_name("flux_behavior_processor_free")
private func flux_behavior_processor_free(_ processor: OpaquePointer?)

@_silgen_name("flux_behavior_processor_process")
private func flux_behavior_processor_process(_ processor: OpaquePointer?, _ json: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("flux_behavior_processor_save_baselines")
private func flux_behavior_processor_save_baselines(_ processor: OpaquePointer?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("flux_behavior_processor_load_baselines")
private func flux_behavior_processor_load_baselines(_ processor: OpaquePointer?, _ json: UnsafePointer<CChar>?) -> Int32

@_silgen_name("flux_version")
private func flux_version() -> UnsafePointer<CChar>?

@_silgen_name("flux_last_error")
private func flux_last_error() -> UnsafePointer<CChar>?

// MARK: - Stateful Processor Wrapper

/// A stateful behavioral processor with persistent baselines.
///
/// Use this class when you want baselines to accumulate across multiple sessions.
public final class FluxBehaviorProcessor {

    private let handle: OpaquePointer
    private var disposed = false

    /// Create a new behavioral processor.
    ///
    /// - Parameter baselineWindowSessions: Number of sessions in the rolling baseline (default: 20)
    /// - Throws: If synheart-flux is not available or processor creation fails
    public init(baselineWindowSessions: Int = 20) throws {
        guard FluxBridge.shared.isAvailable else {
            throw FluxError.libraryNotAvailable
        }

        guard let handle = FluxBridge.shared.createProcessor(baselineWindowSessions: baselineWindowSessions) else {
            throw FluxError.processorCreationFailed
        }

        self.handle = handle
    }

    deinit {
        dispose()
    }

    /// Process a behavioral session and return HSI JSON.
    ///
    /// - Parameter sessionJson: JSON string containing the behavioral session data
    /// - Returns: HSI JSON string
    /// - Throws: If processing fails
    public func process(_ sessionJson: String) throws -> String {
        guard !disposed else {
            throw FluxError.processorDisposed
        }

        guard let result = FluxBridge.shared.processSession(handle, sessionJson: sessionJson) else {
            throw FluxError.processingFailed
        }

        return result
    }

    /// Save current baselines to JSON for persistence.
    ///
    /// - Returns: JSON string containing baseline data
    /// - Throws: If saving fails
    public func saveBaselines() throws -> String {
        guard !disposed else {
            throw FluxError.processorDisposed
        }

        guard let result = FluxBridge.shared.saveBaselines(handle) else {
            throw FluxError.baselineSaveFailed
        }

        return result
    }

    /// Load baselines from JSON.
    ///
    /// - Parameter baselinesJson: JSON string containing baseline data
    /// - Throws: If loading fails
    public func loadBaselines(_ baselinesJson: String) throws {
        guard !disposed else {
            throw FluxError.processorDisposed
        }

        guard FluxBridge.shared.loadBaselines(handle, baselinesJson: baselinesJson) else {
            throw FluxError.baselineLoadFailed
        }
    }

    /// Dispose the processor and free native resources.
    public func dispose() {
        guard !disposed else { return }
        disposed = true
        FluxBridge.shared.freeProcessor(handle)
    }
}

/// Errors that can occur when using FluxBridge.
public enum FluxError: Error, CustomStringConvertible {
    case libraryNotAvailable
    case processorCreationFailed
    case processorDisposed
    case processingFailed
    case baselineSaveFailed
    case baselineLoadFailed
    case invalidJson

    public var description: String {
        switch self {
        case .libraryNotAvailable:
            return "synheart-flux library is not available"
        case .processorCreationFailed:
            return "Failed to create behavioral processor"
        case .processorDisposed:
            return "Processor has been disposed"
        case .processingFailed:
            return "Failed to process behavioral session"
        case .baselineSaveFailed:
            return "Failed to save baselines"
        case .baselineLoadFailed:
            return "Failed to load baselines"
        case .invalidJson:
            return "Invalid JSON format"
        }
    }
}
