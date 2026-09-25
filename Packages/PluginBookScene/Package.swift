// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginBookScene",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginBookScene",
            targets: ["PluginBookScene"]
        )
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../CisumKernelSupport"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../ProviderScene"),
    ],
    targets: [
        .target(
            name: "PluginBookScene",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                "CisumUIComponents",
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderScene", package: "ProviderScene"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "BookScenePluginTests",
            dependencies: ["PluginBookScene"],
            path: "Tests"
        )
    ]
)
