# Example App Guide

## Running and Testing Real Behavioral Signal Collection

This guide shows you how to run the example app and verify that behavioral signals are being collected in real-time.

---

## Prerequisites

### Software Requirements

- macOS 13+ (Ventura or newer)
- Xcode 15.0+ with the iOS SDK installed
- Swift 5.9+
- iOS Simulator or a physical iOS device on iOS 12.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (only needed if you want
  to regenerate `ExampleApp.xcodeproj` from `project.yml`)

### Installation Check

```bash
# Verify Xcode is installed and selected
xcodebuild -version

# Expected output should show:
# Xcode 15.x
# Build version 15Xxxx

# Verify Swift toolchain
swift --version

# Verify XcodeGen (optional)
which xcodegen
```

---

## Running the Example App

### Option 1: Run on iOS Simulator

#### Step 1: Navigate to Example Directory

```bash
cd Example
```

#### Step 2: Generate the Xcode Project (first time only)

The example uses XcodeGen to keep `ExampleApp.xcodeproj` reproducible. If
the project is missing or you change `project.yml`, regenerate it:

```bash
xcodegen generate
```

If the `.xcodeproj` is already committed and you do not need to change the
project graph, you can skip this step.

#### Step 3: Open the Project in Xcode

```bash
open ExampleApp.xcodeproj
```

#### Step 4: Pick a Simulator and Run

1. In Xcode, select the **ExampleApp** scheme.
2. Pick an iOS Simulator destination (e.g. *iPhone 15 Pro*).
3. Press `Cmd+R` to build and run.

#### Step 5: Observe Logs (Optional)

In a separate terminal, stream simulator logs filtered to the example app:

```bash
xcrun simctl spawn booted log stream \
    --predicate 'process == "ExampleApp"' \
    --level debug
```

---

### Option 2: Run on a Physical Device

#### Step 1: Connect the Device

Plug in an iPhone or iPad on iOS 12.0+ and trust the host Mac.

#### Step 2: Configure Signing

In Xcode:

1. Select the **ExampleApp** target.
2. Open **Signing & Capabilities**.
3. Set **Team** to your Apple Developer team.
4. Update the **Bundle Identifier** if `ai.synheart.behavior.example` is
   already taken on your account.

#### Step 3: Pick the Device and Run

1. Select your physical device from the destination dropdown.
2. Press `Cmd+R`. Xcode will install and launch the app.

#### Step 4: Observe Device Logs (Optional)

```bash
# Tail device logs from the Console app or:
log stream --device --predicate 'process == "ExampleApp"' --level debug
```

---

## Using the Example App

### App Interface

When the app launches, you'll see `MainViewController`, which contains:

1. **SDK Status Card**

   - Shows if the SDK is initialized
   - Displays the current active session ID

2. **Control Buttons**

   - **Start Session**: Begin a new behavioral tracking session
   - **End Session**: Stop current session and push `SessionResultsViewController`
   - **Refresh Stats**: Pull the current rolling statistics via
     `try behavior.getCurrentStats()`

3. **Permission Buttons**

   - **Request Notification Permission**: optional, only needed for
     `.notification` events
   - **Request Call Permission**: optional, only needed for `.call` events

4. **Current Stats Card**

   - Shows real-time behavioral metrics from `BehaviorStats`:
     - Scroll Velocity
     - App Switches per minute
     - Stability Index

5. **Typing Test Card**

   - A `BehaviorTrackingTextField` (a custom `UITextField` subclass)
   - Use it to generate typing-related interaction events

6. **Test Items List**

   - Ten scrollable cards for exercising scroll dynamics, taps, and swipes

After ending a session, the app navigates to `SessionResultsViewController`,
which displays the `BehaviorSessionSummary` returned by
`try behavior.endSession(sessionId:)`.

---

## Testing Behavioral Signal Collection

**Important**: The SDK emits **real-time events** (scroll, tap, swipe,
typing, clipboard, app switch, notification, call) via the handler you
register with `behavior.setEventHandler { event in … }`. Aggregated
statistics (scroll velocity averages, app switches per minute, stability
index, etc.) are computed from these events and available via
`try behavior.getCurrentStats()`. The tests below show both individual
events and aggregated statistics.

### Test 1: Tap Gesture Signals

**Objective**: Verify tap gesture detection and timing

**Steps**:

1. Tap **"Start Session"**
2. Tap various buttons and UI elements in the app
3. Try both quick taps and long-press gestures
4. Watch the event count and the **Recent Events** counter update

**Expected Events**:

