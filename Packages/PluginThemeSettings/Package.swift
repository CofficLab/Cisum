// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeSettings",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginThemeSettings",
            targets: ["PluginThemeSettings"]
        )
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../CisumKernel"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderTheme"),
    ],
    targets: [
        .target(
            name: "PluginThemeSettings",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
"CisumUIComponents", "CisumKernel", "ProviderDocsView", "ProviderTheme"],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ThemeSettingsPluginTests",
            dependencies: ["PluginThemeSettings"],
            path: "Tests"
        )
    ]
)
