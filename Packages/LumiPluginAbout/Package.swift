// swift-tools-version: 6.0
import PackageDescription

// LumiPluginAbout：设置界面「关于」页的共享实现（我们的应用 + 关于我们）。
//
// ## 本地 vendor 的原因
//
// 上游 https://github.com/CofficLab/LumiPluginAbout 的「我们的应用」目录
// （`CofficApps.all`）与分组脚注都是写死的，宿主只能配置官网与法律链接。
// Cisum 需要不同的产品清单且不展示脚注，上游没有对应配置项，因此按
// CONTRIBUTING「Vendored upstream packages」的约定 vendor 到本地：
// 目录结构与上游 2.0.0（12e2cc0）一致，改动仅限产品清单与脚注。
let package = Package(
    name: "LumiPluginAbout",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginAbout",
            targets: ["PluginAbout"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.12.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginAbout",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginAbout",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAboutTests",
            dependencies: [
                "PluginAbout",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
            ],
            path: "Tests/PluginAboutTests"
        ),
    ]
)
