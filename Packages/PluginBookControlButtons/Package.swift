// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginBookControlButtons",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginBookControlButtons",
            targets: ["PluginBookControlButtons"]
        )
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../ProviderBook"),
        .package(path: "../MagicPlayMan"),
        .package(path: "../CisumKernelSupport"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderScene"),
        .package(path: "../ProviderPlayback"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "PluginBookControlButtons",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "MagicPlayMan", package: "MagicPlayMan"),
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToast", package: "ProviderToast"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "BookControlButtonsPluginTests",
            dependencies: ["PluginBookControlButtons"],
            path: "Tests"
        )
    ]
)
