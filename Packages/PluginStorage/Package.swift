// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PluginStorage",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginStorage",
            targets: ["PluginStorage"]
        ),
    ],
    dependencies: [
        .package(path: "../CisumUIComponents"),
        .package(path: "../KernelCore"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../MagicKit"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginStorage",
            dependencies: [
                "CisumUIComponents",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .testTarget(
            name: "StoragePluginTests",
            dependencies: [
                "PluginStorage",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: "Tests"
        ),
    ]
)
