// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDevice",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginDevice",
            targets: ["PluginDevice"]
        )
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitDeviceData", path: "../../Packages/DeviceData"),
        .package(name: "KitUIComponents", path: "../../Packages/CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
    ],
    targets: [
        .target(
            name: "PluginDevice",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumDeviceData", package: "KitDeviceData"),
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
            name: "DevicePluginTests",
            dependencies: ["PluginDevice"],
            path: "Tests"
        )
    ]
)
