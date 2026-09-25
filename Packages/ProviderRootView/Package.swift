// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderRootView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderRootView", targets: ["ProviderRootView"]),
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(name: "CisumKernel", path: "../CisumKernel"),
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
    ],
    targets: [
        .target(
            name: "ProviderRootView",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumKernel", package: "CisumKernel"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
            ],
            path: ".",
            sources: ["Sources/ProviderRootView"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderRootViewTests",
            dependencies: [
                "ProviderRootView",
                .product(name: "CisumKernel", package: "CisumKernel"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
