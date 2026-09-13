// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderAppState",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderAppState", targets: ["ProviderAppState"]),
    ],
    targets: [
        .target(name: "ProviderAppState", path: ".", exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderAppState"],
            resources: [.process("Resources")]),
        .testTarget(
            name: "ProviderAppStateTests",
            dependencies: ["ProviderAppState"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
