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
        .library(name: "ProviderStorage", targets: ["CisumProviderStorage"]),
    ],
    dependencies: [
        .package(path: "../KitEventObservation"),
    ],
    targets: [
        .target(name: "CisumProviderStorage", dependencies: [
            .product(name: "KitEventObservation", package: "KitEventObservation"),
        ], path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderStorage"],
            resources: [.process("Resources")]),
        .testTarget(
            name: "ProviderStorageTests",
            dependencies: ["CisumProviderStorage"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
