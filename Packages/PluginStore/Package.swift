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
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
        .package(path: "../ProviderStore"),
        .package(path: "../ProviderAudioLibrary"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "PluginStore",
            dependencies: [
                .product(name: "ProviderStore", package: "ProviderStore"),
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderToast", package: "ProviderToast"),
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
