// swift-tools-version: 5.9
import PackageDescription

// SynheartBehavior SDK
//
// Optional integration: synheart-flux
// ==========================================
// The SDK runs standalone for event capture + per-session summaries.
// HSI-compliant behavioral metrics (`endSessionWithHsi()`) require
// the optional synheart-flux native binary.
//
// To enable HSI metrics:
// 1. Download SynheartFlux.xcframework from synheart-flux releases.
// 2. Place it in Frameworks/SynheartFlux.xcframework.
// 3. Add it as a dependency to your app target.
//
// FluxBridge detects the binary at runtime; without it, only the
// HSI-emitting path is unavailable — the rest of the SDK works.

let package = Package(
    name: "SynheartBehavior",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "SynheartBehavior",
            targets: ["SynheartBehavior"]
        ),
    ],
    targets: [
        .target(
            name: "SynheartBehavior",
            dependencies: []
            // Note: synheart-flux is linked dynamically at runtime if available
            // No linker settings needed here - FluxBridge handles detection
        ),
        .testTarget(
            name: "SynheartBehaviorTests",
            dependencies: ["SynheartBehavior"]
        ),
    ]
)

