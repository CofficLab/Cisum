import Foundation
import Testing
import UniformTypeIdentifiers
@testable import KitAudioRepositoryImport

/// 仓库导入的边界路径：权限、回滚、重名去重、拖放解析与文件身份判定。
struct AudioRepositoryImportEdgeCaseTests {
    private func makeTempDirectory(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeAudioFile(named name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data("fake-audio".utf8).write(to: url)
        return url
    }

    // MARK: - 导入结果与错误

    /// 结果类型本身不产出文案，但领域错误必须给出可读描述。
    @Test
    func permissionDeniedErrorHasReadableDescription() {
        #expect(
            AudioRepositoryImportError.permissionDenied.errorDescription
                == "Permission to access the original file was denied"
        )
    }

    // MARK: - 源文件访问权限

    /// 源文件可访问 = 拿到了安全作用域授权，或文件本身可读。
    @Test
    func sourceAccessNeedsGrantOrReadableFile() throws {
        let root = try makeTempDirectory("cisum-access")
        defer { try? FileManager.default.removeItem(at: root) }

        let readable = try makeAudioFile(named: "a.mp3", in: root)
        let missing = root.appendingPathComponent("missing.mp3")

        #expect(AudioRepositoryImportService.hasImportSourceAccess(readable, securityScopeGranted: true))
        #expect(AudioRepositoryImportService.hasImportSourceAccess(readable, securityScopeGranted: false))
        #expect(!AudioRepositoryImportService.hasImportSourceAccess(missing, securityScopeGranted: false))
        #expect(AudioRepositoryImportService.hasImportSourceAccess(missing, securityScopeGranted: true))
    }

    /// 源文件读不到时导入必须失败，绝不能报「已导入」，也不能留下半截文件。
    ///
    /// 具体落到哪个失败分支取决于运行环境的沙盒授权（`startAccessingSecurityScopedResource`
    /// 在非沙盒测试进程里可能直接放行），因此这里只钉住「不得声称导入成功」这条不变式，
    /// 加上「仓库里不留残骸」这条回滚约束。
    @Test
    func importDoesNotClaimSuccessForUnreadableSource() async throws {
        let root = try makeTempDirectory("cisum-unreadable")
        defer { try? FileManager.default.removeItem(at: root) }

        let missing = root.appendingPathComponent("missing.mp3")
        let repository = root.appendingPathComponent("repo", isDirectory: true)

        let outcome = await AudioRepositoryImportService.importFiles(
            [missing],
            audioDisk: repository,
            supportedExtensions: ["mp3"],
            isLibraryAvailable: { true },
            sync: { _ in }
        )

        if case .imported = outcome {
            Issue.record("源文件不存在时不得报告导入成功，实际得到 \(outcome)")
        }

        let remaining = (try? FileManager.default.contentsOfDirectory(atPath: repository.path)) ?? []
        #expect(remaining.isEmpty)
    }

    /// 仓库目录建不出来时属于「其它失败」，带人类可读原因。
    @Test
    func importReportsGenericFailureWhenRepositoryDirectoryCannotBeCreated() async throws {
        let root = try makeTempDirectory("cisum-blocked")
        defer { try? FileManager.default.removeItem(at: root) }

        // 用一个普通文件占住路径，仓库目录就建不出来。
        let blocker = root.appendingPathComponent("blocker")
        try Data("x".utf8).write(to: blocker)
        let repository = blocker.appendingPathComponent("repo", isDirectory: true)
        let source = try makeAudioFile(named: "a.mp3", in: root)

        let outcome = await AudioRepositoryImportService.importFiles(
            [source],
            audioDisk: repository,
            supportedExtensions: ["mp3"],
            isLibraryAvailable: { true },
            sync: { _ in }
        )

        guard case .failed = outcome else {
            Issue.record("期望 .failed，实际得到 \(outcome)")
            return
        }
    }

    // MARK: - 复制与回滚

