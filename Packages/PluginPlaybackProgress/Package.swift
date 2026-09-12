// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPlaybackProgress",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginPlaybackProgress",
            targets: ["PluginPlaybackProgress"]
        )
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(name: "KernelCore", path: "../KernelCore"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
    ],
    targets: [
        .target(
            name: "PluginPlaybackProgress",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginPlaybackProgressTests",
            dependencies: [
                "PluginPlaybackProgress",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
