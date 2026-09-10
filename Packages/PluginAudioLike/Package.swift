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
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../ProviderAudioLike"),
        .package(path: "../ProviderStorage"),
        .package(path: "../MagicPlayMan"),
        .package(path: "../KernelCore"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderScene"),
        .package(path: "../ProviderPlayback")
    ],
    targets: [
        .target(
            name: "PluginAudioLike",
            dependencies: [
                .product(name: "ProviderAudioLike", package: "ProviderAudioLike"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "MagicPlayMan", package: "MagicPlayMan"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback")
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
                .product(name: "ProviderAudioLike", package: "ProviderAudioLike")
            ],
            path: "Tests"
        )
    ]
)
