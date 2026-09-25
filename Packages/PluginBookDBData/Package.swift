// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PluginBookDBData",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginBookDBData",
            targets: ["PluginBookDBData"]
        ),
    ],
    dependencies: [
        .package(path: "../CisumKernel"),
        .package(path: "../MagicKit"),
        .package(path: "../ProviderBook"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginBookDBData",
            dependencies: [
                .product(name: "CisumKernel", package: "CisumKernel"),
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "ProviderBookData", package: "ProviderBook"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "BookDBDataPluginTests",
            dependencies: [
                "PluginBookDBData",
                .product(name: "CisumKernel", package: "CisumKernel"),
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: "Tests"
        ),
    ]
)
