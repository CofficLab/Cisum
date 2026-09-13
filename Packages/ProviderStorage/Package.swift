// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderStorage",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderStorage", targets: ["ProviderStorage"]),
    ],
    targets: [
        .target(name: "ProviderStorage", path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderStorage"],
            resources: [.process("Resources")]),
        .testTarget(
            name: "ProviderStorageTests",
            dependencies: ["ProviderStorage"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
