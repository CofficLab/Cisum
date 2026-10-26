// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginRepositoryGuide",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginRepositoryGuide",
            targets: ["PluginRepositoryGuide"]
        )
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.11.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(path: "../ProviderPlugin"),
        .package(name: "ProviderControlView", path: "../ProviderControlView"),
        .package(name: "ProviderAudioLibrary", path: "../ProviderAudioLibrary"),
        .package(name: "ProviderScene", path: "../ProviderScene"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.13.0"),
    ],
    targets: [
        .target(
            name: "PluginRepositoryGuide",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "ProviderControlView", package: "ProviderControlView"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources"],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginRepositoryGuideTests",
            dependencies: [
                "PluginRepositoryGuide",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "ProviderControlView", package: "ProviderControlView"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderScene", package: "ProviderScene"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
