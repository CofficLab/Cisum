// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPluginManaging",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderPluginManaging", targets: ["CisumProviderPluginManaging"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.3.4"),
        .package(path: "../ProviderPlugin"),
    ],
    targets: [
        .target(
            name: "CisumProviderPluginManaging",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPluginControl", package: "LumiProviders"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderPluginManaging"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderPluginManagingTests",
            dependencies: [
                "CisumProviderPluginManaging",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
