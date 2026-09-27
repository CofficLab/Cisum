// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPluginManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "PluginPluginManager", targets: ["PluginPluginManager"]),
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "7031fda7ff72492d574ef9a4b5d9ffdc801a6660"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(name: "ProviderPluginManaging", path: "../ProviderPluginManaging"),
        .package(name: "ProviderPlugin", path: "../ProviderPlugin"),
        .package(name: "ProviderStorage", path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginPluginManager",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderPluginManaging", package: "ProviderPluginManaging"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/PluginPluginManager"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginPluginManagerTests",
            dependencies: [
                .target(name: "PluginPluginManager"),
            ],
            path: "Tests/PluginPluginManagerTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
