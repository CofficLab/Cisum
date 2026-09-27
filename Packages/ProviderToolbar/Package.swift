// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderToolbar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderToolbar", targets: ["ProviderToolbar"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "7031fda7ff72492d574ef9a4b5d9ffdc801a6660"),
        .package(path: "../KitAppEvents"),
        .package(path: "../ProviderPlugin"),
        .package(name: "ProviderScene", path: "../ProviderScene"),
    ],
    targets: [
        .target(
            name: "ProviderToolbar",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPlugin", package: "ProviderPlugin"),
                .product(name: "KitAppEvents", package: "KitAppEvents"),
                .product(name: "ProviderScene", package: "ProviderScene"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/ProviderToolbar"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProviderToolbarTests",
            dependencies: ["ProviderToolbar"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
