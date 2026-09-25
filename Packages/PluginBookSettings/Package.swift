// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginBookSettings",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginBookSettings",
            targets: ["PluginBookSettings"]
        )
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../CisumKernel"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderBook"),
    ],
    targets: [
        .target(
            name: "PluginBookSettings",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                "CisumUIComponents",
                "CisumKernel",
                "ProviderDocsView",
                .product(name: "ProviderBook", package: "ProviderBook"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "BookSettingsPluginTests",
            dependencies: ["PluginBookSettings"],
            path: "Tests"
        )
    ]
)
