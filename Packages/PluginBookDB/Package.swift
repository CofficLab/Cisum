// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PluginBookDB",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginBookDB",
            targets: ["PluginBookDB"]
        ),
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../KernelCore"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderBook"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(path: "../ProviderScene"),
    ],
    targets: [
        .target(
            name: "PluginBookDB",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                "CisumUIComponents",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                "ProviderScene",
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .testTarget(
            name: "BookDBViewPluginTests",
            dependencies: [
                "PluginBookDB",
                .product(name: "ProviderBook", package: "ProviderBook"),
            ],
            path: "Tests"
        ),
    ]
)
