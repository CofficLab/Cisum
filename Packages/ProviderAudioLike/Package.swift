// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderAudioLike",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderAudioLike", targets: ["ProviderAudioLike"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ProviderAudioLike",
            dependencies: [],
            path: "Sources/ProviderAudioLike",
            resources: []
        ),
        .testTarget(
            name: "ProviderAudioLikeTests",
            dependencies: ["ProviderAudioLike"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
