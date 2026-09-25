// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLikeButton",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginLikeButton",
            targets: ["PluginLikeButton"]
        )
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(path: "../CisumKernel"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(path: "../MagicPlayMan"),
        .package(path: "../ProviderPlayback"),
    ],
    targets: [
        .target(
            name: "PluginLikeButton",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "CisumKernel", package: "CisumKernel"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "MagicPlayMan", package: "MagicPlayMan"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LikeButtonPluginTests",
            dependencies: ["PluginLikeButton"],
            path: "Tests"
        )
    ]
)
