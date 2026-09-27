// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAudioLike",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginAudioLike",
            targets: ["PluginAudioLike"]
        )
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
        .package(path: "../ProviderAudioLike"),
        .package(path: "../ProviderStorage"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "7031fda7ff72492d574ef9a4b5d9ffdc801a6660"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderScene"),
        .package(path: "../ProviderPlayback"),
        .package(path: "../ProviderToast")
    ],
    targets: [
        .target(
            name: "PluginAudioLike",
            dependencies: [
                .product(name: "ProviderAudioLike", package: "ProviderAudioLike"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderToast", package: "ProviderToast")
            ],
            path: ".",
            sources: [
                "Sources/AudioLikePlugin.swift",
                "Sources/Capabilities",
                "Sources/Events",
                "Sources/Models/AudioLikePluginInfo.swift",
                "Sources/Models/AudioLikeModel.swift",
                "Sources/Observers",
                "Sources/Services",
                "Sources/ViewModels",
                "Sources/Views"
            ],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AudioLikePluginTests",
            dependencies: [
                "PluginAudioLike",
                .product(name: "ProviderAudioLike", package: "ProviderAudioLike"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback")
            ],
            path: "Tests"
        )
    ]
)
