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
        .package(path: "../KernelCore"),
        .package(path: "../ProviderBook"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginBookDBData",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "BookDBDataPluginTests",
            dependencies: ["PluginBookDBData"],
            path: "Tests"
        ),
    ]
)
