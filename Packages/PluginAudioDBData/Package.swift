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
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderAudioNavigation", package: "ProviderAudioNavigation"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "AudioDBDataPluginTests",
            dependencies: ["PluginAudioDBData"],
            path: "Tests"
        ),
    ]
)
