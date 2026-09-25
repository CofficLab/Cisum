// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAudioDownload",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginAudioDownload",
            targets: ["PluginAudioDownload"]
        )
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../MagicPlayMan"),
        .package(path: "../CisumKernelSupport"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderScene"),
        .package(path: "../ProviderPlayback")
    ],
    targets: [
        .target(
            name: "PluginAudioDownload",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "MagicPlayMan", package: "MagicPlayMan"),
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback")
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AudioDownloadPluginTests",
            dependencies: ["PluginAudioDownload"],
            path: "Tests"
        )
    ]
)
