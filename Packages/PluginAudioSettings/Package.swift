// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAudioSettings",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginAudioSettings",
            targets: ["PluginAudioSettings"]
        )
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../CisumKernelSupport"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderAudioLibrary")
    ],
    targets: [
        .target(
            name: "PluginAudioSettings",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                "CisumUIComponents",
                "CisumKernelSupport",
                "ProviderDocsView",
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary")
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AudioSettingsPluginTests",
            dependencies: ["PluginAudioSettings"],
            path: "Tests"
        )
    ]
)
