// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAudioDBView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginAudioDBView",
            targets: ["PluginAudioDBView"]
        )
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../KernelCore"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(name: "ProviderAudioLibrary", path: "../ProviderAudioLibrary"),
        .package(path: "../ProviderScene"),
        .package(path: "../ProviderStorage"),
        .package(name: "PluginAudioDBData", path: "../PluginAudioDBData"),
    ],
    targets: [
        .target(
            name: "PluginAudioDBView",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "PluginAudioDBData", package: "PluginAudioDBData"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AudioDBViewPluginTests",
            dependencies: ["PluginAudioDBView"],
            path: "Tests"
        )
    ]
)
