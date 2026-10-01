// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KitPlayback",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MagicPlayMan",
            targets: ["MagicPlayMan"]
        )
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(path: "../ProviderPlayback"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "MagicPlayMan",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MagicPlayManTests",
            dependencies: [
                "MagicPlayMan",
                .product(name: "ProviderPlayback", package: "ProviderPlayback")
            ],
            path: "Tests"
        )
    ]
)
