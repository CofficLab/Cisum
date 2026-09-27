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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "7031fda7ff72492d574ef9a4b5d9ffdc801a6660"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(path: "../ProviderBook"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginBookDBData",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "MagicKit", package: "KitMagic"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderBook", package: "ProviderBook"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: "Tests"
        ),
    ]
)
