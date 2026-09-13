// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderDevice",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderDevice", targets: ["ProviderDevice"]),
    ],
    targets: [
        .target(name: "ProviderDevice", path: ".", exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderDevice"],
            resources: [.process("Resources")]),
        .testTarget(
            name: "ProviderDeviceTests",
            dependencies: ["ProviderDevice"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
