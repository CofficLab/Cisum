// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderContentView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderContentView", targets: ["ProviderContentView"]),
    ],
    dependencies: [
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
    ],
    targets: [
        .target(
            name: "ProviderContentView",
            dependencies: [
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderContentView"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ProviderContentViewTests",
            dependencies: ["ProviderContentView"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
