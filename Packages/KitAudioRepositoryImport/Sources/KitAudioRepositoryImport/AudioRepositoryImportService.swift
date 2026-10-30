import Foundation
import MagicKit
import OSLog

/// 仓库导入的机械流程：过滤 → 复制 → 同步。
///
/// 仓库视图（拖放 / 文件选择器）与空仓库引导共用这一份实现，避免两条路径
/// 行为分叉：过滤规则、复制策略、回滚时机完全一致。
///
/// 本 Kit 不产出面向用户的文案：结果以 `AudioRepositoryImportOutcome` 返回，
/// 由调用方按自己的语言环境映射成提示。
public enum AudioRepositoryImportService {
    private static let logger = Logger(subsystem: "com.coffic.cisum", category: "audio-repository-import")

    /// 导入一批文件：复制进仓库目录 → 同步索引。
    ///
    /// - Parameters:
    ///   - urls: 用户选择或拖入的原始文件。
    ///   - audioDisk: 仓库目录；`nil` 表示存储位置尚未就绪。
    ///   - supportedExtensions: 当前实现支持的音频扩展名。
    ///   - isLibraryAvailable: 音频库是否已就绪（复制后、入索引前复核）。
    ///   - sync: 把复制后的文件并入索引。
    /// - Returns: 导入结果。
    @MainActor
    public static func importFiles(
        _ urls: [URL],
        audioDisk: URL?,
        supportedExtensions: [String],
        isLibraryAvailable: @escaping @MainActor () -> Bool,
        sync: @escaping @MainActor ([URL]) async -> Void
    ) async -> AudioRepositoryImportOutcome {
        let importableURLs = supportedImportURLs(from: urls, supportedExtensions: supportedExtensions)
        guard !importableURLs.isEmpty else { return .noImportableFiles }

        let skippedUnsupported = urls.count - importableURLs.count

        guard let storageRoot = audioDisk else { return .storageUnavailable }

        let copiedURLs: [URL]
        do {
            copiedURLs = try await copyFiles(importableURLs, to: storageRoot)
        } catch AudioRepositoryImportError.permissionDenied {
            return .permissionDenied
        } catch {
            logger.error("复制文件失败：\(error.localizedDescription, privacy: .public)")
            return .failed(reason: error.localizedDescription)
        }

        guard isLibraryAvailable() else {
            // 库没就绪：复制出来的文件不进索引，直接回滚，避免仓库里留下
            // 「看得见文件、列表里没有」的死文件。
            cleanUpCopiedFiles(copiedURLs)
            return .libraryUnavailable
        }

        await sync(copiedURLs)
        return .imported(skippedUnsupported: skippedUnsupported)
    }

    /// 过滤出可导入的文件：排除文件夹、不受支持的扩展名与重复项。
    public nonisolated static func supportedImportURLs(
        from urls: [URL],
        supportedExtensions: [String]
    ) -> [URL] {
        let supportedExtensions = Set(supportedExtensions.map { $0.lowercased() })
        var seenIdentities = Set<String>()
        var supportedURLs: [URL] = []
        supportedURLs.reserveCapacity(urls.count)

        for url in urls {
            guard !url.isFolder, supportedExtensions.contains(url.pathExtension.lowercased()) else {
                continue
            }

            let identity = AudioRepositoryFileIdentity.canonicalIdentity(for: url)
            guard seenIdentities.insert(identity).inserted else {
                continue
            }

            supportedURLs.append(url)
        }

        return supportedURLs
    }

    /// 把文件复制进仓库目录（后台执行，避免阻塞主线程）。
    public nonisolated static func copyFiles(_ urls: [URL], to storageRoot: URL) async throws -> [URL] {
        try await Task.detached(priority: .userInitiated) {
            try await copyFilesInBackground(urls, to: storageRoot)
        }.value
    }

    /// 逐个复制文件；中途失败时回滚已复制的文件。
    public nonisolated static func copyFilesInBackground(_ urls: [URL], to storageRoot: URL) async throws -> [URL] {
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)

        var copiedURLs: [URL] = []

        do {
            for url in urls {
                let destination = uniqueDestination(for: url, in: storageRoot)
                try await copySecurityScopedFile(url, to: destination)
                copiedURLs.append(destination)
            }
        } catch {
            cleanUpCopiedFiles(copiedURLs)
            throw error
        }

        return copiedURLs
    }

    /// 删除已复制的文件（回滚用）。
    public nonisolated static func cleanUpCopiedFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// 源文件是否可读（沙盒授权或本身可读）。
    public nonisolated static func hasImportSourceAccess(_ source: URL, securityScopeGranted: Bool) -> Bool {
        securityScopeGranted || FileManager.default.isReadableFile(atPath: source.path)
    }

    // MARK: - 内部

    private nonisolated static func uniqueDestination(for source: URL, in directory: URL) -> URL {
        let baseName = source.deletingPathExtension().lastPathComponent
        let fileExtension = source.pathExtension
        let normalizedBaseName = baseName.isEmpty ? "Imported Audio" : baseName

        var candidate = destination(
            named: normalizedBaseName,
            pathExtension: fileExtension,
            in: directory
        )
        var suffix = 2

        while pathExistsIncludingSymlink(candidate) {
            candidate = destination(
                named: "\(normalizedBaseName) \(suffix)",
                pathExtension: fileExtension,
                in: directory
            )
            suffix += 1
        }

        return candidate
    }

    private nonisolated static func destination(named name: String, pathExtension: String, in directory: URL) -> URL {
        let destination = directory.appendingPathComponent(name)
        guard !pathExtension.isEmpty else {
            return destination
        }

        return destination.appendingPathExtension(pathExtension)
    }

    private nonisolated static func pathExistsIncludingSymlink(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.path) {
            return true
        }

        return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private nonisolated static func copySecurityScopedFile(_ source: URL, to destination: URL) async throws {
        let hasAccess = source.startAccessingSecurityScopedResource()
        guard hasImportSourceAccess(source, securityScopeGranted: hasAccess) else {
            throw AudioRepositoryImportError.permissionDenied
        }

        defer {
            if hasAccess {
                source.stopAccessingSecurityScopedResource()
            }
        }

        let sourceToCopy = copySourceURL(for: source)
        try await sourceToCopy.ensureLocalAvailability()

        try FileManager.default.copyItem(at: sourceToCopy, to: destination)
    }

    private nonisolated static func copySourceURL(for source: URL) -> URL {
        let resolvedSource = source.resolvingSymlinksInPath().standardizedFileURL
        guard FileManager.default.fileExists(atPath: resolvedSource.path) else {
            return source
        }

        return resolvedSource
    }
}
