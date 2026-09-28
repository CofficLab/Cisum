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
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
        .package(path: "../ProviderBook"),
        .package(name: "KitPlayback", path: "../MagicPlayMan"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
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
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "MagicPlayMan", package: "KitPlayback"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToast", package: "ProviderToast"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "BookControlButtonsPluginTests",
            dependencies: [
                "PluginBookControlButtons",
                .product(name: "ProviderPlayback", package: "ProviderPlayback")
            ],
            path: "Tests"
        )
    ]
)
