// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PluginAudioDBData",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginAudioDBData",
            targets: ["PluginAudioDBData"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../ProviderAudioLibrary"),
        .package(path: "../ProviderAudioNavigation"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginAudioDBData",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderAudioNavigation", package: "ProviderAudioNavigation"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AudioDBDataPluginTests",
            dependencies: [
                "PluginAudioDBData",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: "Tests"
        ),
    ]
)
