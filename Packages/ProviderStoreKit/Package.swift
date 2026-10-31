// swift-tools-version: 6.0
import PackageDescription

// ProviderStoreKit：Cisum 侧的商店适配层。
//
// 分层（对齐 Coffic Lab 家族的分层纪律）：
// - ProviderStore（LumiProviders）：商店**契约**（档位、权益快照、能力协议）。
// - KitStoreKit（LumiStoreKit）：商店**机制**（交易监听、校准、拉取、购买、验证）。
// - ProviderStoreKit（本包）：Cisum 的**商品表与展示模型**（DTO、订阅组、档位文案）。
//
// 依赖方向：ProviderStoreKit → {ProviderStore 契约, KitStoreKit 机制}。
// 本包不含通用机制实现，三项目共用同一份 Kit。
let package = Package(
    name: "ProviderStoreKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderStoreKit", targets: ["ProviderStoreKit"]),
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.17.0"),
        .package(url: "https://github.com/CofficLab/LumiStoreKit.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.11.1"),
    ],
    targets: [
        .target(
            name: "ProviderStoreKit",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "ProviderStore", package: "LumiProviders"),
                .product(name: "KitStoreKit", package: "LumiStoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderStoreKit"],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .testTarget(
            name: "ProviderStoreKitTests",
            dependencies: ["ProviderStoreKit"],
            path: "Tests",
            exclude: ["TestPlan.md"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
