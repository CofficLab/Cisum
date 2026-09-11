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
        .package(path: "../MagicKit"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "PluginToast",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "KernelCore", package: "KernelCore"),
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
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToast", package: "ProviderToast"),
            ],
            path: "Tests/PluginToastTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
