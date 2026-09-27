// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginVideo",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginVideo",
            targets: ["PluginVideo"]
        )
    ],
    dependencies: [
        .package(name: "KitUIComponents", path: "../../Packages/CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
    ],
    targets: [
        .target(
            name: "PluginVideo",
            dependencies: [
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "VideoPluginTests",
            dependencies: ["PluginVideo"],
            path: "Tests"
        )
    ]
)
