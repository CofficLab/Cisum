// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderSettingsHost",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ProviderSettingsHost", targets: ["ProviderSettingsHost"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.13.0"),
    ],
    targets: [
        .target(
            name: "ProviderSettingsHost",
            dependencies: [
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
            ]
        ),
        .testTarget(
            name: "ProviderSettingsHostTests",
            dependencies: [
                "ProviderSettingsHost",
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Tests/ProviderSettingsHostTests"
        )
    ]
)
