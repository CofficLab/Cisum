// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitUIComponents",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "CisumUIComponents",
            targets: ["CisumUIComponents"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "CisumUIComponents",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources"],
            resources: [.process("Resources")],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=minimal"),
            ]
        ),
        .testTarget(
            name: "CisumUIComponentsTests",
            dependencies: ["CisumUIComponents"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