- `.tap` events — each tap generates an event with duration and long-press
  detection. Taps are *not* counted while the keyboard is open, so typing
  inside the text field is reported as `.typing`, not `.tap`.

**Expected Event Payload**:

```swift
behavior.setEventHandler { event in
    guard event.type == .tap else { return }
    let duration  = event.payload["tap_duration_ms"] as? Int   // 120
    let longPress = event.payload["long_press"]    as? Bool    // false
    print("Tap: \(duration ?? 0) ms, long-press: \(longPress ?? false)")
}
```

**Note**: Tap rate, when available, is exposed through
`BehaviorStats` rather than as its own event.

**Privacy Check**: The event contains NO coordinates and NO content,
only timing.

---

### Test 2: Scroll Dynamics Signals

**Objective**: Verify scroll velocity, acceleration, and direction tracking

**Steps**:

1. Ensure a session is active
2. Scroll the main view **slowly**
3. Then scroll **quickly**
4. Try **jerky** scrolling (start-stop-start)
5. Tap **"Refresh Stats"** to inspect the rolling scroll velocity

**Expected Events**:

- `.scroll` events — emitted while the user is scrolling, with velocity,
  acceleration, direction, and direction-reversal metrics

**Expected Event Payload**:

```swift
behavior.setEventHandler { event in
    guard event.type == .scroll else { return }
    let velocity     = event.payload["velocity"]            as? Double // 150.5
    let acceleration = event.payload["acceleration"]        as? Double // 25.3
    let direction    = event.payload["direction"]           as? String // "down"
    let reversal     = event.payload["direction_reversal"]  as? Bool   // false
    print("Scroll v=\(velocity ?? 0) a=\(acceleration ?? 0) dir=\(direction ?? "?")")
}
```

**Note**: Scroll jitter and aggregated scroll statistics are derived from
these events and surfaced through `try behavior.getCurrentStats()`.

**Privacy Check**: No screen coordinates — only velocity magnitude
and direction.

---

### Test 3: Tap and Swipe Gestures

**Objective**: Verify tap and swipe gesture detection together

**Steps**:

1. Tap various buttons **quickly** (multiple times in succession)
2. **Long-press** on UI elements
3. **Swipe** across the test items list horizontally and vertically
4. Watch events arrive in your handler

**Expected Tap Event Payload**:

```swift
{
    "event_type": "tap",
    "metrics": {
        "tap_duration_ms": 150,
        "long_press": false
    }
}
```

**Expected Swipe Event Payload**:

```swift
{
    "event_type": "swipe",
    "metrics": {
        "direction": "left",
        "distance_px": 250.5,
        "duration_ms": 300,
        "velocity": 835.0,
        "acceleration": 120.5
    }
}
```

**Note**: Tap rate is computed from tap events and is reflected in the
session summary returned by `endSession(sessionId:)`.

**Privacy Check**: No tap or swipe coordinates — only timing and
movement magnitudes.

---

### Test 4: Typing Signals

**Objective**: Verify typing-related events without recording any
characters

**Steps**:

1. Tap into the **Typing Test** text field (`BehaviorTrackingTextField`)
2. Type a short sentence at a comfortable pace
3. Try a fast burst followed by a long pause
4. Hit backspace several times to delete characters

**Expected Events**:

- `.typing` events — describe typing cadence and gap structure, never
  the characters that were typed

**Expected Event Payload**:

```swift
behavior.setEventHandler { event in
    guard event.type == .typing else { return }
    let cadence  = event.payload["typing_cadence"]            as? Double
    let gapRatio = event.payload["gap_ratio"]                 as? Double
    let backsp   = event.payload["backspace_count"]           as? Int
    print("Typing cadence=\(cadence ?? 0), backspaces=\(backsp ?? 0)")
}
```

**About `BehaviorTrackingTextField`**: this is a thin
`UITextField` subclass shipped with the example to show how a host app
can adopt a typing-event-emitting input. You can drop the same subclass
(or a `UITextView` equivalent) into your own UIKit screens — the SDK
treats the field's contents as opaque.

**Privacy Check**: No keystroke content. The event carries only timing
and structural metrics.

---

### Test 5: App Lifecycle Signals

**Objective**: Verify foreground/background detection

**Steps**:

1. Ensure a session is active
2. Press the device **Home button** (or swipe up)
3. Wait 5 seconds
4. Return to the app
5. Tap **"Refresh Stats"**

**Expected Events**:

- `.appSwitch` events — a foreground or background transition; useful
  for task-switch metrics

**Expected Event Payload**:

```swift
behavior.setEventHandler { event in
    guard event.type == .appSwitch else { return }
    let action = event.payload["action"] as? String  // "foreground" / "background"
    print("App switch: \(action ?? "?")")
}
```

