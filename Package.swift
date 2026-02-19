// swift-tools-version: 5.9
import PackageDescription

// SynheartBehavior SDK
//
// Required Integration: synheart-flux (Rust)
// ==========================================
// The SDK requires synheart-flux (Rust library) for HSI-compliant
// behavioral metrics computation. The SDK will fail if Flux is not available.
//
// To integrate synheart-flux:
// 1. Download SynheartFlux.xcframework from synheart-flux releases
// 2. Place it in Frameworks/SynheartFlux.xcframework
// 3. Add it as a dependency to your app target
//
// The FluxBridge class will detect the library at runtime and throw errors if unavailable.

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

