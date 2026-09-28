// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderTheme",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderTheme", targets: ["CisumProviderTheme"]),
    ],
    dependencies: [
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", exact: "1.4.0"),
        .package(path: "../KitEventObservation"),
        .package(path: "../KitAppEvents"),
    ],
    targets: [
        .target(
            name: "CisumProviderTheme",
            dependencies: [
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitEventObservation", package: "KitEventObservation"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderTheme"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderThemeTests",
            dependencies: [
                "CisumProviderTheme",
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
