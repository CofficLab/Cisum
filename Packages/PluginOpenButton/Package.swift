// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenButton",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginOpenButton",
            targets: ["PluginOpenButton"]
        )
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "KitPlayback", path: "../MagicPlayMan"),
        .package(path: "../ProviderPlayback"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
    ],
    targets: [
        .target(
            name: "PluginOpenButton",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "MagicPlayMan", package: "KitPlayback"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "OpenButtonPluginTests",
            dependencies: [
                "PluginOpenButton",
                .product(name: "ProviderPlayback", package: "ProviderPlayback")
            ],
            path: "Tests"
        )
    ]
)
