// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPlaybackHero",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginPlaybackHero",
            targets: ["PluginPlaybackHero"]
        )
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(name: "ProviderAppState", path: "../ProviderAppState"),
        .package(name: "ProviderAudioLibrary", path: "../ProviderAudioLibrary"),
        .package(name: "ProviderScene", path: "../ProviderScene"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.3.4"),
    ],
    targets: [
        .target(
            name: "PluginPlaybackHero",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderAppState", package: "ProviderAppState"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderScene", package: "ProviderScene"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginPlaybackHeroTests",
            dependencies: [
                "PluginPlaybackHero",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderScene", package: "ProviderScene"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
