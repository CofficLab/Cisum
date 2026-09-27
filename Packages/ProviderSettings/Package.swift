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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "7031fda7ff72492d574ef9a4b5d9ffdc801a6660"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiUI", package: "LumiUI"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
