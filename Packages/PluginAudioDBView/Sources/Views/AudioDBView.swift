import CisumUIComponents
import Foundation
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import ProviderAudioLibrary

// NSItemProvider is thread-safe by design but not yet marked Sendable by Apple.
extension NSItemProvider: @retroactive @unchecked Sendable {}

@MainActor
public struct AudioDBView: View, SuperLog, SuperThread, SuperEvent {
    public nonisolated static let emoji = "🐘"
    public nonisolated static let verbose = false

    @Environment(\.audioDBDependencies) private var dependencies
    @EnvironmentObject private var dbViewModel: AudioDBViewModel
    @LumiTheme private var appTheme
    private let isDemoMode: Bool

    /// 是否正在拖拽音频文件
    @State private var isDropping: Bool = false

    /// 是否正在复制导入文件
    @State private var isImportingFiles: Bool = false

    public init(isDemoMode: Bool) {
        self.isDemoMode = isDemoMode
    }

    public var body: some View {
        if Self.verbose {
            os_log("\(self.t)📺 Rendering")
        }

        return Group {
            if isDemoMode {
                EmptyView()
            } else {
                AudioList()
            }
        }
        .overlay(alignment: .center) {
            if dbViewModel.isSorting {
                AudioDBTips(variant: .sorting, sortingMessage: dbViewModel.sortMode.description)
                    .transition(.opacity)
            }
        }
        .frame(maxHeight: .infinity)
        .background(appTheme.background.ignoresSafeArea())
        .fileImporter(
            isPresented: dependencies.isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true,
            onCompletion: handleFileImport
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropping, perform: handleDrop)
    }
}

// MARK: - Action

extension AudioDBView {
    /// 获取存储根目录
    ///
    /// 异步获取音频文件的存储根目录路径。
    ///
    /// - Returns: 存储根目录的 URL
    private func fetchStorageRoot() async -> URL? {
        dependencies.audioDisk()
    }

    /// 复制文件到存储目录
    ///
    /// 将选中的音频文件复制到应用的存储目录中。
    ///
    /// - Parameters:
    ///   - urls: 要复制的文件 URL 列表
    ///   - storageRoot: 目标存储根目录
    private func copyFiles(_ urls: [URL], to storageRoot: URL) async throws -> [URL] {
        if Self.verbose {
            os_log("\(self.t)📋 Preparing to copy \(urls.count) files")
        }

        return try await Task.detached(priority: .userInitiated) {
            try await Self.copyFilesInBackground(urls, to: storageRoot)
        }.value
    }

    nonisolated static func copyFilesInBackground(_ urls: [URL], to storageRoot: URL) async throws -> [URL] {
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)

        var copiedURLs: [URL] = []

        do {
            // 逐个复制文件
            for url in urls {
                let destination = Self.uniqueDestination(for: url, in: storageRoot)

                if Self.verbose {
                    os_log("\(Self.t)📄 Copying: \(url.lastPathComponent)")
                }

                try await copySecurityScopedFile(url, to: destination)
                copiedURLs.append(destination)
            }
        } catch {
            for copiedURL in copiedURLs {
                try? FileManager.default.removeItem(at: copiedURL)
            }
            throw error
        }

        if Self.verbose {
            os_log("\(Self.t)✅ All files copied")
        }

