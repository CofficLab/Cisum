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
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.6.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.8.0"),
        .package(path: "../ProviderPlugin"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(name: "ProviderScene", path: "../ProviderScene"),
        .package(name: "ProviderAudioLibrary", path: "../ProviderAudioLibrary"),
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
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
