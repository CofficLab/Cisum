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
        .package(name: "CisumKernelSupport", path: "../CisumKernelSupport"),
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
    ],
    targets: [
        .target(
            name: "ProviderScene",
            dependencies: [
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
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
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
