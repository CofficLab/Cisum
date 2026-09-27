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
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
        .package(name: "KitPlayback", path: "../MagicPlayMan"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "7031fda7ff72492d574ef9a4b5d9ffdc801a6660"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderScene"),
        .package(path: "../ProviderPlayback"),
        .package(path: "../ProviderToast")
    ],
    targets: [
        .target(
            name: "PluginAudioDownload",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MagicPlayMan", package: "KitPlayback"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderToast", package: "ProviderToast")
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
