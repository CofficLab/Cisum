// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginBookProgress",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginBookProgress",
            targets: ["PluginBookProgress"]
        )
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
        .package(path: "../ProviderBook"),
        .package(name: "KitPlayback", path: "../MagicPlayMan"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(path: "../ProviderScene"),
        .package(path: "../ProviderPlayback"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.3.4")
    ],
    targets: [
        .target(
            name: "PluginBookProgress",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "MagicPlayMan", package: "KitPlayback"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderToast", package: "LumiProviders")
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "BookProgressPluginTests",
            dependencies: [
                "PluginBookProgress",
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "ProviderBookData", package: "ProviderBook"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
            ],
            path: "Tests"
        )
    ]
)
