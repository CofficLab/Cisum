// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MagicKit",  // 包名称
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),  // 最低支持 macOS 14
        .iOS(.v17)     // 最低支持 iOS 17
    ],
    // 定义对外提供的库（可被其他项目导入）
    products: [
        .library(name: "MagicKit", targets: ["MagicKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/chicio/ID3TagEditor", from: "4.5.0"),  // ID3 标签编辑器
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),  // ZIP 文件处理库
        .package(path: "../ProviderToast"),
    ],
    // 编译目标（模块）
    targets: [
       .target(
           name: "MagicKit",
           dependencies: [
               .product(name: "ProviderToast", package: "ProviderToast"),
               "ID3TagEditor",
               "ZIPFoundation",
           ],
           path: ".",
           exclude: [
               "README.md",
               "Tests",
               "Sources/MagicKit/Icons.xcassets",
               "Sources/MagicDemo/MagicDemo/Assets.xcassets",
               "Sources/MagicDemo/MagicDemo/Preview Content"
           ],
            sources: ["Sources"],
           resources: [.process("Resources")],
           swiftSettings: [
               .enableExperimentalFeature("StrictConcurrency=minimal"),
           ]
       ),
       .testTarget(
           name: "Tests",
           dependencies: ["MagicKit"],
           path: "Tests",
           swiftSettings: [
               .enableExperimentalFeature("StrictConcurrency=minimal"),
           ]
       )
    ],
    swiftLanguageModes: [.v5]
)
