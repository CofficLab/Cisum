// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderVideo",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "ProviderVideo", targets: ["ProviderVideo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI", from: "1.17.1"),
    ],
    targets: [
        .target(
            name: "ProviderVideo",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderVideo"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderVideoTests",
            dependencies: ["ProviderVideo"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