**Expected Stats** (from `try behavior.getCurrentStats()`):

```swift
let stats = try behavior.getCurrentStats()
print(stats.appSwitchesPerMinute)        // 2
```

The session summary from `try behavior.endSession(sessionId:)` includes
`appSwitchCount` for the whole session.

---

### Test 6: Idle Gap Detection

**Objective**: Verify idle state detection

**Steps**:

1. Start a session
2. **Stop interacting** with the device completely
3. Wait through a few thresholds:
   - 2 seconds (micro idle)
   - 5 seconds (mid idle)
   - 12 seconds (task-drop idle, governed by `maxIdleGapSeconds`)
4. Tap **"Refresh Stats"** to inspect the current idle metrics

**Note**: Idle gaps are tracked internally and surfaced through
`BehaviorStats` and the session summary, not as standalone events.

**Expected Stats**:

```swift
let stats = try behavior.getCurrentStats()
// inspect stats.stabilityIndex, stats.appSwitchesPerMinute, etc.
```

The default idle threshold is `BehaviorConfig(maxIdleGapSeconds: 10.0)`
— change it on the config if your host app needs a different cutoff.

---

### Test 7: Session Stability Metrics

**Objective**: Verify stability and fragmentation calculation

**Steps**:

1. Start a session
2. Use the app **steadily** for ~2 minutes
3. Switch between the example app and the home screen 2–3 times
4. Tap **"Refresh Stats"**
5. Inspect the stability index

**Expected Stats**:

```swift
let stats = try behavior.getCurrentStats()
print(stats.stabilityIndex ?? 0)         // e.g. 0.85, range 0.0–1.0
```

**Interpretation**:

- **High stability** (>0.8): the user is focused, with few interruptions
- **Low stability** (<0.5): the user is distracted, with many app
  switches

---

### Test 8: Session Summary

**Objective**: Verify session summary generation

**Steps**:

1. Start a session
2. Interact with the app for 1–2 minutes:
   - Scroll the view
   - Tap buttons
   - Perform swipe gestures
   - Type into the text field
   - Background and foreground the app once or twice
3. Tap **"End Session"**
4. Review `SessionResultsViewController`

**Reading the summary**:

```swift
let summary = try behavior.endSession(sessionId: id)

print("Session ID:        \(summary.sessionId)")
print("Started:           \(summary.startTimestamp)")
print("Ended:             \(summary.endTimestamp)")
print("Duration (ms):     \(summary.duration)")
print("Event Count:       \(summary.eventCount)")
print("App Switch Count:  \(summary.appSwitchCount)")
print("Stability Index:   \(summary.stabilityIndex   ?? 0)")
print("Fragmentation:     \(summary.fragmentationIndex ?? 0)")
print("Avg Scroll v:      \(summary.averageScrollVelocity ?? 0)")
print("Avg Typing Cadence:\(summary.averageTypingCadence  ?? 0)")
```

The summary view also displays:

- **Activity Summary** — total events, app switches, scroll/tap/swipe
  counts derived from `summary.eventCount` and the events captured
  during the session
- **Behavior Metrics** — read from `summary.behavioralMetrics`
  (interaction intensity, distraction score, focus hint, …)
- **Typing Session Summary** — read from `summary.typingMetrics`
- **Deep Focus Blocks** — a list of sustained-engagement windows from
  `summary.deepFocusBlocks`

---

## Verifying Data Privacy

### What You Should SEE in Events

Event types delivered to your handler:

- `.scroll` — payload: `velocity`, `acceleration`, `direction`,
  `direction_reversal`
- `.tap` — payload: `tap_duration_ms`, `long_press`
- `.swipe` — payload: `direction`, `distance_px`, `duration_ms`,
  `velocity`, `acceleration`
- `.typing` — payload: `typing_cadence`, `gap_ratio`,
  `backspace_count`, …
- `.clipboard` — payload: copy / paste / cut counts (no content)
- `.appSwitch` — payload: `action`
- `.notification` — payload: `action` (requires permission)
- `.call` — payload: `action` (requires permission)

Aggregated statistics from `try behavior.getCurrentStats()`:

- `scrollVelocity`: pixels per second
- `appSwitchesPerMinute`: integer count
- `stabilityIndex`: 0.0–1.0, higher = more stable
- `typingCadence`: characters per second
- plus other rolling metrics surfaced on `BehaviorStats`

Aggregated statistics on `BehaviorSessionSummary` (returned from
`endSession(sessionId:)`):

