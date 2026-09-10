// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KernelCore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KernelCore",
            targets: ["KernelCore"]
        ),
    ],
    dependencies: [
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
        .package(name: "MagicKit", path: "../MagicKit"),
        // MARK: - Provider Contracts（能力契约独立成包，与 Lumi 的 Provider* 体系对齐）
        .package(name: "ProviderAppState", path: "../ProviderAppState"),
        .package(name: "ProviderAudioLibrary", path: "../ProviderAudioLibrary"),
        .package(name: "ProviderAudioLike", path: "../ProviderAudioLike"),
        .package(name: "ProviderAudioNavigation", path: "../ProviderAudioNavigation"),
        .package(name: "ProviderCloud", path: "../ProviderCloud"),
        .package(name: "ProviderDevice", path: "../ProviderDevice"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(name: "ProviderStorage", path: "../ProviderStorage"),
        .package(name: "ProviderTheme", path: "../ProviderTheme"),
        .package(name: "ProviderToast", path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "KernelCore",
            dependencies: [
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "ProviderAppState", package: "ProviderAppState"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderAudioLike", package: "ProviderAudioLike"),
                .product(name: "ProviderAudioNavigation", package: "ProviderAudioNavigation"),
                .product(name: "ProviderCloud", package: "ProviderCloud"),
                .product(name: "ProviderDevice", package: "ProviderDevice"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderTheme", package: "ProviderTheme"),
                .product(name: "ProviderToast", package: "ProviderToast"),
            ],
            path: ".",
            sources: ["Sources/KernelCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KernelCoreTests",
            dependencies: [
                "KernelCore",
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
            ],
            path: "Tests/KernelCoreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
