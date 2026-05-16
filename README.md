# Synheart Behavior


> **Source-available.** This repository is open for reading, auditing, and
> filing issues. We do **not** accept pull requests — see
> [CONTRIBUTING.md](CONTRIBUTING.md) for the rationale and how to contribute
> via issues. Security reports go through [SECURITY.md](SECURITY.md).
> On-device behavioral signal inference from digital interactions for iOS applications

[![CI](https://github.com/synheart-ai/synheart-behavior-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/synheart-ai/synheart-behavior-swift/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen?logo=swift)](https://www.swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Platform](https://img.shields.io/badge/platform-iOS%2012%2B-lightgrey.svg)](https://developer.apple.com/ios/)

A privacy-preserving mobile SDK that collects digital behavioral signals from smartphones. The SDK transforms low-level digital interaction events into structured numerical representations of behavior across event and session. By modeling interaction timing, intensity, fragmentation, and interruption patterns without collecting content or personal data, the SDK provides stable, interpretable metrics to represent digital behavior.

These behavioral signals power downstream systems such as:

- Focus and distraction inference
- Digital wellness analytics
- Cognitive load and fatigue estimation
- Multimodal human state modeling (HSI)

## 🚀 Features

- **Privacy-First**: No text, content, or personally identifiable information (PII) collected—only timing-based signals
- **Real-Time Streaming**: Event callbacks for scroll, tap, swipe, notification, and call interactions
- **Session Tracking**: Built-in session management with comprehensive summaries
- **On-Demand Metrics**: Calculate behavioral metrics for custom time ranges within sessions
- **Swift Package Manager**: Easy integration via SPM, no extra native binaries required
- **System State Tracking**: Internet connectivity, charging state, and device context
- **Minimal Permissions**: No permissions required for basic functionality (scroll, tap, swipe). Optional permissions for notification and call tracking.
- **Platform Support**: iOS 13.0+

## 📦 Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/synheart-ai/synheart-behavior-swift.git", from: "0.4.0")
]
```

Then add `SynheartBehavior` to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "SynheartBehavior", package: "synheart-behavior-swift"),
    ]
)
```

### Xcode

1. File → Add Packages…
2. Enter `https://github.com/synheart-ai/synheart-behavior-swift.git`
3. Select the latest version

### Platform Setup

This SDK is **self-contained** and does **not** require bundling any native binaries or `.xcframework` files.

For optional features (notifications and calls), see the [Permissions](#-permissions) section below.

## 🎯 Quick Start

Here's a complete example to get you started:

```swift
import SwiftUI
import SynheartBehavior

@main
struct MyApp: App {
    @StateObject private var behaviorHost = BehaviorHost()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(behaviorHost)
        }
    }
}

@MainActor
final class BehaviorHost: ObservableObject {
    let behavior: SynheartBehavior
    @Published private(set) var sessionId: String?

    init() {
        let config = BehaviorConfig(
            enableInputSignals: true,
            enableAttentionSignals: true,
            enableMotionLite: false
        )
        self.behavior = SynheartBehavior(config: config)

        do {
            try behavior.initialize()
        } catch {
            print("Init failed: \(error)")
        }

        // Listen to real-time events
        behavior.setEventHandler { event in
            print("Event: \(event.eventType) at \(event.timestamp)")
            print("Payload: \(event.metrics)")
        }
    }

    func startSession() {
        do {
            sessionId = try behavior.startSession()
            print("Session started: \(sessionId ?? "n/a")")
        } catch {
            print("Failed to start session: \(error)")
        }
    }

    func endSession() {
        guard let id = sessionId else { return }
        do {
            let summary = try behavior.endSession(sessionId: id)
            print("Session ended: \(summary.duration)ms")
            print("Total events: \(summary.eventCount)")
            print("App switches: \(summary.appSwitchCount)")
            sessionId = nil
        } catch {
            print("Failed to end session: \(error)")
        }
    }

    deinit {
        behavior.dispose()
    }
}
```

### Key Steps

1. **Initialize the SDK** - Construct `SynheartBehavior(config:)` and call `try initialize()` once during app startup
2. **Listen to Events** - Register a handler with `setEventHandler { … }` for real-time behavioral signals
3. **Track Sessions** - Start and end sessions to get behavioral summaries
4. **Clean Up** - Call `dispose()` when done to free resources

## 📡 Real-Time Event Tracking

The SDK streams behavioral events in real-time as they occur. This is the primary way to track user behavior:

```swift
behavior.setEventHandler { event in
    print("Event: \(event.eventType) at \(event.timestamp)")
    print("Payload: \(event.metrics)")

    switch event.eventType {
    case .scroll:
        let velocity = event.metrics["velocity"] as? Double
        print("Scroll velocity: \(velocity ?? 0) px/s")
    case .tap:
        let duration = event.metrics["tap_duration_ms"] as? Int
        let longPress = event.metrics["long_press"] as? Bool
        print("Tap duration: \(duration ?? 0) ms, long press: \(longPress ?? false)")
    case .swipe:
        let direction = event.metrics["direction"] as? String
        let velocity = event.metrics["velocity"] as? Double
        print("Swipe direction: \(direction ?? "n/a"), velocity: \(velocity ?? 0) px/s")
    case .appSwitch:
        let action = event.metrics["action"] as? String
        print("App switch action: \(action ?? "n/a")")
    default:
        break
    }
}
```

If you prefer to receive events in batches (lower main-thread pressure for large sessions):

```swift
behavior.setBatchEventHandler { events in
    for event in events {
        // process
    }
}
```

## 📊 Event Types

`BehaviorEventType` has **eight canonical values**:
`.scroll, .tap, .swipe, .appSwitch, .notification, .call, .typing,
.clipboard`.

- **.scroll**: Velocity, acceleration, direction, direction reversals
- **.tap**: Duration, long-press detection. **Taps are not counted while the keyboard is open** (when a text field or text view is first responder), so typing interaction is not double-counted as tap events.
- **.swipe**: Direction, distance, velocity, acceleration
- **.appSwitch**: Foreground/background transitions, used for task-switch metrics
- **.notification**: Received, opened, ignored (requires permission)
- **.call**: Answered, ignored, dismissed (requires permission)
- **.typing**: Speed, cadence, gap ratio, backspace count (no content)
- **.clipboard**: Copy / paste / cut event counts (no content)

> This package is the **collector**. Higher-level behavioral metrics
> (focus hint, distraction score, burstiness, etc.) are computed by
> the Synheart Runtime when these events are fed into Synheart Core.

Each event includes:

- `eventId`: Unique identifier
- `sessionId`: Associated session ID
- `timestamp`: ISO 8601 timestamp
- `type`: Event type (`.scroll`, `.tap`, `.swipe`, …)
- `payload`: Event-specific metrics (velocity, duration, etc.)

## 🔐 Permissions

**Note**: Basic functionality (scroll, tap, swipe) requires **no permissions**. The following permissions are optional and only needed for notification and call tracking.

No content-level information is ever collected or stored. For notifications, the SDK does not record notification text, sender identity, application source, or semantic meaning. For phone calls, the SDK does not record audio, voice data, call content, or call participants.

Instead, the SDK records only event-level metadata, such as:

- the occurrence of a notification or call,
- the timestamp of the event,
- and the user's interaction outcome (e.g., opened, dismissed, ignored).

### Notification Permission

Required for tracking notification interactions (received, opened, ignored). On iOS, request notification authorization via `UNUserNotificationCenter` in your host app, then forward the relevant `UNNotificationResponse` events through the SDK if you want fine-grained tracking.

```swift
import UserNotifications

UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
    print("Notification authorization granted: \(granted)")
}
```

### Call Permission

Required for tracking call interactions (answered, ignored). On iOS, the SDK uses `CXCallObserver` from CallKit, which does not require an explicit permission prompt — but your app must declare the appropriate CallKit entitlement and link `CallKit.framework` if you want call metadata in session summaries.

## 🔧 Configuration

### Initial Configuration

Configure the SDK during initialization:

```swift
let config = BehaviorConfig(
    // Enable/disable signal types
    enableInputSignals: true,        // Scroll, tap, swipe gestures
    enableAttentionSignals: true,    // App switching, idle gaps, session stability
    enableMotionLite: true,          // Lightweight on-device motion classification

    // Session configuration
    sessionIdPrefix: "MYAPP",        // Custom session ID prefix (default: "SESS")

    // User/device identifiers (optional, for custom tracking)
    userId: "user_123",              // Optional: custom user identifier
    deviceId: "device_456",          // Optional: custom device identifier

    // SDK configuration
    behaviorVersion: "1.0.0",        // SDK version identifier
    consentBehavior: true,           // Consent flag for behavior tracking

    // Advanced settings
    eventBatchSize: 10,              // Events per batch (default: 10)
    maxIdleGapSeconds: 10.0          // Max idle time before task drop (default: 10.0)
)

let behavior = SynheartBehavior(config: config)
try behavior.initialize()
```

### Update Configuration at Runtime

You can update the configuration after initialization:

```swift
// Disable motion tracking to save battery
try behavior.updateConfig(BehaviorConfig(
    enableInputSignals: true,
    enableAttentionSignals: true,
    enableMotionLite: false
))
```

## 📈 Session Management

### Starting a Session

```swift
// Start with auto-generated session ID
let sessionId = try behavior.startSession()

// Or provide a custom session ID
let sessionId = try behavior.startSession(
    sessionId: "MYAPP-\(Int(Date().timeIntervalSince1970 * 1000))"
)
```

### Ending a Session

When a session ends, you receive a comprehensive summary:

```swift
let summary = try behavior.endSession(sessionId: sessionId)

// Session metadata
print("Session ID: \(summary.sessionId)")
print("Started: \(summary.startTimestamp)")
print("Ended: \(summary.endTimestamp)")
print("Duration: \(summary.duration)ms")

// Activity summary
print("Total Events: \(summary.eventCount)")
print("App Switches: \(summary.appSwitchCount)")

// Top-level shortcuts
print("Stability Index: \(summary.stabilityIndex ?? 0)")
print("Fragmentation Index: \(summary.fragmentationIndex ?? 0)")
print("Avg Scroll Velocity: \(summary.averageScrollVelocity ?? 0)")
print("Avg Typing Cadence: \(summary.averageTypingCadence ?? 0)")

// Behavioral metrics (interactionIntensity, taskSwitchRate, idleRatio,
// burstiness, notificationLoad, scrollJitterRate,
// behavioralDistractionScore, behavioralFocusHint, …)
if let metrics = summary.behavioralMetrics {
    print("Interaction Intensity: \(metrics["interaction_intensity"] ?? 0)")
    print("Distraction Score: \(metrics["behavioral_distraction_score"] ?? 0)")
    print("Focus Hint: \(metrics["behavioral_focus_hint"] ?? 0)")
}

// Typing metrics
if let typing = summary.typingMetrics {
    print("Typing Cadence: \(typing["typing_cadence"] ?? 0)")
    print("Mean Inter-Tap Interval: \(typing["mean_inter_tap_interval_ms"] ?? 0)")
}

// Deep focus blocks
print("Deep Focus Blocks: \(summary.deepFocusBlocks?.count ?? 0)")
```

### On-Demand Metrics Calculation

Calculate behavioral metrics for a custom time range within a session:

```swift
let metrics = try behavior.calculateMetricsForTimeRange(
    startTimestampSeconds: 1767688063,
    endTimestampSeconds: 1767688130,
    sessionId: sessionId
)

if let activity = metrics["activity_summary"] as? [String: Any] {
    print("Total events: \(activity["total_events"] ?? 0)")
    print("App switches: \(activity["app_switch_count"] ?? 0)")
}

if let behavioral = metrics["behavioral_metrics"] as? [String: Any] {
    print("Interaction intensity: \(behavioral["interaction_intensity"] ?? 0)")
    print("Distraction score: \(behavioral["behavioral_distraction_score"] ?? 0)")
}
```

**Note**: The time range must be within the session's start and end times. The SDK validates this automatically and will throw an error if the range is out of bounds.

### Current Statistics

Get real-time statistics without ending a session:

```swift
let stats = try behavior.getCurrentStats()
print("Typing cadence: \(stats.typingCadence ?? 0)")
print("Scroll velocity: \(stats.scrollVelocity ?? 0)")
print("App switches per minute: \(stats.appSwitchesPerMinute)")
print("Stability index: \(stats.stabilityIndex ?? 0)")
```

### Session Status

```swift
// Check current active session
if let currentSessionId = behavior.getCurrentSessionId() {
    print("Active session: \(currentSessionId)")
}

// Inspect events captured in the current session
let events = behavior.getSessionEvents()
print("Events so far: \(events.count)")
```

### Core Behavioral Metrics

Session-level outputs include:

- `interaction_intensity`: Overall interaction rate and engagement
- `behavioral_distraction_score`: Behavioral proxy for distraction (0-1)
- `behavioral_focus_hint`: Behavioral proxy for focus quality (0-1)
- `task_switch_rate`: Frequency of app switching
- `idle_ratio`: Proportion of idle time vs active interaction
- `fragmented_idle_ratio`: Ratio of fragmented vs continuous idle periods
- `burstiness`: Temporal clustering of interaction events
- `notification_load`: Notification pressure and response patterns
- `scroll_jitter_rate`: Scroll pattern irregularity

Plus `deep_focus_blocks` (a list of sustained-engagement windows) on the summary itself.

All metrics are bounded, normalized, and numerically stable.

## ⚙️ Additional Features

### Custom Event Sending

You can manually send events to the SDK. Only the predefined event types are supported (scroll, tap, swipe, notification, call, typing, clipboard, appSwitch):

```swift
let event = BehaviorEvent.tap(
    sessionId: behavior.getCurrentSessionId() ?? "current",
    tapDurationMs: 120,
    longPress: false
)

behavior.sendEvent(event)
```

Each event type has a corresponding factory on `BehaviorEvent` (`.scroll(...)`, `.tap(...)`, `.swipe(...)`, `.notification(...)`, `.call(...)`, `.typing(...)`, `.clipboard(...)`, `.appSwitch(...)`).

### Cleanup

Always dispose of the SDK when done to free resources:

```swift
deinit {
    behavior.dispose()
}
```

## 🔒 Privacy & Compliance

The Synheart SDK is designed around privacy-by-design and data minimization principles. It captures only the minimum interaction metadata required to model digital behavior, without accessing personal, semantic, or content-level information.

### Hard Guarantees

✅ **No PII**: The SDK does not collect names, contacts, account identifiers, message content, or any user-identifying data. All signals are timing-based and structural.

✅ **No content capture**: The SDK does not collect notification text/titles/sender identity, call audio/voice data/participants, or application UI content/screen data.

✅ **No keystroke logging**: Text input is never recorded. Interactions with text fields are captured only as abstract tap events (timing and duration only), without any character-level data.

✅ **No audio or visual recording**: The SDK does not access the screen buffer, screenshots, camera, microphone, or any form of visual/audio capture.

✅ **Permission-scoped tracking only**: Behavioral data is collected exclusively from applications that explicitly receive user permission. The SDK does not monitor, infer, or aggregate behavior across the entire device or across unpermitted applications.

✅ **No tracking across unconsented apps**: The SDK only tracks behavior within the app that integrates it and has received user consent.

✅ **Event-level metadata only**: Collected data is limited to event type (tap, scroll, swipe, notification, call), timestamp, and non-semantic physical metrics (duration, velocity). No semantic interpretation is performed at the data collection stage.

### Connectivity & System Access

✅ **No internet connectivity required**: The SDK functions fully offline and does not require an active internet connection to perform behavioral capture or inference.

✅ **Network availability state only**: The SDK may record a binary system-level indicator of whether network connectivity is present at a given time. This signal does not include network traffic, destinations, IPs, or content, does not trigger any data transmission, and is used solely as contextual metadata.

✅ **No Bluetooth or external connectivity required**: The SDK does not depend on Bluetooth, NFC, or communication with external devices.

✅ **No background network communication**: Behavioral computation and aggregation occur locally without initiating network requests. Any optional data transmission is explicitly controlled, consent-gated, and configurable.

### Processing & Storage

✅ **On-device computation by default**: Behavioral features and metrics are computed locally on the device, minimizing data exposure.

✅ **Ephemeral data handling**: Raw interaction events are processed in-memory and are not persisted in long-term storage unless explicitly configured for research or debugging purposes.

✅ **No third-party data sharing**: The SDK does not share raw or derived behavioral data with advertisers, analytics providers, or external third parties.

### Regulatory alignment

The SDK is designed around the principles of data minimization,
purpose limitation, user consent, and transparency. See the
[privacy audit](https://docs.synheart.ai/privacy/behavior) for the
detailed static-review notes. This is a self-assessment, not a
third-party certification — legal sufficiency for your specific
deployment depends on how you wire consent in your host app.

The SDK does not track users across apps, does not collect device
identifiers, and does not share data with ad-network brokers. Whether
your host app needs to present an ATT prompt depends on the rest of
the app's behavior, not on this SDK alone.

## 📱 Platform Support

- ✅ **iOS**: Swift 5.9+, iOS 13.0+
- ✅ **Build**: Xcode 15.0+, Swift Package Manager

## ⚡ Performance

The SDK is designed for continuous background operation with minimal
resource impact: events are processed on background queues, and there
is no persistent storage layer to flush. Specific CPU / memory /
battery numbers are deployment-dependent — earlier docs published
fixed targets, but those were design goals, not measured runtime
numbers. Profile your integration with Instruments on the iOS device
class you ship.

## 🏗️ Architecture

```text
┌──────────────────────────────────────────────────────┐
│                    Your iOS App                       │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │           SynheartBehavior SDK                   │  │
│  │                                                  │  │
│  │  BehaviorConfig ──► SynheartBehavior(config:)    │  │
│  │                           │                      │  │
│  │       ┌───────────────────┼───────────────┐      │  │
│  │       ▼                   ▼               ▼      │  │
│  │  InputSignal      ScrollSignal       Attention   │  │
│  │  Collector        Collector          Collector   │  │
│  │  (typing, taps,   (scroll dynamics)  (app switch,│  │
│  │   gestures)                          idle, notif)│  │
│  │       │                   │               │      │  │
│  │       └─────────┬─────────┘───────────────┘      │  │
│  │                 ▼                                 │  │
│  │          EventBatcher ──► Event Handlers          │  │
│  │                 │                                 │  │
│  │                 ▼                                 │  │
│  │     SessionManager ──► BehaviorSessionSummary     │  │
│  └─────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
         │
         ▼ (events forwarded to Synheart Core for HSI ingestion)
```

Signals flow: **Collectors → EventBatcher → SessionManager → Summary**.
The SDK never generates HSI directly — it collects and normalizes behavioral signals.

## 🧪 Testing

```bash
swift build
swift test
```

Tests are in `Tests/SynheartBehaviorTests/` covering models (config, event, session, stats), SDK initialization, and event factories.

## 📋 Requirements

- **Swift**: 5.9+
- **Xcode**: 15.0+
- **iOS**: 12.0+

## 🔍 Troubleshooting

### SDK Not Initializing

**Problem**: `try behavior.initialize()` throws.

**Solutions**:

- Make sure you only call `initialize()` once per `SynheartBehavior` instance.
- Verify the iOS deployment target meets the requirement (12.0+).
- Catch and log the underlying `BehaviorError` — `.invalidConfiguration` indicates a config issue, `.notInitialized` means another call slipped in before init completed.

### No Events Being Collected

**Problem**: The event handler is not firing.

**Solutions**:

- Confirm `setEventHandler(_:)` was called after `initialize()`.
- Verify a session is started with `try behavior.startSession()`.
- Check that `enableInputSignals` or `enableAttentionSignals` is `true` in your config.
- For notifications/calls, ensure permissions are granted in the host app.

### Permission Requests Not Working

**Problem**: Notification or call events never arrive.

**Solutions**:

- **Notifications**: ensure `UNUserNotificationCenter` authorization was granted and forward `UNNotificationResponse` outcomes through the SDK's notification factory.
- **Calls**: link `CallKit.framework` and confirm the app has the appropriate CallKit entitlement.
- Test on a real device — the iOS simulator does not deliver call events.

### Session End Fails

**Problem**: `try behavior.endSession(sessionId:)` throws `.sessionNotFound` or another error.

**Solutions**:

- Make sure you pass the same `sessionId` returned by `startSession()`.
- Sessions are tracked by ID, not as opaque handles — keep that ID alive on your side.
- Wrap end-session calls in `do/catch` and log the error type.

### Build Errors

```bash
swift package reset
swift package update
swift build
```

If Xcode complains about resolution, close Xcode, delete `.swiftpm/` and `~/Library/Developer/Xcode/DerivedData/<your-app>-*`, then re-resolve.

## 🧪 Example App

A complete example app demonstrating all SDK features is available in the [`Example/`](Example/) directory.

To run the example:

```bash
cd Example
xcodegen generate    # if you use XcodeGen with project.yml
open ExampleApp.xcodeproj
```

The example app includes:

- Real-time event visualization
- Session management UI
- Time-range selection for on-demand metrics
- Comprehensive session results display

## 📚 API Reference

### SynheartBehavior

```swift
public class SynheartBehavior {
    public init(config: BehaviorConfig)
    public func initialize() throws
    public func dispose()

    // Sessions
    public func startSession(sessionId: String? = nil) throws -> String
    public func endSession(sessionId: String) throws -> BehaviorSessionSummary
    public func getCurrentSessionId() -> String?
    public func getSessionEvents() -> [BehaviorEvent]
    public func getCurrentStats() throws -> BehaviorStats

    // Events
    public func setEventHandler(_ handler: @escaping (BehaviorEvent) -> Void)
    public func setBatchEventHandler(_ handler: @escaping ([BehaviorEvent]) -> Void)
    public func sendEvent(_ event: BehaviorEvent)

    // On-demand metrics
    public func calculateMetricsForTimeRange(
        startTimestampSeconds: Int,
        endTimestampSeconds: Int,
        sessionId: String?
    ) throws -> [String: Any]

    // Configuration
    public func updateConfig(_ config: BehaviorConfig) throws
}
```

### Key Types

| Type | Description |
|---|---|
| `BehaviorConfig` | SDK configuration (signals, batching, consent) |
| `BehaviorEvent` | Single behavioral event with type and payload |
| `BehaviorEventType` | `.scroll`, `.tap`, `.swipe`, `.notification`, `.call`, `.typing`, `.clipboard`, `.appSwitch` |
| `BehaviorSession` | Active session handle (returned by `startSession()`'s session id) |
| `BehaviorSessionSummary` | Aggregated session metrics (activity, behavioral, typing, deep focus blocks) |
| `BehaviorStats` | Real-time metrics snapshot (cadence, velocity, stability) |
| `BehaviorError` | `.notInitialized`, `.invalidConfiguration`, `.sessionNotFound` |

## 📚 Documentation

Full reference docs live at **[docs.synheart.ai/synheart-behavior/swift](https://docs.synheart.ai/synheart-behavior/swift)** — metric definitions, model card, threat model, error reference, and the cross-platform overview.

## Contributing

This is a source-available repository. Issues and feature requests are
welcome; pull requests are not accepted at this time. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the rationale and the supported
contribution path.

## 📄 License

Apache 2.0 License - see [LICENSE](LICENSE) file for details.

## 🔗 Links

- 📦 [Swift Package Index](https://swiftpackageindex.com/synheart-ai/synheart-behavior-swift)
- 🔗 [GitHub repository](https://github.com/synheart-ai/synheart-behavior-swift)
- 🔗 [Parent specification repository](https://github.com/synheart-ai/synheart-behavior)
- 📖 [Example App Guide](Example/GUIDE.md)
- 🔒 [Privacy audit](https://docs.synheart.ai/privacy/behavior)

## 🔗 Related Projects

| Repository | Description |
|---|---|
| [synheart-behavior](https://github.com/synheart-ai/synheart-behavior) | Specification & docs (Source of Truth) |
| [synheart-behavior-flutter](https://github.com/synheart-ai/synheart-behavior-flutter) | Flutter/Dart SDK |
| [synheart-behavior-kotlin](https://github.com/synheart-ai/synheart-behavior-kotlin) | Android/Kotlin SDK |
| [synheart-behavior-chrome](https://github.com/synheart-ai/synheart-behavior-chrome) | Chrome extension |

## Patent Pending Notice

This project is provided under an open-source license. Certain underlying systems, methods, and architectures described or implemented herein may be covered by one or more pending patent applications.

Nothing in this repository grants any license, express or implied, to any patents or patent applications, except as provided by the applicable open-source license.

## Not a Medical Device

This SDK is intended for wellness and research use only. It is not a medical device, is not intended to diagnose, treat, cure, or prevent any disease or condition, and has not been evaluated by the FDA or any other regulatory body.
