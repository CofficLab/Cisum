// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PluginScene",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginScene",
            targets: ["PluginScene"]
        ),
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(name: "CisumKernelSupport", path: "../CisumKernelSupport"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
        .package(name: "ProviderScene", path: "../ProviderScene"),
    ],
    targets: [
        .target(
            name: "PluginScene",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "ProviderScene", package: "ProviderScene"),
            ],
            path: ".",
            sources: ["Sources/PluginScene"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "PluginSceneTests",
            dependencies: ["PluginScene"],
            path: "Tests/PluginSceneTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