    /// 中途失败时已复制的文件必须被回滚——仓库里不能留下「看得见、列表里没有」的死文件。
    @Test
    func copyRollsBackAlreadyCopiedFilesWhenLaterFileFails() async throws {
        let root = try makeTempDirectory("cisum-rollback")
        defer { try? FileManager.default.removeItem(at: root) }

        let good = try makeAudioFile(named: "good.mp3", in: root)
        let missing = root.appendingPathComponent("missing.mp3")
        let repository = root.appendingPathComponent("repo", isDirectory: true)

        await #expect(throws: (any Error).self) {
            _ = try await AudioRepositoryImportService.copyFilesInBackground([good, missing], to: repository)
        }

        let remaining = (try? FileManager.default.contentsOfDirectory(atPath: repository.path)) ?? []
        #expect(remaining.isEmpty)
    }

    /// 同名文件进仓库必须自动加序号后缀，不能互相覆盖。
    @Test
    func duplicateBaseNameGetsNumericSuffix() async throws {
        let root = try makeTempDirectory("cisum-dup")
        defer { try? FileManager.default.removeItem(at: root) }

        let dirA = root.appendingPathComponent("a", isDirectory: true)
        let dirB = root.appendingPathComponent("b", isDirectory: true)
        try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)
        let songA = try makeAudioFile(named: "song.mp3", in: dirA)
        let songB = try makeAudioFile(named: "song.mp3", in: dirB)
        let repository = root.appendingPathComponent("repo", isDirectory: true)

        let copied = try await AudioRepositoryImportService.copyFilesInBackground([songA, songB], to: repository)

        #expect(copied.count == 2)
        #expect(copied[0].lastPathComponent == "song.mp3")
        #expect(copied[1].lastPathComponent == "song 2.mp3")
    }

    /// 仓库里已存在同名**悬空符号链接**时也要让位——符号链接挡路不能被当成空位。
    @Test
    func danglingSymlinkInRepositoryAlsoForcesSuffix() async throws {
        let root = try makeTempDirectory("cisum-symlink")
        defer { try? FileManager.default.removeItem(at: root) }

        let source = try makeAudioFile(named: "song.mp3", in: root)
        let repository = root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        let dangling = repository.appendingPathComponent("song.mp3")
        try FileManager.default.createSymbolicLink(
            at: dangling,
            withDestinationURL: root.appendingPathComponent("gone.mp3")
        )

        let copied = try await AudioRepositoryImportService.copyFilesInBackground([source], to: repository)

        #expect(copied.count == 1)
        #expect(copied[0].lastPathComponent == "song 2.mp3")
    }

    /// 无扩展名的文件保持原名，不被补上扩展名。
    @Test
    func fileWithoutExtensionKeepsItsName() async throws {
        let root = try makeTempDirectory("cisum-noext")
        defer { try? FileManager.default.removeItem(at: root) }

        let source = try makeAudioFile(named: "noext", in: root)
        let repository = root.appendingPathComponent("repo", isDirectory: true)

        let copied = try await AudioRepositoryImportService.copyFilesInBackground([source], to: repository)

        #expect(copied.count == 1)
        #expect(copied[0].lastPathComponent == "noext")
    }
}

/// 仓库文件身份判定：同一性必须与导入去重用同一把尺子。
struct AudioRepositoryFileIdentityTests {
    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cisum-identity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// 非文件 URL（网络地址）按标准化后的绝对字符串判定。
    @Test
    func nonFileURLIdentityUsesStandardizedAbsoluteString() throws {
        let url = URL(string: "https://example.com/audio/../song.mp3")!

        #expect(
            AudioRepositoryFileIdentity.canonicalIdentity(for: url)
                == url.standardized.absoluteString
        )
    }

    /// 悬空符号链接无法解析，保留原路径——不能猜成别的文件。
    @Test
    func danglingSymlinkKeepsItsOwnPath() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("gone.mp3")
        let link = root.appendingPathComponent("link.mp3")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        #expect(
            AudioRepositoryFileIdentity.canonicalIdentity(for: link)
                == link.standardizedFileURL.path
        )
    }

    /// 正常符号链接解析到目标文件——它和目标文件是同一份。
    @Test
    func regularSymlinkResolvesToItsTarget() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("real.mp3")
        try Data("x".utf8).write(to: target)
        let link = root.appendingPathComponent("link.mp3")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        #expect(
            AudioRepositoryFileIdentity.canonicalIdentity(for: link)
                == target.resolvingSymlinksInPath().standardizedFileURL.path
        )
        #expect(AudioRepositoryFileIdentity.representsSameFile(link, target))
    }
}

