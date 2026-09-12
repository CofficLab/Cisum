// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderStore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderStore", targets: ["ProviderStore"]),
    ],
    dependencies: [
        .package(path: "../MagicKit"),
        .package(path: "../CisumUIComponents"),
    ],
    targets: [
        .target(
            name: "ProviderStore",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderStore"],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .testTarget(
            name: "ProviderStoreTests",
            dependencies: ["ProviderStore"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
