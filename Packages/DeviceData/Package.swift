// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KitDeviceData",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "CisumDeviceData",
            targets: ["CisumDeviceData"]
        )
    ],
    targets: [
        .target(
            name: "CisumDeviceData",
            path: ".",
            sources: ["Sources"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CisumDeviceDataTests",
            dependencies: ["CisumDeviceData"],
            path: "Tests"
        )
    ]
)
