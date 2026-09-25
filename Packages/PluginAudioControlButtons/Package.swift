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
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
        .package(name: "CisumKernelSupport", path: "../CisumKernelSupport"),
        .package(name: "MagicPlayMan", path: "../MagicPlayMan"),
        .package(path: "../ProviderPlayback"),
        .package(path: "../ProviderAudioNavigation"),
        .package(path: "../ProviderScene"),
        .package(name: "ProviderDocsView", path: "../ProviderDocsView"),
        .package(name: "ProviderRootView", path: "../ProviderRootView"),
        .package(name: "ProviderToast", path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "PluginAudioControlButtons",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
                .product(name: "MagicPlayMan", package: "MagicPlayMan"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderAudioNavigation", package: "ProviderAudioNavigation"),
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
            dependencies: ["PluginAudioControlButtons"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