        return copiedURLs
    }

    nonisolated static func cleanUpCopiedFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    nonisolated static func supportedImportURLs(from urls: [URL], supportedExtensions: [String]) -> [URL] {
        let supportedExtensions = Set(supportedExtensions.map { $0.lowercased() })
        var seenIdentities = Set<String>()
        var supportedURLs: [URL] = []
        supportedURLs.reserveCapacity(urls.count)

        for url in urls {
            guard !url.isFolder && supportedExtensions.contains(url.pathExtension.lowercased()) else {
                continue
            }

            let identity = canonicalImportSourceIdentity(for: url)
            guard seenIdentities.insert(identity).inserted else {
                continue
            }

            supportedURLs.append(url)
        }

        return supportedURLs
    }

    nonisolated static func representsSameImportSource(_ lhs: URL, _ rhs: URL) -> Bool {
        canonicalImportSourceIdentity(for: lhs) == canonicalImportSourceIdentity(for: rhs)
    }

    nonisolated static func canonicalImportSourceIdentity(for url: URL) -> String {
        AudioListFileIdentity.canonicalIdentity(for: url)
    }

    nonisolated static func droppedFileURL(from provider: NSItemProvider) async throws -> URL? {
        var fileURLDataError: Error?

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            do {
                let data: Data? = try await withCheckedThrowingContinuation { continuation in
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: data)
                        }
                    }
                }

                if let data, let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL {
                    return url
                }
            } catch {
                fileURLDataError = error
            }
        }

        if let url = try await droppedURLObject(from: provider) {
            return url
        }

        if let fileURLDataError {
            throw fileURLDataError
        }

        return nil
    }

    nonisolated private static func droppedURLObject(from provider: NSItemProvider) async throws -> URL? {
        guard provider.canLoadObject(ofClass: URL.self) else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: object)
                }
            }
        }
    }

    nonisolated static func droppedFileURLs(from providers: [NSItemProvider]) async -> (urls: [URL], errors: [Error]) {
        var urls: [URL] = []
        var errors: [Error] = []

        for provider in providers {
            do {
                if let url = try await droppedFileURL(from: provider) {
                    urls.append(url)
                }
            } catch {
                errors.append(error)
            }
        }

        return (urls, errors)
    }

    nonisolated static func shouldImportDroppedURLs(_ urls: [URL], after errors: [Error]) -> Bool {
        !urls.isEmpty
    }

    nonisolated static func shouldReportDroppedURLLoadFailure(_ urls: [URL], errors: [Error]) -> Bool {
        urls.isEmpty && !errors.isEmpty
    }

    nonisolated static func shouldReportPartialDroppedURLLoadFailure(_ urls: [URL], errors: [Error]) -> Bool {
        !urls.isEmpty && !errors.isEmpty
    }

    nonisolated static func shouldStartImport(isImporting: Bool) -> Bool {
        !isImporting
    }

    nonisolated static func hasImportSourceAccess(_ source: URL, securityScopeGranted: Bool) -> Bool {
        securityScopeGranted || FileManager.default.isReadableFile(atPath: source.path)
    }

    nonisolated private static func uniqueDestination(for source: URL, in directory: URL) -> URL {
        let baseName = source.deletingPathExtension().lastPathComponent
        let fileExtension = source.pathExtension
        let normalizedBaseName = baseName.isEmpty ? "Imported Audio" : baseName

        var candidate = destination(
            named: normalizedBaseName,
            pathExtension: fileExtension,
            in: directory
        )
        var suffix = 2

        while Self.pathExistsIncludingSymlink(candidate) {
            candidate = destination(
                named: "\(normalizedBaseName) \(suffix)",
                pathExtension: fileExtension,
                in: directory
            )
            suffix += 1
        }

        return candidate
    }

    nonisolated private static func pathExistsIncludingSymlink(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.path) {
            return true
        }

        return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    nonisolated private static func copySecurityScopedFile(_ source: URL, to destination: URL) async throws {
        let hasAccess = source.startAccessingSecurityScopedResource()
        guard hasImportSourceAccess(source, securityScopeGranted: hasAccess) else {
            throw NSError(
                domain: "AudioDBView",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "Permission to access the original file was denied", bundle: .module)
                ]
            )
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

    nonisolated private static func copySourceURL(for source: URL) -> URL {
        let resolvedSource = source.resolvingSymlinksInPath().standardizedFileURL
        guard FileManager.default.fileExists(atPath: resolvedSource.path) else {
            return source
        }

        return resolvedSource
    }

    nonisolated private static func destination(named name: String, pathExtension: String, in directory: URL) -> URL {
        let destination = directory.appendingPathComponent(name)
        guard !pathExtension.isEmpty else {
            return destination
        }

        return destination.appendingPathExtension(pathExtension)
    }

    private func importFiles(_ urls: [URL]) async {
        if Self.verbose {
            os_log("\(self.t)📥 Handling file import, count: \(urls.count)")
        }

        guard Self.shouldStartImport(isImporting: isImportingFiles) else {
            alert_warning(String(localized: "Import is already in progress", bundle: .module))
            return
        }

        isImportingFiles = true
        defer {
            isImportingFiles = false
        }

        let importableURLs = Self.supportedImportURLs(
            from: urls,
            supportedExtensions: dependencies.supportedExtensions
        )

        guard !importableURLs.isEmpty else {
            alert_error(String(localized: "No files were added", bundle: .module))
            return
        }

        if importableURLs.count < urls.count {
            alert_warning(String(localized: "Some files were skipped because they are not supported audio files", bundle: .module))
        }

        guard let storageRoot = await fetchStorageRoot() else {
            alert_error(String(localized: "Storage location is unavailable", bundle: .module))
            return
        }

        do {
            let copiedURLs = try await copyFiles(importableURLs, to: storageRoot)
            guard let library = dependencies.audioLibrary() else {
                Self.cleanUpCopiedFiles(copiedURLs)
                alert_error(String(localized: "Import failed: audio repository is unavailable", bundle: .module))
                return
            }

            await library.sync(urls: copiedURLs, verbose: false, isFirst: false)
        } catch {
            os_log(.error, "\(self.t)❌ Failed to copy files: \(error.localizedDescription)")
            alert_error(String(localized: "Import failed: \(error.localizedDescription)", bundle: .module))
        }
    }
}

