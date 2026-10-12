// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginRootView",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "PluginRootView", targets: ["PluginRootView"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.3.4"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderPlugin"),
    ],
    targets: [
        .target(
            name: "PluginRootView",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
