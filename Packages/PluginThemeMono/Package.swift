// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeMono",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginThemeMono",
            targets: ["PluginThemeMono"]
        )
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../CisumKernel"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
    ],
    targets: [
        .target(
            name: "PluginThemeMono",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "CisumKernel", package: "CisumKernel"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ThemeMonoPluginTests",
            dependencies: ["PluginThemeMono"],
            path: "Tests"
        )
    ]
)
