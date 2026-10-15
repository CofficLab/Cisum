// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderCloudDownload",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderCloudDownload", targets: ["ProviderCloudDownload"]),
    ],
    dependencies: [
        .package(path: "../KitEventObservation"),
    ],
    targets: [
        .target(
            name: "ProviderCloudDownload",
            dependencies: [
                .product(name: "KitEventObservation", package: "KitEventObservation"),
            ],
            path: "Sources/ProviderCloudDownload"
        ),
        .testTarget(
            name: "ProviderCloudDownloadTests",
            dependencies: ["ProviderCloudDownload"],
            path: "Tests",
            exclude: ["TestPlan.md"]
        ),
    ],
    swiftLanguageModes: [.v5]
)