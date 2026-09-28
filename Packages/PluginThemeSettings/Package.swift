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
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderTheme"),
    ],
    targets: [
        .target(
            name: "PluginThemeSettings",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
.product(name: "CisumUIComponents", package: "KitUIComponents"), .product(name: "LumiUI", package: "LumiUI"), .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"), "ProviderDocsView", "ProviderTheme"],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ThemeSettingsPluginTests",
            dependencies: [
                "PluginThemeSettings",
                .product(name: "ProviderTheme", package: "ProviderTheme"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Tests"
        )
    ]
)
