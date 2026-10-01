// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitAppEvents",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "KitAppEvents", targets: ["KitAppEvents"]),
    ],
    targets: [
        .target(
            name: "KitAppEvents",
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/KitAppEvents"]
        ),
        .testTarget(
            name: "KitAppEventsTests",
            dependencies: ["KitAppEvents"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
