@testable import MagicPlayMan
import XCTest

// MARK: - AssetCache Tests

final class AssetCacheTests: XCTestCase {
    func testSeparatesDifferentURLsWithSameFilename() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let cache = try AssetCache(directory: root)
        let first = try XCTUnwrap(URL(string: "https://example.com/albums/one/track.mp3"))
        let second = try XCTUnwrap(URL(string: "https://cdn.example.net/library/two/track.mp3"))

        try cache.cache(Data("first".utf8), for: first)
        try cache.cache(Data("second".utf8), for: second)

        let firstCachedURL = try XCTUnwrap(cache.cachedURL(for: first))
        let secondCachedURL = try XCTUnwrap(cache.cachedURL(for: second))

        XCTAssertNotEqual(firstCachedURL, secondCachedURL)
        XCTAssertEqual(try Data(contentsOf: firstCachedURL), Data("first".utf8))
        XCTAssertEqual(try Data(contentsOf: secondCachedURL), Data("second".utf8))
    }

    func testHandlesLongSignedURLs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let cache = try AssetCache(directory: root)
        let token = String(repeating: "abcdef0123456789", count: 40)
        let url = try XCTUnwrap(URL(string: "https://cdn.example.com/audio/track.mp3?signature=\(token)"))

        try cache.cache(Data("audio".utf8), for: url)
        let cachedURL = try XCTUnwrap(cache.cachedURL(for: url))

        XCTAssertLessThan(cachedURL.lastPathComponent.count, 100)
        XCTAssertEqual(cachedURL.pathExtension, "mp3")
        XCTAssertEqual(try Data(contentsOf: cachedURL), Data("audio".utf8))
    }

    func testReportsCachedDataSize() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let cache = try AssetCache(directory: root)
        let first = try XCTUnwrap(URL(string: "https://example.com/audio/first.mp3"))
        let second = try XCTUnwrap(URL(string: "https://example.com/audio/second.mp3"))

        try cache.cache(Data(repeating: 1, count: 12), for: first)
        try cache.cache(Data(repeating: 2, count: 8), for: second)

        XCTAssertEqual(try cache.size(), 20)
    }

    func testFileSizePolicyReadsFoundationNumberAttributes() {
        XCTAssertEqual(AssetCacheFileSizePolicy.fileSize(from: [.size: NSNumber(value: 1234)]), 1234)
        XCTAssertEqual(AssetCacheFileSizePolicy.fileSize(from: [.size: Int64(5678)]), 5678)
        XCTAssertEqual(AssetCacheFileSizePolicy.fileSize(from: [.size: Int(90)]), 90)
        XCTAssertEqual(AssetCacheFileSizePolicy.fileSize(from: [.size: UInt64(42)]), 42)
    }

    func testFileSizePolicyNormalizesInvalidSizes() {
        XCTAssertEqual(AssetCacheFileSizePolicy.fileSize(from: [.size: NSNumber(value: -1234)]), 0)
        XCTAssertEqual(AssetCacheFileSizePolicy.fileSize(from: [:]), 0)
    }

    func testReplacesFileAtCacheDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try Data("not a directory".utf8).write(to: root)

        let cache = try AssetCache(directory: root)
        let url = try XCTUnwrap(URL(string: "https://cdn.example.com/audio/track.mp3"))
        try cache.cache(Data("audio".utf8), for: url)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertNotNil(cache.cachedURL(for: url))
    }

    func testReplacesDanglingSymlinkAtCacheDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cacheDirectory = root.appendingPathComponent("cache", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: cacheDirectory,
            withDestinationURL: root.appendingPathComponent("missing", isDirectory: true)
        )

        let cache = try AssetCache(directory: cacheDirectory)
        let url = try XCTUnwrap(URL(string: "https://cdn.example.com/audio/track.mp3"))
        try cache.cache(Data("audio".utf8), for: url)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheDirectory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertNotNil(cache.cachedURL(for: url))
    }
}
