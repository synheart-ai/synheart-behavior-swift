# Quick Integration Guide

A simple guide to integrate Synheart Behavioral SDK into your iOS app.

## Step 1: Add the SDK

### Via Xcode
1. File → Add Packages...
2. Enter: `https://github.com/synheart-ai/synheart-behavior-ios.git`
3. Select version: `0.3.0`

### Via Package.swift
```swift
dependencies: [
    .package(url: "https://github.com/synheart-ai/synheart-behavior-ios.git", from: "0.3.0")
]
```

## Step 2: Download and Add synheart-flux (Required)

The SDK requires synheart-flux for HSI-compliant metrics computation. **Just downloading is not enough** - you must add it to your Xcode project and configure it.

1. **Download**: Go to [synheart-flux releases](https://github.com/synheart-ai/synheart-flux/releases)
2. **Download**: `synheart-flux-ios-xcframework.zip` (version 0.1.1 or later)
3. **Extract** the zip file to get `SynheartFlux.xcframework`
4. **Add to Xcode**:
   - Drag `SynheartFlux.xcframework` into your Xcode project (add to your app target, not the package)
   - In Xcode: Select your app target → General tab → Frameworks, Libraries, and Embedded Content
   - Click "+" and add `SynheartFlux.xcframework`
   - Set it to **"Do Not Embed"** (it's a static library, not a dynamic framework)
5. **Configure Build Settings**:
   - In Build Settings → Other Linker Flags (`OTHER_LDFLAGS`), add both paths (Xcode will use the correct one based on build target):
     - `-L$(PROJECT_DIR)/path/to/SynheartFlux.xcframework/ios-arm64_x86_64-simulator -lsynheart_flux`
     - `-L$(PROJECT_DIR)/path/to/SynheartFlux.xcframework/ios-arm64 -lsynheart_flux`
     - Replace `path/to/` with the actual path relative to your project directory (e.g., if the framework is in `Frameworks/`, use `Frameworks/SynheartFlux.xcframework`)
   - In Build Settings → Framework Search Paths (`FRAMEWORK_SEARCH_PATHS`), add:
     - `$(PROJECT_DIR)/path/to/SynheartFlux.xcframework`
     - Replace `path/to/` with the actual path relative to your project directory

**Important**: For static libraries in XCFrameworks, you typically need to configure the linker flags manually. Xcode won't automatically link static libraries. The XCFramework will automatically select the correct architecture slice based on your build target.

## Step 3: Initialize the SDK

```swift
import SynheartBehavior

// In your AppDelegate or SceneDelegate
let config = BehaviorConfig(
    enableInputSignals: true,      // Track taps, scrolls, swipes
    enableAttentionSignals: true,   // Track app switches, idle gaps
    enableMotionLite: false        // Optional: motion tracking
)

let behavior = SynheartBehavior(config: config)
try behavior.initialize()

// Verify Flux is available
guard behavior.isFluxAvailable else {
    fatalError("synheart-flux is required but not available")
}
```

## Step 4: Basic Usage

```swift
// Start a session
let sessionId = try behavior.startSession()

// Set up event handler (optional)
behavior.setEventHandler { event in
    // Handle real-time events
    print("Event: \(event.type)")
}

// ... user interacts with your app ...

// Optional: report copy/paste/cut for clipboard_activity_rate (use a custom text field that calls these)
// behavior.recordCopy()  behavior.recordPaste()  behavior.recordCut()
// Example app uses BehaviorTrackingTextField; see Example/ExampleApp/BehaviorTrackingTextField.swift

// End session and get HSI metrics
let (hsiPayload, rawHsiJson) = try behavior.endSessionWithHsi(sessionId: sessionId)

// Access metrics
if let window = hsiPayload.behaviorWindows.first {
    let focus = hsiPayload.behaviorReadings.first(where: { $0.axis == "focus" })?.score ?? 0
    let distraction = hsiPayload.behaviorReadings.first(where: { $0.axis == "distraction" })?.score ?? 0
    print("Focus: \(focus), Distraction: \(distraction)")
}
```

## Troubleshooting

**Flux not available at runtime?**
- Ensure `SynheartFlux.xcframework` is added to your app target (not just the package)
- Verify linker flags (`OTHER_LDFLAGS`) are configured correctly - check the paths match your project structure
- Check that framework search paths (`FRAMEWORK_SEARCH_PATHS`) include the XCFramework location
- Verify you downloaded version 0.1.1 or later
- Clean build folder: Product → Clean Build Folder

**Linker errors (undefined symbols)?**
- Verify the `-L` paths in `OTHER_LDFLAGS` point to the correct XCFramework subdirectories
- Ensure `-lsynheart_flux` is included in `OTHER_LDFLAGS`
- Check that `FRAMEWORK_SEARCH_PATHS` includes the XCFramework directory
- Verify the XCFramework contains the correct architecture slices (arm64 for device, x86_64/arm64 for simulator)
- Clean build folder: Product → Clean Build Folder

**Build errors?**
- Clean build folder: Product → Clean Build Folder
- Ensure iOS deployment target is 12.0+
- Check that the XCFramework contains the correct architecture slices for your target

## Next Steps

- See [README.md](README.md) for full API documentation
- See [SYNHEART_FLUX_INTEGRATION.md](SYNHEART_FLUX_INTEGRATION.md) for advanced Flux usage
- Check the [Example/](Example/) directory for a complete working app
