// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CisumKernelSupport",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "CisumKernelSupport",
            targets: ["CisumKernelSupport"]
        ),
    ],
    dependencies: [
        // 共享内核：远程 LumiKernel（Provider 注册表、插件生命周期引擎、贡献 Token）。
        // 本包只承载 Cisum 应用特有层：UI 贡献注册表、事件系统、主题/状态服务、
        // 插件协议兼容扩展。
        .package(name: "LumiKernel", url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
        .package(name: "MagicKit", path: "../MagicKit"),
        .package(name: "ProviderAppState", path: "../ProviderAppState"),
        .package(name: "ProviderAudioLibrary", path: "../ProviderAudioLibrary"),
        .package(name: "ProviderCloud", path: "../ProviderCloud"),
        .package(name: "ProviderDevice", path: "../ProviderDevice"),
        .package(name: "ProviderPlayback", path: "../ProviderPlayback"),
        .package(name: "ProviderStorage", path: "../ProviderStorage"),
        .package(name: "ProviderTheme", path: "../ProviderTheme"),
    ],
    targets: [
        .target(
            name: "CisumKernelSupport",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "ProviderAppState", package: "ProviderAppState"),
                .product(name: "ProviderAudioLibrary", package: "ProviderAudioLibrary"),
                .product(name: "ProviderCloud", package: "ProviderCloud"),
                .product(name: "ProviderDevice", package: "ProviderDevice"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderTheme", package: "ProviderTheme"),
            ],
            path: ".",
            sources: ["Sources/CisumKernelSupport"]
        ),
        .testTarget(
            name: "CisumKernelSupportTests",
            dependencies: ["CisumKernelSupport"],
            path: "Tests/CisumKernelSupportTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
