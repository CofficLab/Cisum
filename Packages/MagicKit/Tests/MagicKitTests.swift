import XCTest
@testable import MagicKit

final class MagicKitTests: XCTestCase {
    func testExample() throws {
        // This is an example test case
        XCTAssertTrue(true)
    }

    func testToURLKeepsValidURL() {
        let url = "https://example.com/path".toURL()

        XCTAssertEqual(url.absoluteString, "https://example.com/path")
    }

    func testToURLFallsBackToFileURLForInvalidURLString() {
        let url = "http://[::1".toURL()

        XCTAssertTrue(url.isFileURL)
    }

    func testToMarkdownConvertsCommonHtmlElements() {
        let html = """
        <h1><strong>Title</strong></h1><p>Read <a href="https://example.com">more</a></p><img src="cover.png" alt="Cover">
        """

        let markdown = html.toMarkdown()

        XCTAssertTrue(markdown.contains("# Title"))
        XCTAssertTrue(markdown.contains("[more](https://example.com)"))
        XCTAssertTrue(markdown.contains("![Cover](cover.png)"))
    }

    func testSampleURLsKeepRemoteSchemes() {
        XCTAssertEqual(URL.sample_web_mp3_kennedy.scheme, "https")
        XCTAssertEqual(URL.sample_web_mp4_bunny.scheme, "http")
        XCTAssertEqual(URL.sample_web_stream_basic.pathExtension, "m3u8")
    }

    func testEnsureLocalAvailabilityReturnsForLocalFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("track.mp3")
        try Data("audio".utf8).write(to: file)

