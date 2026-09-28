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
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(path: "../ProviderAudioLibrary"),
        .package(path: "../ProviderStore"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "PluginAudioCopy",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderStore", package: "ProviderStore"),
                .product(name: "ProviderToast", package: "ProviderToast"),
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
