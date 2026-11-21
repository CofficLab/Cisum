// swift-tools-version: 6.0
import PackageDescription
import Foundation

let package = Package(
    name: "HEVCDecoder",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "HEVCDecoder", targets: ["HEVCDecoder"]),
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
    ],
    targets: [
        .target(
            name: "HEVCDecoder",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
            ],
            path: "Sources/HEVCDecoder"
        ),
    ],
    swiftLanguageModes: [.v5]
)
