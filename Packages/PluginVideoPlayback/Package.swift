// swift-tools-version: 6.0
import PackageDescription
import Foundation

// 内嵌的 mpv / FFmpeg 动态库目录。
//
// App 构建时这些库会被拷贝进 `Contents/Frameworks` 并由 App 的 rpath 解析；
// 单测没有这一步，测试包因此需要自己指一条 rpath 过去。
let vendoredDylibsDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("../MPVKit/Sources/MPVC/dylibs")
    .standardizedFileURL

let package = Package(
    name: "PluginVideoPlayback",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "PluginVideoPlayback", targets: ["PluginVideoPlayback"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiUI", from: "1.17.1"),
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(path: "../HEVCDecoder"),
        .package(path: "../MPVKit"),
        .package(path: "../ProviderPlugin"),
        .package(path: "../ProviderVideo"),
    ],
    targets: [
        .target(
            name: "PluginVideoPlayback",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumMPVKit", package: "MPVKit"),
                .product(name: "HEVCDecoder", package: "HEVCDecoder"),
                "ProviderVideo",
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources"],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .testTarget(
            name: "PluginVideoPlaybackTests",
            dependencies: [
                "PluginVideoPlayback",
                "ProviderVideo",
            ],
            path: "Tests",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", vendoredDylibsDir.path])
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
