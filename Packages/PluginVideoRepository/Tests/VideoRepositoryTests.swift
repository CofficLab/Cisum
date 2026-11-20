import XCTest
@testable import PluginVideoRepository

final class VideoRepositoryScannerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoRepositoryScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testScanFindsSupportedExtensionsRecursively() throws {
        try Data("x".utf8).write(to: directory.appendingPathComponent("a.mp4"))
        try Data("x".utf8).write(to: directory.appendingPathComponent("b.txt"))
        let nested = directory.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: nested.appendingPathComponent("c.mkv"))

        let scanned = VideoRepositoryScanner.scan(directory: directory)

        XCTAssertEqual(scanned.map(\.relativePath), ["a.mp4", "nested/c.mkv"])
    }

    func testScanSkipsHiddenFiles() throws {
        try Data("x".utf8).write(to: directory.appendingPathComponent(".hidden.mp4"))
        try Data("x".utf8).write(to: directory.appendingPathComponent("visible.mp4"))

        let scanned = VideoRepositoryScanner.scan(directory: directory)

        XCTAssertEqual(scanned.map(\.relativePath), ["visible.mp4"])
    }

    func testRelativePathUsesRootPrefix() {
        let root = "/tmp/repo"
        let url = URL(fileURLWithPath: "/tmp/repo/sub/a.mp4")
        XCTAssertEqual(VideoRepositoryScanner.relativePath(of: url, under: root), "sub/a.mp4")
    }
}

final class VideoMetadataStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoMetadataStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMetadataPersistsAcrossInstances() {
        let store = VideoMetadataStore(directory: directory)
        store.update(VideoMetadata(tags: ["旅行"], rating: 4, isFavorite: true), for: "a.mp4")

        let reloaded = VideoMetadataStore(directory: directory)
        XCTAssertEqual(reloaded.metadata(for: "a.mp4").tags, ["旅行"])
        XCTAssertEqual(reloaded.metadata(for: "a.mp4").rating, 4)
        XCTAssertTrue(reloaded.metadata(for: "a.mp4").isFavorite)
    }

    func testMigrateMovesEntryToNewPath() {
        let store = VideoMetadataStore(directory: directory)
        store.update(VideoMetadata(tags: ["a"]), for: "old.mp4")
        store.migrate(from: "old.mp4", to: "new.mp4")

        XCTAssertTrue(store.metadata(for: "old.mp4").tags.isEmpty)
        XCTAssertEqual(store.metadata(for: "new.mp4").tags, ["a"])
    }

    func testUnknownPathReturnsEmptyMetadata() {
        let store = VideoMetadataStore(directory: directory)
        XCTAssertEqual(store.metadata(for: "missing.mp4"), .empty)
    }
}
