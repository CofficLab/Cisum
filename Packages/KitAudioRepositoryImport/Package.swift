// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitAudioRepositoryImport",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "KitAudioRepositoryImport", targets: ["KitAudioRepositoryImport"]),
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
    ],
    targets: [
        .target(
            name: "KitAudioRepositoryImport",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["Sources/KitAudioRepositoryImport"]
        ),
        .testTarget(
            name: "KitAudioRepositoryImportTests",
            dependencies: ["KitAudioRepositoryImport"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
