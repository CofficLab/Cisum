// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderBook",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderBook", targets: ["ProviderBook"]),
        .library(name: "ProviderBookData", targets: ["ProviderBookData"]),
    ],
    dependencies: [
        .package(name: "KitMagic", path: "../MagicKit"),
        .package(name: "KitUIComponents", path: "../CisumUIComponents"),
        .package(url: "https://github.com/CofficLab/LumiUI", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "ProviderBook",
            dependencies: [
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: [
                "Sources/ProviderBook/BookPluginError.swift",
                "Sources/ProviderBook/BookPluginInfo.swift",
                "Sources/ProviderBook/BookProviding.swift",
                "Sources/ProviderBook/DTO/BookDTO.swift",
            ],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .target(
            name: "ProviderBookData",
            dependencies: [
                "ProviderBook",
                .product(name: "MagicKit", package: "KitMagic"),
                .product(name: "CisumUIComponents", package: "KitUIComponents"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: ["README.md", "Tests", "Resources"],
            sources: [
                "Sources/ProviderBook/BookConfig.swift",
                "Sources/ProviderBook/DB/BookRead.swift",
                "Sources/ProviderBook/DB/BookUpdate.swift",
                "Sources/ProviderBook/DB/BookWorker.swift",
                "Sources/ProviderBook/DTO/BookModelExt+DTO.swift",
                "Sources/ProviderBook/Models/BookModel.swift",
                "Sources/ProviderBook/Models/BookState.swift",
                "Sources/ProviderBook/Repo/BookCoverRepo.swift",
                "Sources/ProviderBook/Repo/BookDB.swift",
                "Sources/ProviderBook/Repo/BookPathContainment.swift",
                "Sources/ProviderBook/Repo/BookRepo.swift",
                "Sources/ProviderBook/Repo/BookSettingRepo.swift",
            ]
        ),
        .testTarget(
            name: "ProviderBookTests",
            dependencies: ["ProviderBook", "ProviderBookData"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
