// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderControlView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderControlView", targets: ["ProviderControlView"]),
    ],
    dependencies: [
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
    ],
    targets: [
        .target(
            name: "ProviderControlView",
            dependencies: [
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderControlView"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderControlViewTests",
            dependencies: ["ProviderControlView"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
