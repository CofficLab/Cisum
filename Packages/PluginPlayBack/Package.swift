// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPlayBack",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "PluginPlayBack", targets: ["PluginPlayBack"]),
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "KitPlayback", path: "../MagicPlayMan"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(name: "ProviderScene", path: "../ProviderScene"),
        .package(name: "ProviderStorage", path: "../ProviderStorage"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.3.4"),
    ],
    targets: [
        .target(
            name: "PluginPlayBack",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "MagicPlayMan", package: "KitPlayback"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/PluginPlayBack"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginPlayBackTests",
            dependencies: [
                "PluginPlayBack",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderScene", package: "ProviderScene"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
