// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderCloud",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderCloud", targets: ["ProviderCloud"]),
    ],
    targets: [
        .target(name: "ProviderCloud", path: ".", exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderCloud"],
            resources: [.process("Resources")]),
        .testTarget(
            name: "ProviderCloudTests",
            dependencies: ["ProviderCloud"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
