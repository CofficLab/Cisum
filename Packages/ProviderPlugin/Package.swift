// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderPlugin", targets: ["ProviderPlugin"]),
    ],
    dependencies: [
        .package(name: "CisumKernel", path: "../CisumKernel"),
    ],
    targets: [
        .target(
            name: "ProviderPlugin",
            dependencies: [
                .product(name: "CisumKernel", package: "CisumKernel"),
            ],
            path: ".",
            sources: ["Sources/ProviderPlugin"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderPluginTests",
            dependencies: ["ProviderPlugin"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
