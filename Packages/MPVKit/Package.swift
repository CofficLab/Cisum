// swift-tools-version: 6.0
import PackageDescription
import Foundation

// 内嵌的 mpv / FFmpeg 动态库。
//
// libmpv 依赖的 FFmpeg 库与它自己的非 FFmpeg 依赖一起放在同一个目录里，
// 全部以 `@rpath/<name>.dylib` 解析依赖——运行期由 App 的
// `@executable_path/../Frameworks` rpath 统一找到。
//
// 这里用 glob 而不是硬编码清单：构建脚本放进来什么就链什么。
let mpvDylibsDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/MPVC/dylibs")

let mpvDylibs: [String] = (try? FileManager.default
    .contentsOfDirectory(atPath: mpvDylibsDir.path))?
    .filter { $0.hasSuffix(".dylib") }
    .map { mpvDylibsDir.appendingPathComponent($0).path } ?? []

let package = Package(
    name: "CisumMPVKit",
    // mpv 的原生实现只存在于 macOS；其他平台编译出空模块，
    // 以便被依赖它的插件在 iOS / visionOS 上也能完成依赖解析。
    platforms: [.macOS(.v15), .iOS(.v17), .visionOS(.v2)],
    products: [
        .library(name: "MPVC", targets: ["MPVC"]),
        .library(name: "CisumMPVKit", targets: ["CisumMPVKit"]),
    ],

    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
    ],

    targets: [
        .target(
            name: "MPVC",
            path: "Sources/MPVC",
            exclude: [],
            sources: nil,
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ],
            // 原生 libmpv 的链接输入挂在暴露符号的 C target 上。
            linkerSettings: [
                .unsafeFlags(mpvDylibs, .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "CisumMPVKit",
            dependencies: ["MPVC", .product(name: "MagicKit", package: "KitMagic")],
            path: "Sources/MPVKit",
        ),
    ],
    swiftLanguageModes: [.v5]
)
