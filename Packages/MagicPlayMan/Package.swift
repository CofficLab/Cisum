// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KitPlayback",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v2),
    ],
    products: [
        .library(
            name: "MagicPlayMan",
            targets: ["MagicPlayMan"]
        )
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(path: "../ProviderPlayback"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.12.0"),
    ],
    targets: [
        .target(
            name: "MagicPlayMan",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "ProviderPlayback", package: "ProviderPlayback"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            sources: ["Sources"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MagicPlayManTests",
            dependencies: [
                "MagicPlayMan",
                .product(name: "ProviderPlayback", package: "ProviderPlayback")
            ],
            path: "Tests"
        )
    ],
    // 保持 Swift 5 语言模式：tools-version 从 5.9 升到 6.0 只是为了用
    // `.visionOS(.v2)` 版本枚举，语言模式不变，避免引入 Swift 6 严格并发报错。
    swiftLanguageModes: [.v5]
)
