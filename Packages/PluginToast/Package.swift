// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToast",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "PluginToast", targets: ["PluginToast"]),
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "PluginToast",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToast", package: "ProviderToast"),
            ],
            path: ".",
            exclude: ["Tests"],
            sources: ["Sources/PluginToast"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginToastTests",
            dependencies: [
                "PluginToast",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToast", package: "ProviderToast"),
            ],
            path: "Tests/PluginToastTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
