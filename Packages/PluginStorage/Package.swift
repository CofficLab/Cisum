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
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../ProviderPlugin"),
        .package(path: "../KitEventObservation"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginStorage",
            dependencies: [
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitEventObservation", package: "KitEventObservation"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "MagicKit", package: "KitMagic"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: "Tests"
        ),
    ]
)
