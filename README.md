# Synheart Behavioral SDK for iOS

[![Swift](https://img.shields.io/badge/Swift-5.0%2B-orange?logo=swift)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen?logo=swift)](https://www.swift.org/package-manager/)
[![Platform](https://img.shields.io/badge/platform-iOS%2012%2B-lightgrey)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

A lightweight, privacy-preserving iOS SDK that collects digital behavioral signals from smartphones. These signals represent biobehavioral markers strongly correlated with cognitive and emotional states, especially focus, stress, engagement, and fatigue.

## Features

- 🎯 **Privacy-First**: No text, content, or PII collected - only timing-based signals
- ⚡ **Lightweight**: <150 KB compiled, <2% CPU usage, <500 KB memory footprint
- 🔄 **Event Streaming**: Real-time event callbacks for behavioral signals
- 📊 **Session Tracking**: Built-in session management with comprehensive summaries
- 🎨 **Swift Package Manager**: Easy integration via SPM
- 📈 **On-Demand Metrics**: Calculate behavioral metrics for custom time ranges within sessions
- 🔬 **HSI-Compliant**: All metrics computed using synheart-flux for Human State Index compliance
- 📱 **System State Tracking**: Internet connectivity, charging state, and device context

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/synheart-ai/synheart-behavior-ios.git", from: "0.2.0")
]
```

Or add via Xcode:
1. File → Add Packages...
2. Enter: `https://github.com/synheart-ai/synheart-behavior-ios.git`
3. Select version: `0.2.0`

**📖 New to the SDK?** See [INTEGRATION.md](INTEGRATION.md) for a quick start guide.

## Required: synheart-flux (HSI metrics)

The SDK **requires** the native `synheart-flux` library for computing all behavioral and typing metrics. Install it as follows:

1. Download `SynheartFlux.xcframework` from the [synheart-flux releases](https://github.com/synheart-ai/synheart-flux/releases)
2. Extract and copy the framework into your project's `Frameworks/` directory
3. Add it as a framework dependency to your app target in Xcode

**Note**: The SDK requires synheart-flux version 0.1.1 or later. For **clipboard_activity_rate** and **correction_rate** in the typing summary, use synheart-flux **0.3.0** or later.

For full details (usage, troubleshooting, building from source), see [`SYNHEART_FLUX_INTEGRATION.md`](SYNHEART_FLUX_INTEGRATION.md).

## Usage

### Initialization

```swift
import SynheartBehavior

let config = BehaviorConfig(
    enableInputSignals: true,
    enableAttentionSignals: true,
    enableMotionLite: false,
    consentBehavior: true
)

let behavior = SynheartBehavior(config: config)
try behavior.initialize()

// Verify Flux is available
if behavior.isFluxAvailable {
    print("synheart-flux is ready for HSI calculations")
}
```

### Event Handling

```swift
behavior.setEventHandler { event in
    print("Event type: \(event.type)")
    print("Payload: \(event.payload)")
    print("Timestamp (ISO 8601): \(event.timestamp)")

    // Attention/multitasking signals are emitted as `.appSwitch` with an `action` subtype.
    if event.type == .appSwitch {
        print("AppSwitch action: \(event.payload["action"] ?? "n/a")")
    }
}
```

### Session Tracking

```swift
let sessionId = try behavior.startSession()

// ... user interacts with app ...

let (hsiPayload, rawHsiJson) = try behavior.endSessionWithHsi(sessionId: sessionId)
print("Session duration: \(hsiPayload.behaviorWindows.first?.durationSec ?? 0)s")
print("Total events: \(hsiPayload.behaviorWindows.first?.eventSummary.totalEvents ?? 0)")
print("Focus hint: \(hsiPayload.behaviorReadings.first(where: { $0.axis == "focus" })?.score ?? 0)")
```

### On-Demand Metrics Calculation

Calculate behavioral metrics for a custom time range within a session:

```swift
// Get events from a session
let events = behavior.getSessionEvents()

// Filter events by time range
let startTime = Date(timeIntervalSince1970: 1767688063)
let endTime = Date(timeIntervalSince1970: 1767688130)
let filteredEvents = events.filter { event in
    let eventDate = Date(timeIntervalSince1970: Double(event.timestamp) / 1000.0)
    return eventDate >= startTime && eventDate <= endTime
}

// Convert to Flux JSON and compute HSI metrics
let fluxJson = convertToFluxSessionJson(
    sessionId: sessionId,
    deviceId: deviceId,
    timezone: timezone,
    startTime: startTime,
    endTime: endTime,
    events: filteredEvents
)

if let hsiJson = FluxBridge.shared.behaviorToHsi(fluxJson) {
    print("HSI metrics computed: \(hsiJson)")
}
```

### Manual Polling

```swift
let stats = try behavior.getCurrentStats()
print("Current typing cadence: \(stats.typingCadence ?? 0)")
print("Scroll velocity: \(stats.scrollVelocity ?? 0)")
print("App switches per minute: \(stats.appSwitchesPerMinute)")
```

## Event Types

The SDK collects six types of behavioral events:

- **Scroll**: Velocity, acceleration, direction, direction reversals (for scroll jitter calculation)
- **Tap**: Duration, long-press detection. **Taps are not counted while the keyboard is open** (when a text field or text view is first responder), so typing interaction is not double-counted as tap events.
- **Swipe**: Direction, distance, velocity, acceleration
- **Notification**: Received, opened, ignored (requires permission)
- **Call**: Answered, ignored, dismissed (requires permission)
- **Typing**: Comprehensive typing session metrics: speed, cadence, burstiness, cadence variability, gap ratio, activity ratio, interaction intensity, deep typing, **backspace/copy/paste/cut counts**. Flux uses these to compute **clipboard_activity_rate** and **correction_rate** in the typing summary (synheart-flux 0.3.0+).

**Note**: App switch events are tracked internally and sent to Flux for task switch calculations, but are not displayed as one of the six event types in event streams or UI. App switch count is available in session summaries.

### Typing: clipboard and correction rates

To get non-zero **clipboard_activity_rate** and **correction_rate** in the session typing summary (from Flux):

- **Backspace/correction**: The SDK infers deletions from text length decrease. **Cut** is not counted as backspace (only actual backspace/delete taps are).
- **Copy/paste/cut**: The SDK does not observe the system clipboard. Call `behavior.recordCopy()`, `behavior.recordPaste()`, or `behavior.recordCut()` when the user performs those actions—e.g. from a custom `UITextField`/`UITextView` that overrides `copy(_:)`, `paste(_:)`, and `cut(_:)`. The Example app uses `BehaviorTrackingTextField` for this; you can use that class or wire the same calls in your own text input.

## Privacy & Compliance

- ✅ **No PII collected**: Only timing-based signals, no personal information
- ✅ **No text content**: Typing events only contain timing metrics (speed, cadence, etc.), not actual text
- ✅ **No screen capture**: No screenshots or screen recording
- ✅ **No app content**: No access to app UI content or data
- ✅ **Fully local processing**: All processing happens on-device
- ✅ **No persistent storage**: Data stored only in memory
- ✅ **No network transmission**: Zero network activity
- ✅ **GDPR/CCPA-ready**: Compliant with privacy regulations
- ✅ **iOS App Tracking Transparency not required**: No tracking identifiers used

## Performance

- <2% CPU usage
- <500 KB memory footprint
- <2% battery overhead
- <1 ms processing latency
- Zero background threads

## Testing

```bash
swift build
swift test
```

## Related Projects

| Repository | Description |
|---|---|
| [synheart-behavior](https://github.com/synheart-ai/synheart-behavior) | Specification & docs (Source of Truth) |
| [synheart-behavior-dart](https://github.com/synheart-ai/synheart-behavior-dart) | Flutter/Dart SDK |
| [synheart-behavior-kotlin](https://github.com/synheart-ai/synheart-behavior-kotlin) | Android/Kotlin SDK |

| [synheart-behavior-chrome](https://github.com/synheart-ai/synheart-behavior-chrome) | Chrome extension |

## Requirements

- iOS 12.0+
- Swift 5.9+
- Xcode 15.0+
- **synheart-flux** 0.1.1+ (required for HSI metrics); 0.3.0+ for typing `clipboard_activity_rate` and `correction_rate`

## Breaking Changes

### Version 0.2.0

- **Clipboard and correction rates**: Typing summary from Flux includes `clipboard_activity_rate` and `correction_rate` (synheart-flux 0.3.0+). Use `recordCopy()`/`recordPaste()`/`recordCut()` for clipboard counts; cut is not counted as backspace. Taps are not counted when the keyboard is open.

### Version 0.1.0

- **Flux is required**: The SDK requires synheart-flux libraries to be present. If Flux is unavailable, session ending will fail with an error
- All behavioral metrics come exclusively from Flux, ensuring HSI compliance and cross-platform consistency

## Example App

A complete example app demonstrating all SDK features is available in the [`Example/`](Example/) directory.

The example app includes:

- Real-time event visualization
- Session management UI
- **BehaviorTrackingTextField** for typing and clipboard (copy/paste/cut) testing
- Time range selection for on-demand metrics
- Comprehensive session results display (including typing clipboard/correction rates)
- HSI JSON output viewing

## API Reference

For detailed API documentation, see the [GitHub repository](https://github.com/synheart-ai/synheart-behavior-swift).

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Apache 2.0 License - see [LICENSE](LICENSE) file for details.

## Author

Israel Goytom

## Links

- 🔗 [GitHub repository](https://github.com/synheart-ai/synheart-behavior-swift)
- 📦 [Swift Package Manager](https://swiftpackageindex.com)

## Patent Pending Notice

This project is provided under an open-source license. Certain underlying systems, methods, and architectures described or implemented herein may be covered by one or more pending patent applications.

Nothing in this repository grants any license, express or implied, to any patents or patent applications, except as provided by the applicable open-source license.
