// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginVideoLibrary",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "PluginVideoLibrary", targets: ["PluginVideoLibrary"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiUI", from: "1.17.1"),
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(path: "../ProviderPlugin"),
        .package(path: "../ProviderScene"),
        .package(path: "../ProviderVideo"),
    ],
    targets: [
        .target(
            name: "PluginVideoLibrary",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MagicKit", package: "KitMagic"),
                "ProviderScene",
                "ProviderVideo",
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .testTarget(
            name: "PluginVideoLibraryTests",
            dependencies: [
                "PluginVideoLibrary",
                "ProviderVideo",
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
