// swift-tools-version: 5.9
import PackageDescription

// SynheartBehavior SDK
//
// Optional Integration: synheart-flux (Rust)
// ==========================================
// The SDK can optionally use synheart-flux (Rust library) for HSI-compliant
// behavioral metrics computation. If not available, it falls back to Swift.
//
// To enable synheart-flux:
// 1. Download SynheartFlux.xcframework from synheart-flux releases
// 2. Place it in Frameworks/SynheartFlux.xcframework
// 3. Add it as a dependency to your app target
//
// The FluxBridge class will automatically detect and use the library at runtime.

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

