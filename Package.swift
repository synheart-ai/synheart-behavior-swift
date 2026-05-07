// swift-tools-version: 5.9
import PackageDescription

// SynheartBehavior SDK
//
// A privacy-preserving collector of digital behavioral signals on iOS.
// The SDK captures interaction events (taps, scrolls, swipes, app
// switches, idle gaps, typing session counts) and emits per-session
// summaries. Higher-level behavioral inference (HSI fusion, focus /
// distraction modeling) lives in the Synheart Core SDK, which consumes
// the events this package emits.

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
        ),
        .testTarget(
            name: "SynheartBehaviorTests",
            dependencies: ["SynheartBehavior"]
        ),
    ]
)
