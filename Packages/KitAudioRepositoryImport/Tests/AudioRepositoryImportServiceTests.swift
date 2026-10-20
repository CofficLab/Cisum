import Foundation
import Testing
@testable import KitAudioRepositoryImport

/// 仓库导入机械流程的行为约束：
/// - 过滤：只保留受支持、且不重复的文件；
/// - 复制：文件落到仓库目录，重名自动加后缀；
/// - 回滚：库未就绪时复制结果被清理；
/// - 结果：结构化返回，文案由调用方决定。
struct AudioRepositoryImportServiceTests {
    private func makeAudioFile(named name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data("fake-audio".utf8).write(to: url)
        return url
    }

    @Test
    func supportedImportURLsFiltersUnsupportedFoldersAndDuplicates() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cisum-import-filter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let mp3 = try makeAudioFile(named: "a.mp3", in: root)
        let flac = try makeAudioFile(named: "b.flac", in: root)
        let text = try makeAudioFile(named: "c.txt", in: root)
        let folder = root.appendingPathComponent("folder.mp3")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let urls = AudioRepositoryImportService.supportedImportURLs(
            from: [mp3, flac, text, folder, mp3],
            supportedExtensions: ["mp3", "flac"]
        )

        #expect(urls.count == 2)
        #expect(AudioRepositoryFileIdentity.representsSameFile(urls[0], mp3))
        #expect(AudioRepositoryFileIdentity.representsSameFile(urls[1], flac))
    }

    @Test
    func importFilesReportsNoImportableFilesWhenNothingSupported() async {
        let outcome = await AudioRepositoryImportService.importFiles(
            [URL(fileURLWithPath: "/tmp/does-not-matter.txt")],
            audioDisk: URL(fileURLWithPath: "/tmp"),
            supportedExtensions: ["mp3"],
            isLibraryAvailable: { true },
            sync: { _ in }
        )

        #expect(outcome == .noImportableFiles)
    }

    @Test
    func importFilesReportsStorageUnavailableWhenDiskMissing() async {
        let outcome = await AudioRepositoryImportService.importFiles(
            [URL(fileURLWithPath: "/tmp/a.mp3")],
            audioDisk: nil,
            supportedExtensions: ["mp3"],
            isLibraryAvailable: { true },
            sync: { _ in }
        )

        #expect(outcome == .storageUnavailable)
    }

    @Test
    func importFilesCopiesIntoRepositoryAndSyncs() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cisum-import-ok-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = try makeAudioFile(named: "song.mp3", in: root)
        let repository = root.appendingPathComponent("repo", isDirectory: true)

        var synced: [URL] = []
        let outcome = await AudioRepositoryImportService.importFiles(
            [source],
            audioDisk: repository,
            supportedExtensions: ["mp3"],
            isLibraryAvailable: { true },
            sync: { urls in synced = urls }
        )

        #expect(outcome == .imported(skippedUnsupported: 0))
        #expect(synced.count == 1)
        #expect(synced[0].lastPathComponent == "song.mp3")
        #expect(FileManager.default.fileExists(atPath: synced[0].path))
    }

    @Test
    func importFilesRollsBackCopiesWhenLibraryUnavailable() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cisum-import-rollback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = try makeAudioFile(named: "song.mp3", in: root)
        let repository = root.appendingPathComponent("repo", isDirectory: true)

        var syncCalled = false
        let outcome = await AudioRepositoryImportService.importFiles(
            [source],
            audioDisk: repository,
            supportedExtensions: ["mp3"],
            isLibraryAvailable: { false },
            sync: { _ in syncCalled = true }
        )

        #expect(outcome == .libraryUnavailable)
        #expect(!syncCalled)

        let remaining = (try? FileManager.default.contentsOfDirectory(atPath: repository.path)) ?? []
        #expect(remaining.isEmpty)
    }

    @Test
    func importFilesCountsSkippedUnsupportedFiles() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cisum-import-skip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let mp3 = try makeAudioFile(named: "a.mp3", in: root)
        let txt = try makeAudioFile(named: "b.txt", in: root)
        let repository = root.appendingPathComponent("repo", isDirectory: true)

        let outcome = await AudioRepositoryImportService.importFiles(
            [mp3, txt],
            audioDisk: repository,
            supportedExtensions: ["mp3"],
            isLibraryAvailable: { true },
            sync: { _ in }
        )

        #expect(outcome == .imported(skippedUnsupported: 1))
    }
}
