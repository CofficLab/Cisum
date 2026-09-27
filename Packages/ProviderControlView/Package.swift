// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderControlView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderControlView", targets: ["ProviderControlView"]),
    ],
    dependencies: [
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
    ],
    targets: [
        .target(
            name: "ProviderControlView",
            dependencies: [
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderControlView"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderControlViewTests",
            dependencies: ["ProviderControlView"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
