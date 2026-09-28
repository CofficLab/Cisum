// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderPlugin", targets: ["ProviderPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.0.0"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
        .package(path: "../KitEventObservation"),
    ],
    targets: [
        .target(
            name: "ProviderPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitEventObservation", package: "KitEventObservation"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderPlugin"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderPluginTests",
            dependencies: [
                "ProviderPlugin",
                .product(name: "KernelCore", package: "LumiKernel"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