        try await file.ensureLocalAvailability(timeout: 0.1, pollInterval: 0.05)
    }

    /// 非 iCloud 文件必须一律视为「内容已在本地」，否则播放路径会误触发下载等待。
    func testLocalFileHasLocalContent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("track.mp3")
        try Data("audio".utf8).write(to: file)

        XCTAssertTrue(file.hasLocalContent)
        XCTAssertFalse(file.appendingPathExtension("missing").hasLocalContent)
    }

    /// 空文件没有内容需要下载，不应被判为「内容不在本地」。
    func testEmptyLocalFileHasLocalContent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("empty.mp3")
        try Data().write(to: file)

        XCTAssertTrue(file.hasLocalContent)
    }

    func testCopyToRejectsCopyingFileOntoItselfWithoutDeletingSource() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("track.mp3")
        let originalData = Data("audio".utf8)
        try originalData.write(to: file)

        do {
            try await file.copyTo(file, verbose: false, caller: "test")
            XCTFail("Copying a file onto itself should throw")
        } catch {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
            XCTAssertEqual(try Data(contentsOf: file), originalData)
        }
    }

    func testCopyToRejectsCopyingFolderIntoDescendantWithoutDeletingChild() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let source = root.appendingPathComponent("source", isDirectory: true)
        let child = source.appendingPathComponent("child", isDirectory: true)
        let childFile = child.appendingPathComponent("keep.txt")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: childFile)

        do {
            try await source.copyTo(child, verbose: false, caller: "test")
            XCTFail("Copying a folder into its child should throw")
        } catch {
            XCTAssertTrue(FileManager.default.fileExists(atPath: child.path))
            XCTAssertEqual(try Data(contentsOf: childFile), Data("keep".utf8))
        }
    }

    func testCopyToCopiesSymlinkedFileAsStandaloneFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let external = root.appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let realFile = external.appendingPathComponent("real.mp3")
        let linkedFile = root.appendingPathComponent("linked.mp3")
        let destination = root.appendingPathComponent("copied.mp3")
        try Data("audio".utf8).write(to: realFile)
        try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: realFile)

        try await linkedFile.copyTo(destination, verbose: false, caller: "test")

        let fileType = try FileManager.default.attributesOfItem(atPath: destination.path)[.type] as? FileAttributeType
        XCTAssertEqual(fileType, .typeRegular)
        XCTAssertEqual(try Data(contentsOf: destination), Data("audio".utf8))
    }

    func testCopyToReplacesDanglingDestinationSymlink() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source.txt")
        let destination = root.appendingPathComponent("destination.txt")
        let missingTarget = root.appendingPathComponent("missing-target.txt")
        try Data("copied".utf8).write(to: source)
        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: missingTarget)

        XCTAssertTrue(destination.pathExistsIncludingSymbolicLink)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))

        try await source.copyTo(destination, verbose: false, caller: "test")

        let fileType = try FileManager.default.attributesOfItem(atPath: destination.path)[.type] as? FileAttributeType
        XCTAssertEqual(fileType, .typeRegular)
        XCTAssertEqual(try Data(contentsOf: destination), Data("copied".utf8))
    }

    func testSameFileLocationNormalizesRelativeSegments() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("track.mp3")
        let equivalent = root
            .appendingPathComponent("subdir")
            .appendingPathComponent("..")
            .appendingPathComponent("track.mp3")

        XCTAssertTrue(file.isSameFileLocation(as: equivalent))
    }

    func testSameFileLocationKeepsDistinctDanglingSymlinksSeparate() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let missingFile = root.appendingPathComponent("missing.mp3")
        let firstLink = root.appendingPathComponent("first.mp3")
        let secondLink = root.appendingPathComponent("second.mp3")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingFile)
        try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingFile)

        XCTAssertFalse(firstLink.isSameFileLocation(as: secondLink))
    }

    func testMagicLoggerClearLogsFromBackgroundClearsOnMainThread() async throws {
        let logger = MagicLogger(app: "MagicKitTests")
        logger.info("background clear setup")
        try await Task.sleep(nanoseconds: 50_000_000)

        await MainActor.run {
            XCTAssertFalse(logger.logs.isEmpty)
        }

        await Task.detached {
            logger.clearLogs()
        }.value
        try await Task.sleep(nanoseconds: 50_000_000)

        await MainActor.run {
            XCTAssertTrue(logger.logs.isEmpty)
        }
    }

    func testICloudPlaceholderIsNotTreatedAsDownloadedJustBecauseItExists() {
        XCTAssertTrue(URLDownloadAvailabilityPolicy.isDownloaded(
            fileExists: true,
            isUbiquitousItem: false,
            downloadingStatus: nil
        ))
        XCTAssertTrue(URLDownloadAvailabilityPolicy.isDownloaded(
            fileExists: true,
            isUbiquitousItem: true,
            downloadingStatus: .current
        ))
        XCTAssertFalse(URLDownloadAvailabilityPolicy.isDownloaded(
            fileExists: true,
            isUbiquitousItem: true,
            downloadingStatus: .notDownloaded
        ))
        XCTAssertFalse(URLDownloadAvailabilityPolicy.isDownloaded(
            fileExists: true,
            isUbiquitousItem: true,
            downloadingStatus: .downloaded
        ))
    }

    func testDownloadProgressPolicyClampsInvalidValues() {
        XCTAssertEqual(URLDownloadProgressPolicy.normalizedFraction(percentDownloaded: nil), 0)
        XCTAssertEqual(URLDownloadProgressPolicy.normalizedFraction(percentDownloaded: .nan), 0)
        XCTAssertEqual(URLDownloadProgressPolicy.normalizedFraction(percentDownloaded: -25), 0)
        XCTAssertEqual(URLDownloadProgressPolicy.normalizedFraction(percentDownloaded: 40), 0.4)
        XCTAssertEqual(URLDownloadProgressPolicy.normalizedFraction(percentDownloaded: 140), 1)

        XCTAssertEqual(URLDownloadProgressPolicy.normalizedFraction(downloadedSize: nil, totalSize: 100), 0)
        XCTAssertEqual(URLDownloadProgressPolicy.normalizedFraction(downloadedSize: 50, totalSize: nil), 0)
        XCTAssertEqual(URLDownloadProgressPolicy.normalizedFraction(downloadedSize: -50, totalSize: 100), 0)
        XCTAssertEqual(URLDownloadProgressPolicy.normalizedFraction(downloadedSize: 50, totalSize: 100), 0.5)
        XCTAssertEqual(URLDownloadProgressPolicy.normalizedFraction(downloadedSize: 120, totalSize: 100), 1)
    }

    func testDirectoryContainmentDoesNotMatchSiblingPrefix() {
        let parent = "/tmp/Cisum/Documents"

        XCTAssertTrue(URLDirectoryContainmentPolicy.contains(
            "/tmp/Cisum/Documents",
            inDirectory: parent
        ))
        XCTAssertTrue(URLDirectoryContainmentPolicy.contains(
            "/tmp/Cisum/Documents/Audio/Track.mp3",
            inDirectory: parent
        ))
        XCTAssertFalse(URLDirectoryContainmentPolicy.contains(
            "/tmp/Cisum/Documents Backup/Track.mp3",
            inDirectory: parent
        ))
    }

    func testDirectoryContainmentTreatsRootAsParentOfAbsolutePaths() {
        XCTAssertTrue(URLDirectoryContainmentPolicy.contains(
            "/tmp/Cisum/Documents/Audio/Track.mp3",
            inDirectory: "/"
        ))
        XCTAssertFalse(URLDirectoryContainmentPolicy.contains(
            "tmp/Cisum/Documents/Audio/Track.mp3",
            inDirectory: "/"
        ))
    }

    func testOpenActionOnlyAllowsExistingLocalFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let existingFile = root.appendingPathComponent("track.mp3")
        let missingFile = root.appendingPathComponent("missing.mp3")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: existingFile)

        XCTAssertTrue(URLOpenActionPolicy.canOpen(existingFile))
        XCTAssertFalse(URLOpenActionPolicy.canOpen(missingFile))
        XCTAssertTrue(URLOpenActionPolicy.canOpen(URL(string: "https://example.com")!))
    }

    func testRevealInFinderAllowsExistingPathsAndSymlinksOnly() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let existingFile = root.appendingPathComponent("track.mp3")
        let missingFile = root.appendingPathComponent("missing.mp3")
        let danglingLink = root.appendingPathComponent("dangling.mp3")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: existingFile)
        try FileManager.default.createSymbolicLink(
            at: danglingLink,
            withDestinationURL: root.appendingPathComponent("deleted-target.mp3")
        )

        XCTAssertTrue(URLOpenActionPolicy.canRevealInFinder(existingFile))
        XCTAssertTrue(URLOpenActionPolicy.canRevealInFinder(danglingLink))
        XCTAssertFalse(URLOpenActionPolicy.canRevealInFinder(missingFile))
        XCTAssertFalse(URLOpenActionPolicy.canRevealInFinder(URL(string: "https://example.com")!))
    }

    func testImageCropping() {
        // 暂时跳过此测试，因为缺少相关的图像处理功能
        // let originalImage = UIImage(named: "testImage")!
        // let croppedImage = MagicKit.cropImage(originalImage, to: CGRect(x: 0, y: 0, width: 100, height: 100))
        // 
        // XCTAssertNotNil(croppedImage)
        // XCTAssertEqual(croppedImage.size, CGSize(width: 100, height: 100))
    }

    // Add more test methods here
}
