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
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../ProviderStore"),
        .package(path: "../ProviderAudioLibrary"),
        .package(path: "../CisumKernelSupport"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
    ],
    targets: [
        .target(
            name: "PluginStore",
            dependencies: [
                .product(name: "ProviderStore", package: "ProviderStore"),
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
            ],
            path: ".",
            sources: [
                "Sources/StorePlugin.swift",
                "Sources/ProviderStoreExports.swift",
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
