// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPlayBack",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "PluginPlayBack", targets: ["PluginPlayBack"]),
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(name: "KernelCore", path: "../KernelCore"),
        .package(name: "MagicPlayMan", path: "../MagicPlayMan"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(name: "ProviderScene", path: "../ProviderScene"),
        .package(name: "ProviderStorage", path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginPlayBack",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                "CisumUIComponents",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "MagicPlayMan", package: "MagicPlayMan"),
                "ProviderDocsView",
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/PluginPlayBack"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginPlayBackTests",
            dependencies: [
                "PluginPlayBack",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderScene", package: "ProviderScene"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
