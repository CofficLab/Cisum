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
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../ProviderPlugin"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(name: "KitAppEvents", path: "../KitAppEvents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
        .package(name: "ProviderScene", path: "../ProviderScene"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.3.4"),
    ],
    targets: [
        .target(
            name: "PluginScene",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/PluginScene"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "PluginSceneTests",
            dependencies: [
                "PluginScene",
                .product(name: "KitAppEvents", package: "KitAppEvents"),
            ],
            path: "Tests/PluginSceneTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
