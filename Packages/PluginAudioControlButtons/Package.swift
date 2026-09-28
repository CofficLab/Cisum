// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAudioControlButtons",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginAudioControlButtons",
            targets: ["PluginAudioControlButtons"]
        )
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(path: "../ProviderPlayback"),
        .package(path: "../ProviderAudioLibrary"),
        .package(path: "../ProviderAudioNavigation"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderScene"),
        .package(name: "ProviderRootView", path: "../ProviderRootView"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(name: "ProviderToast", path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "PluginAudioControlButtons",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderAudioNavigation", package: "ProviderAudioNavigation"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToast", package: "ProviderToast"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginAudioControlButtonsTests",
            dependencies: [
                "PluginAudioControlButtons",
                .product(name: "ProviderAudioNavigation", package: "ProviderAudioNavigation"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback")
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
