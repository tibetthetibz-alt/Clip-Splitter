// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SlipSplitter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SlipSplitter", targets: ["SlipSplitter"])
    ],
    targets: [
        .executableTarget(
            name: "SlipSplitter",
            path: "Sources/SlipSplitter",
            swiftSettings: [
                .unsafeFlags(["-gnone"])
            ]
        )
    ]
)
