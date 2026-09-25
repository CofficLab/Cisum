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
        .package(path: "../MagicKit"),
        .package(name: "CisumKernel", path: "../CisumKernel"),
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(name: "ProviderPluginManaging", path: "../ProviderPluginManaging"),
        .package(name: "ProviderStorage", path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginPluginManager",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumKernel", package: "CisumKernel"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderPluginManaging", package: "ProviderPluginManaging"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: ".",
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
