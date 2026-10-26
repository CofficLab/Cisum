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
        .package(name: "KitPlayback", path: "../MagicPlayMan"),
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.8.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.13.0"),
    ],
    targets: [
        .target(
            name: "PluginPlaybackProgress",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "MagicPlayMan", package: "KitPlayback"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
