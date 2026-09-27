// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitEventObservation",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "KitEventObservation", targets: ["KitEventObservation"]),
    ],
    targets: [
        .target(name: "KitEventObservation"),
        .testTarget(
            name: "KitEventObservationTests",
            dependencies: ["KitEventObservation"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