- `eventCount`, `appSwitchCount`, `duration`
- `stabilityIndex`, `fragmentationIndex`
- `averageScrollVelocity`, `averageTypingCadence`
- `behavioralMetrics`, `typingMetrics`, `deepFocusBlocks`

### What You Should NOT SEE

**Text Content**:

- No character data
- No string values from text fields
- No field names

**Screen Coordinates**:

- No X/Y positions
- No pixel locations
- No UI element identifiers

**Identifiers**:

- No advertising IDs
- No IDFV/IDFA
- No raw user IDs (unless you set `userId` on `BehaviorConfig`
  yourself)

**System Information**:

- No other app names
- No bundle identifiers from outside the host app
- No file paths

**Privacy Verification**: If you see ANY of the above in an event
payload, please file a bug report against the SDK.

---

## Performance Verification

### Monitor App Performance

While using the example app, profile it with Xcode Instruments:

1. **Product** → **Profile** (`Cmd+I`) in Xcode
2. Pick the **Time Profiler** template (or **Allocations** for memory)
3. Run a 1–2 minute session in the app
4. Inspect CPU usage and allocations attributed to `SynheartBehavior`

For battery and energy impact:

1. Open Xcode while the app is running on a device
2. **Window** → **Devices and Simulators** → your device → **Open Console**
3. Filter on `process == "ExampleApp"`
4. Watch for memory or CPU warnings

Profile your own host app for ground-truth CPU and memory numbers —
values vary with config (which signals are enabled, how many events the
host handler emits per second) and the device class.

**What to watch for**:

- No lag in UI interactions while the SDK is collecting.
- CPU and memory deltas stay within whatever budget your host app has
  allocated for telemetry.

---

## Troubleshooting

### Problem: No Events Appearing

**Possible Causes**:

1. The session was never started
2. `setEventHandler` was registered before `initialize()` returned
3. `enableInputSignals` / `enableAttentionSignals` is `false` in your
   `BehaviorConfig`

**Solution**:

```swift
let config   = BehaviorConfig(
    enableInputSignals: true,
    enableAttentionSignals: true,
    enableMotionLite: false
)
let behavior = SynheartBehavior(config: config)

do {
    try behavior.initialize()
    behavior.setEventHandler { event in
        print("Event: \(event.type), payload: \(event.payload)")
    }
    let sessionId = try behavior.startSession()
    print("Session: \(sessionId)")
} catch {
    print("SDK setup failed: \(error)")
}
```

If the handler still doesn't fire, log every `BehaviorError` you catch
— `.invalidConfiguration` and `.notInitialized` are the two failures
that silently break event delivery.

### Problem: Build Errors

**Swift Package resolution stuck**:

```bash
# In the Example directory:
rm -rf .build
rm -rf ~/Library/Developer/Xcode/DerivedData/ExampleApp-*
xcodegen generate
open ExampleApp.xcodeproj
```

Then in Xcode, **File** → **Packages** → **Reset Package Caches**.

**`SynheartBehavior` not found**:

The example uses a local Swift Package reference (`packages.SynheartBehavior.path`
in `project.yml`). Make sure you opened `Example/ExampleApp.xcodeproj`
*from inside the Example directory* — opening it through a copied path
breaks the relative `../` dependency.

### Problem: Events Stop After Backgrounding

iOS suspends most user-interaction tracking when the app is backgrounded.
The SDK records the `.appSwitch` transition but does not collect events
from outside your app — that's by design.

If the app is killed by the system while a session is active, the
session ID is lost. Persist the session ID returned by
`startSession()` if you need durability across launches, and pass it
back to `startSession(sessionId:)` to resume tracking under the same
session.

### Problem: `endSession(sessionId:)` Throws

`BehaviorError.sessionNotFound` is the most common cause. Double-check
that:

- you're passing the same `sessionId` returned from `startSession()`,
  and
- you're not calling `endSession` twice in a row (the second call has
  no session to end).

Wrap calls in `do/catch` and switch on `BehaviorError`:

```swift
do {
    let summary = try behavior.endSession(sessionId: id)
    // …
} catch let error as BehaviorError {
    switch error {
    case .notInitialized:        print("SDK not initialized")
    case .invalidConfiguration:  print("Invalid configuration")
    case .sessionNotFound:       print("Session not found")
    @unknown default:            print("Unknown BehaviorError: \(error)")
    }
} catch {
    print("Other error: \(error)")
}
```

---

## Expected Output Examples

### Console Log (Successful Run)

