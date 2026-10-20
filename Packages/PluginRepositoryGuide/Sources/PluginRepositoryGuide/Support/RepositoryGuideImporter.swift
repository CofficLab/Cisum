import Foundation
import KitAudioRepositoryImport
import MagicKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// 引导面板的导入控制器：把用户拖入的文件复制进仓库目录并同步索引。
///
/// 机械流程（过滤 → 复制 → 同步）由 `KitAudioRepositoryImport` 提供，与仓库
/// 视图共用同一份实现；本控制器只负责「拖放意图 → 导入 → 提示」。
@MainActor
final class RepositoryGuideImporter: ObservableObject, SuperLog {
    nonisolated static let emoji = "📥"
    nonisolated static let verbose = false

    /// 正在导入：同一时刻只允许一个导入任务。
    @Published private(set) var isImporting = false

    /// 拖拽悬停中：用于高亮拖放目标。
    @Published var isDropping = false

    private let library: any GuideLibraryCapability
    private let toast: any GuideToastCapability

    init(library: any GuideLibraryCapability, toast: any GuideToastCapability) {
        self.library = library
        self.toast = toast
    }

    /// 导入一批文件：复制进仓库目录 → 同步索引。
    func importFiles(_ urls: [URL]) async {
        guard !isImporting else {
            toast.warning(String(localized: "Import is already in progress", bundle: .module))
            return
        }

        isImporting = true
        defer { isImporting = false }

        let outcome = await AudioRepositoryImportService.importFiles(
            urls,
            audioDisk: library.audioDisk,
            supportedExtensions: library.supportedExtensions,
            isLibraryAvailable: { [library] in library.isAvailable },
            sync: { [library] urls in await library.sync(urls: urls) }
        )

        report(outcome)
    }

    /// 处理拖放：解析出文件 URL 后走同一条导入路径。
    @discardableResult
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if Self.verbose {
            os_log("\(Self.t)🎯 Handling file drop, provider count: \(providers.count)")
        }

        Task {
            let droppedFiles = await AudioRepositoryDropResolver.droppedFileURLs(from: providers)

            if droppedFiles.urls.isEmpty, !droppedFiles.errors.isEmpty {
                if let error = droppedFiles.errors.first {
                    toast.error(String(localized: "Import failed: %@", bundle: .module)
                        .replacingOccurrences(of: "%@", with: error.localizedDescription))
                }
            } else if !droppedFiles.urls.isEmpty, !droppedFiles.errors.isEmpty {
                toast.warning(String(localized: "Some dropped files could not be loaded", bundle: .module))
            }

            guard !droppedFiles.urls.isEmpty else { return }
            await importFiles(droppedFiles.urls)
        }

        return true
    }

    /// 把导入结果映射成提示文案（文案由本插件决定，Kit 不产出文案）。
    private func report(_ outcome: AudioRepositoryImportOutcome) {
        switch outcome {
        case .imported(let skippedUnsupported):
            if skippedUnsupported > 0 {
                toast.warning(String(localized: "Some files were skipped because they are not supported audio files", bundle: .module))
            }
        case .noImportableFiles:
            toast.error(String(localized: "No files were added", bundle: .module))
        case .storageUnavailable:
            toast.error(String(localized: "Storage location is unavailable", bundle: .module))
        case .libraryUnavailable:
            toast.error(String(localized: "Import failed: audio repository is unavailable", bundle: .module))
        case .permissionDenied:
            toast.error(String(localized: "Import failed: %@", bundle: .module)
                .replacingOccurrences(of: "%@", with: String(localized: "Permission to access the original file was denied", bundle: .module)))
        case .failed(let reason):
            toast.error(String(localized: "Import failed: %@", bundle: .module)
                .replacingOccurrences(of: "%@", with: reason))
        }
    }
}
