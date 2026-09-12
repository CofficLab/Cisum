// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderSettings",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderSettings", targets: ["ProviderSettings"]),
    ],
    dependencies: [
        .package(name: "KernelCore", path: "../KernelCore"),
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
        // MARK: - Provider Contracts（设置窗口只依赖能力契约，不依赖内核/工厂）
        .package(name: "ProviderAppState", path: "../ProviderAppState"),
        .package(name: "ProviderStorage", path: "../ProviderStorage"),
        .package(name: "ProviderScene", path: "../ProviderScene"),
        .package(name: "ProviderTheme", path: "../ProviderTheme"),
    ],
    targets: [
        .target(
            name: "ProviderSettings",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "ProviderAppState", package: "ProviderAppState"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderScene", package: "ProviderScene"),
                .product(name: "ProviderTheme", package: "ProviderTheme"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderSettings"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderSettingsTests",
            dependencies: [
                "ProviderSettings",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
