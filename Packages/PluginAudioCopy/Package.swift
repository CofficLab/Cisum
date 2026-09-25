// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PluginAudioCopy",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginAudioCopy",
            targets: ["PluginAudioCopy"]
        ),
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../CisumKernelSupport"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderAudioLibrary"),
        .package(path: "../ProviderStore"),
    ],
    targets: [
        .target(
            name: "PluginAudioCopy",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                "CisumUIComponents",
                "CisumKernelSupport",
                "ProviderDocsView",
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderStore", package: "ProviderStore"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .testTarget(
            name: "AudioCopyPluginTests",
            dependencies: ["PluginAudioCopy"],
            path: "Tests"
        ),
    ]
)
