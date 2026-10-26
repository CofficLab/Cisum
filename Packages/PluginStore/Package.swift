// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginStore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginStore",
            targets: ["PluginStore"]
        )
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.8.0"),
        .package(path: "../ProviderStore"),
        .package(path: "../ProviderAudioLibrary"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.13.0"),
    ],
    targets: [
        .target(
            name: "PluginStore",
            dependencies: [
                .product(name: "ProviderStore", package: "ProviderStore"),
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderToast", package: "LumiProviders"),
            ],
            path: ".",
            sources: [
                "Sources/StorePlugin.swift",
                "Sources/Observers",
                "Sources/ViewModels",
                "Sources/Views"
            ],
            resources: [
                .process("Resources/Localizable.xcstrings"),
                .process("Resources/Products.storekit")
            ]
        ),
        .testTarget(
            name: "StorePluginTests",
            dependencies: [
                "PluginStore",
                .product(name: "ProviderStore", package: "ProviderStore")
            ],
            path: "Tests"
        )
    ]
)
