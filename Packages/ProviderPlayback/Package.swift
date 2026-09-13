// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPlayback",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderPlayback", targets: ["ProviderPlayback"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ProviderPlayback",
            dependencies: [],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderPlayback"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderPlaybackTests",
            dependencies: ["ProviderPlayback"],
            path: "Tests"
        )
    ],
    swiftLanguageModes: [.v5]
)
