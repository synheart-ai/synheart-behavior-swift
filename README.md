# Synheart Behavioral SDK for iOS

A lightweight, privacy-preserving iOS SDK that collects digital behavioral signals from smartphones. These signals represent biobehavioral markers strongly correlated with cognitive and emotional states, especially focus, stress, engagement, and fatigue.

## Features

- 🎯 **Privacy-First**: No text, content, or PII collected - only timing-based signals
- ⚡ **Lightweight**: <150 KB compiled, <2% CPU usage, <500 KB memory footprint
- 🔄 **Event Streaming**: Real-time event callbacks for behavioral signals
- 📊 **Session Tracking**: Built-in session management with summaries
- 🎨 **Swift Package Manager**: Easy integration via SPM

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/synheart-ai/synheart-behavior-swift.git", from: "1.0.0")
]
```

Or add via Xcode:
1. File → Add Packages...
2. Enter: `https://github.com/synheart-ai/synheart-behavior-swift.git`
3. Select version: `1.0.0`

## Usage

### Initialization

```swift
import SynheartBehavior

let config = BehaviorConfig(
    enableInputSignals: true,
    enableAttentionSignals: true,
    enableMotionLite: false
)

let behavior = SynheartBehavior(config: config)
try behavior.initialize()
```

### Event Handling

```swift
behavior.setEventHandler { event in
    print("Event type: \(event.type)")
    print("Payload: \(event.payload)")
    print("Timestamp: \(event.timestamp)")
}
```

### Session Tracking

```swift
let sessionId = try behavior.startSession()

// ... user interacts with app ...

let summary = try behavior.endSession(sessionId: sessionId)
print("Session duration: \(summary.duration)ms")
print("Total events: \(summary.eventCount)")
```

### Manual Polling

```swift
let stats = try behavior.getCurrentStats()
print("Current typing cadence: \(stats.typingCadence ?? 0)")
print("Scroll velocity: \(stats.scrollVelocity ?? 0)")
```

## Privacy & Compliance

- ✅ No PII collected
- ✅ No keystroke content
- ✅ No screen capture
- ✅ No app content
- ✅ Fully local processing
- ✅ GDPR/CCPA-ready
- ✅ iOS App Tracking Transparency not required

## Performance

- <2% CPU usage
- <500 KB memory footprint
- <2% battery overhead
- <1 ms processing latency
- Zero background threads

## Requirements

- iOS 12.0+
- Swift 5.0+
- Xcode 12.0+

## License

MIT License

## Author

Israel Goytom

## Patent Pending Notice

This project is provided under an open-source license. Certain underlying systems, methods, and architectures described or implemented herein may be covered by one or more pending patent applications.

Nothing in this repository grants any license, express or implied, to any patents or patent applications, except as provided by the applicable open-source license.
