# Synheart Flux Integration

This document explains how to integrate synheart-flux (Rust library) with SynheartBehavior for HSI-compliant behavioral metrics computation.

## Overview

The SynheartBehavior SDK **requires** synheart-flux (Rust library) for computing behavioral metrics. The SDK provides HSI-compliant output including:
- Distraction score and focus hint
- Burstiness (Barabási formula)
- Task switch rate (exponential saturation)
- Notification load (exponential saturation)
- Scroll jitter rate
- Deep focus blocks
- Interaction intensity
- **Typing session summary** (session count, average speed, cadence, **clipboard_activity_rate**, **correction_rate**, etc.; requires synheart-flux **0.3.0+** for the two rates)
- Rolling baselines across sessions

**Flux is now required** - the SDK will fail to initialize if Flux libraries are not available.

## Benefits

- **HSI Compliance**: Metrics computed using synheart-flux are fully HSI-compliant
- **Cross-Platform Consistency**: Same Rust code runs on iOS, Android, and other platforms
- **Baseline Support**: Rolling baselines across 20 sessions
- **Deterministic Output**: Reproducible results for research

## Installation

### Step 1: Download the XCFramework

Download `synheart-flux-ios-xcframework.zip` from the [synheart-flux releases](https://github.com/synheart-ai/synheart-flux/releases).

### Step 2: Add to Your Project

Extract the zip and place the XCFramework in your project:

**Option A: For apps using SynheartBehavior via SPM**

1. Add `SynheartFlux.xcframework` to your app target (not the package)
2. In Xcode: Target > General > Frameworks, Libraries, and Embedded Content
3. Add the XCFramework and set to "Embed & Sign"

**Option B: For direct integration**

Place the XCFramework in the Frameworks directory:
```
SynheartBehavior/
├── Frameworks/
│   └── SynheartFlux.xcframework/
│       ├── ios-arm64/
│       ├── ios-arm64_x86_64-simulator/
│       └── Info.plist
└── Sources/
    └── SynheartBehavior/
```

### Step 3: Verify Integration

```swift
import SynheartBehavior

let sdk = SynheartBehavior()
print("synheart-flux available: \(sdk.isFluxAvailable)")
```

## Usage

### Basic Usage (with HSI output)

```swift
import SynheartBehavior

let config = BehaviorConfig(
    enableInputSignals: true,
    enableAttentionSignals: true
)

let sdk = SynheartBehavior(config: config)
try sdk.initialize()

// Start a session
let sessionId = try sdk.startSession()

// ... user interacts with app ...

// End session with HSI output (uses synheart-flux if available)
if let hsiPayload = try sdk.endSessionWithHsi(sessionId: sessionId) {
    // Access HSI-compliant metrics
    if let window = hsiPayload.behaviorWindows.first {
        print("Distraction score: \(window.behavior.distractionScore)")
        print("Focus hint: \(window.behavior.focusHint)")
        print("Burstiness: \(window.behavior.burstiness)")
        print("Task switch rate: \(window.behavior.taskSwitchRate)")

        if let baseline = window.baseline {
            print("Baseline distraction: \(baseline.distraction ?? 0)")
            print("Sessions in baseline: \(baseline.sessionsInBaseline)")
        }
    }
} else {
    // Fallback to basic summary
    let summary = try sdk.endSession(sessionId: sessionId)
    print("Event count: \(summary.eventCount)")
}
```

### Using FluxBridge Directly

For more control, use FluxBridge directly:

```swift
import SynheartBehavior

// Check availability
guard FluxBridge.shared.isAvailable else {
    print("synheart-flux not available")
    return
}

// Create a stateful processor with baselines
let processor = try FluxBehaviorProcessor(baselineWindowSessions: 20)

// Load previous baselines (if any)
if let savedBaselines = UserDefaults.standard.string(forKey: "behavior_baselines") {
    try processor.loadBaselines(savedBaselines)
}

// Process a session
let sessionJson = """
{
    "session_id": "sess-123",
    "device_id": "device-456",
    "timezone": "America/New_York",
    "start_time": "2024-01-15T14:00:00Z",
    "end_time": "2024-01-15T14:30:00Z",
    "events": [
        {"timestamp": "2024-01-15T14:01:00Z", "event_type": "scroll", "scroll": {"velocity": 150.5, "direction": "down"}},
        {"timestamp": "2024-01-15T14:02:00Z", "event_type": "tap", "tap": {"tap_duration_ms": 120}}
    ]
}
"""

let hsiJson = try processor.process(sessionJson)
if let payload = parseHsiJson(hsiJson) {
    print("HSI computed successfully")
}

// Save baselines for next session
let baselines = try processor.saveBaselines()
UserDefaults.standard.set(baselines, forKey: "behavior_baselines")

// Clean up
processor.dispose()
```

### Stateless Processing

For one-shot processing without baselines:

```swift
if let hsiJson = FluxBridge.shared.behaviorToHsi(sessionJson) {
    if let payload = parseHsiJson(hsiJson) {
        // Use HSI metrics
    }
}
```

## Typing summary from Flux

When you end a session with `endSessionWithHsi(sessionId:)`, Flux computes the **typing session summary** from the events the SDK sent. The SDK includes in each typing event:

- `typing_tap_count`, `typing_speed`, `mean_inter_tap_interval_ms`, `typing_cadence_variability`, `typing_cadence_stability`, gap/burstiness/activity/intensity metrics, `duration`, `start_at`, `end_at`, `deep_typing`
- **Correction/clipboard counts**: `number_of_backspace`, `number_of_delete` (0 on iOS), `number_of_copy`, `number_of_paste`, `number_of_cut`

Flux (v0.3.0+) uses those counts to compute:

- **clipboard_activity_rate** = (copy + paste + cut) / (typing_tap_count + copy + paste + cut)
- **correction_rate** = (backspace + delete) / (typing_tap_count + backspace + delete)

These appear in the HSI `meta` section and in `extractMetricsDictionary(from:hsiJson:)` under `typing_session_summary`. To get non-zero copy/paste/cut counts, your app must call `behavior.recordCopy()`, `behavior.recordPaste()`, and `behavior.recordCut()` when the user performs those actions (e.g. from a custom text field that overrides `copy(_:)`/`paste(_:)`/`cut(_:)`). Cut removals are not counted as backspace.

## Building from Source

If you prefer to build synheart-flux from source:

```bash
cd /path/to/synheart-flux

# Build iOS XCFramework
bash scripts/build-ios-xcframework.sh dist/ios

# Copy to your project
cp -r dist/ios/SynheartFlux.xcframework /path/to/your/project/Frameworks/
```

## Verifying Integration

Check the console for these messages:

**Success:**
```
FluxBridge: Successfully initialized synheart-flux
SessionManager: Successfully computed HSI metrics using synheart-flux (stateful)
```

**Not Available:**
```
FluxBridge: synheart-flux not available, using Swift fallback
```

## HSI Output Format

The HSI payload includes:

```swift
struct HsiBehaviorPayload {
    let hsiVersion: String           // "1.0.0"
    let producer: HsiProducer        // name, version, instance_id
    let provenance: HsiProvenance    // source_device_id, timestamps
    let quality: HsiQuality          // coverage, confidence, flags
    let behaviorWindows: [HsiBehaviorWindow]
}

struct HsiBehaviorWindow {
    let sessionId: String
    let startTimeUtc: String
    let endTimeUtc: String
    let durationSec: Double
    let behavior: HsiBehavioralMetrics
    let baseline: HsiBehaviorBaseline?
    let eventSummary: HsiEventSummary
}

struct HsiBehavioralMetrics {
    let distractionScore: Double      // 0.0 to 1.0
    let focusHint: Double             // 0.0 to 1.0
    let taskSwitchRate: Double        // 0.0 to 1.0
    let notificationLoad: Double      // 0.0 to 1.0
    let burstiness: Double            // 0.0 to 1.0
    let scrollJitterRate: Double
    let interactionIntensity: Double
    let deepFocusBlocks: Int
    let idleRatio: Double
    let fragmentedIdleRatio: Double
}
```

## Troubleshooting

### XCFramework not found

Ensure the XCFramework is:
1. In your app target (not just the package)
2. Set to "Embed & Sign" in Frameworks settings
3. Contains the correct architecture slices

### Symbols not found at runtime

- The library uses dynamic symbol lookup via `dlsym`
- Ensure the XCFramework is properly embedded
- Check that the app is signed correctly

### Baseline data not persisting

- Use `processor.saveBaselines()` before the app terminates
- Store the JSON string in UserDefaults or Keychain
- Load with `processor.loadBaselines()` on next launch

## API Reference

### SynheartBehavior

```swift
// Check if synheart-flux is available
var isFluxAvailable: Bool { get }

// End session with HSI output (returns nil if Flux unavailable)
func endSessionWithHsi(sessionId: String) throws -> HsiBehaviorPayload?
```

### FluxBridge

```swift
// Singleton
static let shared: FluxBridge

// Check availability
var isAvailable: Bool { get }

// Stateless processing
func behaviorToHsi(_ sessionJson: String) -> String?

// Create processor
func createProcessor(baselineWindowSessions: Int) -> OpaquePointer?
```

### FluxBehaviorProcessor

```swift
// Create with baseline window
init(baselineWindowSessions: Int) throws

// Process session
func process(_ sessionJson: String) throws -> String

// Baseline management
func saveBaselines() throws -> String
func loadBaselines(_ baselinesJson: String) throws

// Clean up
func dispose()
```
