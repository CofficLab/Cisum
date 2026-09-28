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
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderAudioLibrary"),
        .package(name: "KitPlayback", path: "../MagicPlayMan"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(path: "../ProviderAudioNavigation"),
    ],
    targets: [
        .target(
            name: "PluginAudioWidgetControl",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "MagicPlayMan", package: "KitPlayback"),
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
            dependencies: [
                "PluginAudioWidgetControl",
                .product(name: "ProviderPlayback", package: "ProviderPlayback")
            ],
            path: "Tests"
        )
    ]
)
