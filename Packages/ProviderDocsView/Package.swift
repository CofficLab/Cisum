// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderDocsView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderDocsView", targets: ["ProviderDocsView"]),
    ],
    dependencies: [
        .package(name: "CisumKernelSupport", path: "../CisumKernelSupport"),
        .package(name: "CisumUIComponents", path: "../CisumUIComponents"),
    ],
    targets: [
        .target(
            name: "ProviderDocsView",
            dependencies: [
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
                .product(name: "CisumUIComponents", package: "CisumUIComponents"),
            ],
            path: ".",
            sources: ["Sources/ProviderDocsView"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderDocsViewTests",
            dependencies: [
                "ProviderDocsView",
                .product(name: "CisumKernelSupport", package: "CisumKernelSupport"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
