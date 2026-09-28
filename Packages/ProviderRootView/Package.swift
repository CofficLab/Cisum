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
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
        .package(path: "../KitEventObservation"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
    ],
    targets: [
        .target(
            name: "ProviderRootView",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitEventObservation", package: "KitEventObservation"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
