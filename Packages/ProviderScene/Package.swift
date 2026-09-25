// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderScene",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderScene", targets: ["ProviderScene"]),
    ],
    dependencies: [
        .package(name: "CisumKernel", path: "../CisumKernel"),
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
    ],
    targets: [
        .target(
            name: "ProviderScene",
            dependencies: [
                .product(name: "CisumKernel", package: "CisumKernel"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderScene"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderSceneTests",
            dependencies: [
                "ProviderScene",
                .product(name: "CisumKernel", package: "CisumKernel"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
