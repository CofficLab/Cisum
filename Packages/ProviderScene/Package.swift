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
        .package(name: "KernelCore", path: "../KernelCore"),
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
    ],
    targets: [
        .target(
            name: "ProviderScene",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
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
                .product(name: "KernelCore", package: "KernelCore"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
