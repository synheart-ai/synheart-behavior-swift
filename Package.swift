// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SynheartBehavior",
    platforms: [
        .iOS(.v12),
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

