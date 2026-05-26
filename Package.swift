// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ClipSplitter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClipSplitter", targets: ["ClipSplitter"])
    ],
    targets: [
        .executableTarget(
            name: "ClipSplitter",
            path: "Sources/ClipSplitter",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-gnone"])
            ]
        )
    ]
)
