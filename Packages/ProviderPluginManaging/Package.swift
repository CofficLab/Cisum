// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPluginManaging",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderPluginManaging", targets: ["ProviderPluginManaging"]),
    ],
    dependencies: [
        .package(name: "CisumKernelSupport", path: "../CisumKernelSupport"),
    ],
    targets: [
        .target(
            name: "ProviderPluginManaging",
            dependencies: [
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderPluginManaging"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderPluginManagingTests",
            dependencies: [
                "ProviderPluginManaging",
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
