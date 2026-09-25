// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CisumKernel",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "CisumKernel",
            targets: ["CisumKernel"]
        ),
    ],
    dependencies: [
        // 共享内核：所有 Coffic App 共用的远程 LumiKernel（Provider 注册表与生命周期核心）。
        // CisumKernelContainer 门面持有 KernelCoreContainer 并委托注册/解析，应用特有
        // 服务（事件、插件管理、主题、UI 贡献）保留在本包。
        .package(name: "LumiKernel", url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
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
            name: "CisumKernel",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
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
            sources: ["Sources/CisumKernel"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CisumKernelTests",
            dependencies: [
                "CisumKernel",
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
            ],
            path: "Tests/CisumKernelTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
