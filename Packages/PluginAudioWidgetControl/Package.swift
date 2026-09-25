// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAudioWidgetControl",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginAudioWidgetControl",
            targets: ["PluginAudioWidgetControl"]
        )
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../CisumKernelSupport"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderAudioLibrary"),
        .package(path: "../MagicPlayMan"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(path: "../ProviderAudioNavigation"),
    ],
    targets: [
        .target(
            name: "PluginAudioWidgetControl",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "MagicPlayMan", package: "MagicPlayMan"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderAudioNavigation", package: "ProviderAudioNavigation"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AudioWidgetControlPluginTests",
            dependencies: ["PluginAudioWidgetControl"],
            path: "Tests"
        )
    ]
)
