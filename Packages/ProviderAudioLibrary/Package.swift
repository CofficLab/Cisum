// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderAudioLibrary",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderAudioLibrary", targets: ["ProviderAudioLibrary"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ProviderAudioLibrary",
            dependencies: [],
            path: "Sources/ProviderAudioLibrary"
        ),
        .testTarget(
            name: "ProviderAudioLibraryTests",
            dependencies: ["ProviderAudioLibrary"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
