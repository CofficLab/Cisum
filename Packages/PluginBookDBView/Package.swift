// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PluginBookDBView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginBookDBView",
            targets: ["PluginBookDBView"]
        ),
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderBook"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(path: "../ProviderScene"),
        .package(path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "PluginBookDBView",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                "ProviderScene",
                .product(name: "ProviderToast", package: "ProviderToast"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .testTarget(
            name: "BookDBViewPluginTests",
            dependencies: [
                "PluginBookDBView",
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "ProviderBookData", package: "ProviderBook"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
            ],
            path: "Tests"
        ),
    ]
)