/// 拖放来源解析：正常文件 URL、加载失败与批量汇总。
struct AudioRepositoryDropResolverTests {
    /// 拖放来源加载失败时抛出的错误。
    struct StubLoadError: Error {}

    /// 构造一个「加载必然失败」的 fileURL 来源。
    ///
    /// `NSItemProvider` 的加载方法在 Swift 侧不可覆写，这里改为注册一个必定失败的
    /// data representation：类型声明自己是 fileURL，取数据时却只给得出错误。
    private func makeFailingFileURLProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier,
            visibility: .all
        ) { completion in
            completion(nil, StubLoadError())
            return nil
        }
        return provider
    }

    /// 文件 URL 的拖放来源应被解析成原始 URL。
    @Test
    func resolvesFileURLFromItemProvider() async throws {
        let url = URL(fileURLWithPath: "/tmp/dropped-\(UUID().uuidString).mp3")
        let provider = NSItemProvider(item: url as NSURL, typeIdentifier: UTType.fileURL.identifier)

        let resolved = try await AudioRepositoryDropResolver.droppedFileURL(from: provider)

        #expect(resolved?.standardizedFileURL.path == url.standardizedFileURL.path)
    }

    /// 既不是文件 URL 也拿不到 URL 对象的来源返回 `nil`。
    @Test
    func returnsNilForProviderWithoutFileURL() async throws {
        let provider = NSItemProvider(
            item: NSData(data: Data("x".utf8)),
            typeIdentifier: UTType.data.identifier
        )

        let resolved = try await AudioRepositoryDropResolver.droppedFileURL(from: provider)

        #expect(resolved == nil)
    }

    /// 加载失败且拿不到替代 URL 时，必须把原始错误抛出去。
    ///
    /// `NSItemProvider` 会把 data representation 的失败包装进自己的错误域
    /// （`NSItemProviderErrorDomain`），原始错误保留在 `NSUnderlyingErrorKey` 里。
    @Test
    func propagatesLoadFailureWhenNoURLCanBeLoaded() async {
        let provider = makeFailingFileURLProvider()

        do {
            _ = try await AudioRepositoryDropResolver.droppedFileURL(from: provider)
            Issue.record("加载失败时必须抛错")
        } catch {
            let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? StubLoadError
            #expect(underlying != nil)
        }
    }

    /// 只提供 URL 对象的来源（没有 fileURL 数据表示）也能解析出文件 URL。
    @Test
    func resolvesURLFromPlainURLObjectProvider() async throws {
        let url = URL(fileURLWithPath: "/tmp/object-\(UUID().uuidString).mp3")
        let provider = NSItemProvider(item: url as NSURL, typeIdentifier: UTType.url.identifier)

        let resolved = try await AudioRepositoryDropResolver.droppedFileURL(from: provider)

        #expect(resolved?.standardizedFileURL.path == url.standardizedFileURL.path)
    }

    /// 批量解析要分拣：成功的进 urls，失败的进 errors，一个失败不拖累其它。
    @Test
    func batchSeparatesResolvedURLsFromFailures() async throws {
        let url = URL(fileURLWithPath: "/tmp/batch-\(UUID().uuidString).mp3")
        let good = NSItemProvider(item: url as NSURL, typeIdentifier: UTType.fileURL.identifier)
        let bad = makeFailingFileURLProvider()

        let result = await AudioRepositoryDropResolver.droppedFileURLs(from: [good, bad])

        #expect(result.urls.count == 1)
        #expect(result.errors.count == 1)
        #expect(result.urls[0].standardizedFileURL.path == url.standardizedFileURL.path)
    }
}