// MARK: - Event Handler

extension AudioDBView {
    /// 处理文件导入
    ///
    /// 当用户通过文件选择器导入音频文件时触发。
    /// 获取存储根目录并将文件复制到该目录。
    ///
    /// - Parameter result: 文件导入的结果，包含选中的文件 URL 或错误信息
    private func handleFileImport(result: Result<[URL], Error>) {
        Task {
            switch result {
            case let .success(urls):
                await importFiles(urls)

            case let .failure(error):
                os_log(.error, "\(self.t)❌ File import failed: \(error.localizedDescription)")
                alert_error(String(localized: "Import failed: \(error.localizedDescription)", bundle: .module))
            }
        }
    }

    /// 处理用户将音频文件拖入仓库视图。
    nonisolated func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if Self.verbose {
            os_log("\(self.t)🎯 Handling file drop, provider count: \(providers.count)")
        }

        // Extract URLs from non-Sendable NSItemProvider before crossing isolation boundary.
        Task {
            let droppedFiles = await Self.droppedFileURLs(from: providers)

            await MainActor.run {
                if Self.shouldReportDroppedURLLoadFailure(droppedFiles.urls, errors: droppedFiles.errors),
                   let error = droppedFiles.errors.first {
                    os_log(.error, "\(self.t)⚠️ Failed to load dropped file: \(error.localizedDescription)")
                    alert_error(String(localized: "Import failed: \(error.localizedDescription)", bundle: .module))
                } else if Self.shouldReportPartialDroppedURLLoadFailure(droppedFiles.urls, errors: droppedFiles.errors) {
                    os_log(.error, "\(self.t)⚠️ Some dropped files failed to load")
                    alert_warning(String(localized: "Some dropped files could not be loaded", bundle: .module))
                }

                guard Self.shouldImportDroppedURLs(droppedFiles.urls, after: droppedFiles.errors) else {
                    return
                }

                Task {
                    await importFiles(droppedFiles.urls)
                }
            }
        }

        return true
    }
}