```
Synheart Behavior SDK Initialized
  Config: enableInputSignals=true, enableAttentionSignals=true, enableMotionLite=false

Session Started: SESS-1705234567890

Event: tap
  Payload: ["tap_duration_ms": 120, "long_press": false]

Event: scroll
  Payload: ["velocity": 150.5, "acceleration": 25.3, "direction": "down", "direction_reversal": false]

Event: swipe
  Payload: ["direction": "left", "distance_px": 250.5, "duration_ms": 300, "velocity": 835.0, "acceleration": 120.5]

Event: typing
  Payload: ["typing_cadence": 4.2, "gap_ratio": 0.18, "backspace_count": 1]

Event: appSwitch
  Payload: ["action": "background"]

Session Ended: SESS-1705234567890
  Duration: 120000ms
  Events: 87
  App Switches: 2
  Stability: 0.85
```

### Event Stream (Real-time)

```json
[
  {
    "event_id":   "evt_1705234567890",
    "session_id": "SESS-1705234567890",
    "timestamp":  "2025-01-15T10:15:23.456Z",
    "event_type": "tap",
    "metrics": {
      "tap_duration_ms": 120,
      "long_press": false
    }
  },
  {
    "event_id":   "evt_1705234568100",
    "session_id": "SESS-1705234567890",
    "timestamp":  "2025-01-15T10:15:25.100Z",
    "event_type": "scroll",
    "metrics": {
      "velocity": 150.5,
      "acceleration": 25.3,
      "direction": "down",
      "direction_reversal": false
    }
  },
  {
    "event_id":   "evt_1705234570000",
    "session_id": "SESS-1705234567890",
    "timestamp":  "2025-01-15T10:15:40.000Z",
    "event_type": "swipe",
    "metrics": {
      "direction": "left",
      "distance_px": 250.5,
      "duration_ms": 300,
      "velocity": 835.0,
      "acceleration": 120.5
    }
  }
]
```

---

## Next Steps

After successfully running the example app:

1. **Verify All Signal Types** — confirm each `BehaviorEventType` you
   care about is being delivered to your handler
2. **Privacy Check** — confirm no sensitive data appears in any event
   payload
3. **Performance Check** — profile CPU and memory with Instruments
4. **Integration** — adopt the SDK in your own app
5. **Customization** — tune `BehaviorConfig` for your needs

---

## Integration into Your App

Once you've verified the example app works, here's the minimum
integration for a UIKit host app:

```swift
import UIKit
import SynheartBehavior

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var behavior: SynheartBehavior?
    var sessionId: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let config = BehaviorConfig(
            enableInputSignals: true,
            enableAttentionSignals: true,
            enableMotionLite: false
        )
        let behavior = SynheartBehavior(config: config)
        self.behavior = behavior

        do {
            try behavior.initialize()

            behavior.setEventHandler { event in
                // Send to your analytics backend
                print("Event: \(event.type), payload: \(event.payload)")
            }

            sessionId = try behavior.startSession()
        } catch {
            print("SDK setup failed: \(error)")
        }

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(
            rootViewController: RootViewController()
        )
        window?.makeKeyAndVisible()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        if let id = sessionId {
            _ = try? behavior?.endSession(sessionId: id)
        }
        behavior?.dispose()
    }
}
```

For a SwiftUI host app, hold the SDK in an `ObservableObject` so views
can observe session state:

```swift
import SwiftUI
import SynheartBehavior

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
            behavior.setEventHandler { event in
                print("Event: \(event.type)")
            }
        } catch {
            print("Init failed: \(error)")
        }
    }

    func startSession() {
        do {
            sessionId = try behavior.startSession()
        } catch {
            print("Start failed: \(error)")
        }
    }

    func endSession() {
        guard let id = sessionId else { return }
        do {
            let summary = try behavior.endSession(sessionId: id)
            print("Duration: \(summary.duration)ms, events: \(summary.eventCount)")
            sessionId = nil
        } catch {
            print("End failed: \(error)")
        }
    }

    deinit { behavior.dispose() }
}

@main
struct MyApp: App {
    @StateObject private var host = BehaviorHost()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(host)
        }
    }
}
```

If you want to capture typing events, use a `UITextField` subclass like
`BehaviorTrackingTextField` from this example as the input control in
your screens. The SDK doesn't see — and doesn't want to see — the text
itself; the subclass simply gives you a hook point for typing-aware
behavior.

---

## Support

If you encounter issues:

1. Check the [README.md](../README.md) for basic setup and API reference
2. Read the [privacy audit](https://docs.synheart.ai/privacy/behavior)
   for privacy questions
3. File an issue on
   [GitHub](https://github.com/synheart-ai/synheart-behavior-swift/issues)

Happy testing.
