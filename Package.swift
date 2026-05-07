// swift-tools-version: 5.9
import PackageDescription

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

