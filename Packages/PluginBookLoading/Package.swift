// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginBookLoading",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v2),
    ],
    products: [
        .library(
            name: "PluginBookLoading",
            targets: ["PluginBookLoading"]
        )
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.17.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.1"),
        .package(path: "../ProviderPlugin"),
        .package(path: "../ProviderScene"),
        .package(path: "../ProviderPlayback"),
        .package(path: "../ProviderControlView"),
        .package(path: "../ProviderBook"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.23.0"),
    ],
    targets: [
        .target(
            name: "PluginBookLoading",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderControlView", package: "ProviderControlView"),
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "BookLoadingPluginTests",
            dependencies: [
                "PluginBookLoading",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderControlView", package: "ProviderControlView"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
