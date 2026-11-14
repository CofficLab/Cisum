// swift-tools-version: 6.0
import PackageDescription

// LumiPluginSettingView：插件设置视图的共享实现。
//
// ## 本地 vendor 的原因
//
// 上游 https://github.com/CofficLab/LumiPluginSettingView 尚未适配 visionOS：
// `SettingViewProvider.swift` 里的 `CurrentAppIconView` / `MobilePluginSettingsShell`
// 用 `#elseif os(iOS)` 分流，visionOS 落到空分支，导致
// "cannot find 'CurrentAppIconView' in scope"。vendor 到本地后把这些分支
// 扩成 `#elseif os(iOS) || os(visionOS)`，并声明 visionOS 平台。
//
// 源码与上游 1.0.3（56fc485）保持一致，改动仅限 visionOS 适配。
let package = Package(
    name: "LumiPluginSettingView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "PluginSettingView", targets: ["PluginSettingView"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.1.1"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.17.1"),
    ],
    targets: [
        .target(
            name: "PluginSettingView",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginSettingViewTests",
            dependencies: [
                "PluginSettingView",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
            ]
        ),
    ]
)
