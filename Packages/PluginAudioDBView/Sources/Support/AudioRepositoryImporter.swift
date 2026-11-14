import Foundation
import KitAudioRepositoryImport
import MagicKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// 仓库导入控制器：把外部文件（拖放 / 文件选择器）复制进仓库目录并同步索引。
///
/// 机械流程（过滤 → 复制 → 同步）由 `KitAudioRepositoryImport` 提供，
/// 仓库视图与空仓库引导插件共用同一份实现，不会出现两条路径行为分叉。
///
/// 控制器由插件入口持有并注入视图；视图只负责发起意图（拖放 / 选择文件），
/// 不再各自实现一遍复制与同步。
@MainActor
final class AudioRepositoryImporter: ObservableObject, SuperLog {
    nonisolated static let emoji = "📥"
    nonisolated static let verbose = false

    /// 正在导入：同一时刻只允许一个导入任务。
    @Published private(set) var isImporting = false

    /// 拖拽悬停中：用于高亮拖放目标。
    @Published var isDropping = false

    private let library: any AudioLibraryCapability
    private let audioDisk: @MainActor @Sendable () -> URL?
    private let supportedExtensions: [String]
    private let toast: any AudioLibraryToastCapability
    private let capacity: any AudioLibraryCapacityCapability
    private let purchase: any AudioPurchasePresentingCapability

    init(
        library: any AudioLibraryCapability,
        audioDisk: @escaping @MainActor @Sendable () -> URL?,
        supportedExtensions: [String],
        toast: any AudioLibraryToastCapability,
        capacity: any AudioLibraryCapacityCapability,
        purchase: any AudioPurchasePresentingCapability
    ) {
        self.library = library
        self.audioDisk = audioDisk
        self.supportedExtensions = supportedExtensions
        self.toast = toast
        self.capacity = capacity
        self.purchase = purchase
    }

    /// 导入一批文件：容量准入 → 复制进仓库目录 → 同步索引。
    ///
    /// 复制与同步是同一件事的两半：文件先落到仓库目录（用户可见、可在 Finder
    /// 里管理），再把新文件并入索引（列表可见）。任一步失败都会给出提示。
    ///
    /// ## 容量准入在前
    ///
    /// 准入必须在**复制之前**：先复制再判断，等于把超限文件落到了磁盘上，
    /// 既浪费了空间，又让「仓库里到底有几个文件」与索引不一致。这里先问一次
    /// 闸门「这批文件能进几个」，只把放行的部分交给复制流程。
    func importFiles(_ urls: [URL]) async {
        guard AudioDBView.shouldStartImport(isImporting: isImporting) else {
            toast.warning(String(localized: "Import is already in progress", bundle: .module))
            return
        }

        isImporting = true
        defer { isImporting = false }

        let admitted = await admit(urls: urls)
        guard !admitted.isEmpty else { return }

        let outcome = await AudioRepositoryImportService.importFiles(
            admitted,
            audioDisk: audioDisk(),
            supportedExtensions: supportedExtensions,
            isLibraryAvailable: { [library] in library.isAvailable },
            sync: { [library] urls in await library.sync(urls: urls, verbose: false, isFirst: false) }
        )

        report(outcome)
    }

    /// 容量准入：问闸门这批文件能进几个。
    ///
    /// 返回放行的文件；被挡住时给出提示并提供购买入口。
    func admit(urls: [URL]) async -> [URL] {
        guard !urls.isEmpty else { return [] }

        let admission = await capacity.admit(requestedCount: urls.count, reservedCount: 0)
        guard admission.didReject else { return urls }

        let allowed = admission.allowedCount(requestedCount: urls.count)
        if allowed > 0 {
            toast.warning(
                String(
                    localized: String.LocalizationValue("Only \(allowed) files were added because the free file limit is almost full"),
                    bundle: .module
                )
            )
        } else {
            toast.error(String(localized: "File limit reached", bundle: .module))
        }
        presentPurchaseEntry()

        return Array(urls.prefix(allowed))
    }

    /// 撞限后给出购买入口。
    ///
    /// 提示本身由 Toast 承载（一闪而过），但**必须有可点击的付费入口**——
    /// 否则用户只看到「已达上限」，却不知道去哪付费，这条链路就断在这里。
    /// 这里在容量被挡住时直接请商店呈现购买面板。
    private func presentPurchaseEntry() {
        purchase.presentPurchase()
    }

    /// 处理文件选择器的结果。
    func handleFileImport(result: Result<[URL], Error>) {
        Task {
            switch result {
            case let .success(urls):
                await importFiles(urls)
            case let .failure(error):
                if Self.verbose {
                    os_log(.error, "\(Self.t)❌ File import failed: \(error.localizedDescription)")
                }
                toast.error(String(localized: "Import failed: %@", bundle: .module)
                    .replacingOccurrences(of: "%@", with: error.localizedDescription))
            }
        }
    }

    /// 处理拖放：解析出文件 URL 后走同一条导入路径。
    @discardableResult
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if Self.verbose {
            os_log("\(Self.t)🎯 Handling file drop, provider count: \(providers.count)")
        }

        Task {
            let droppedFiles = await AudioRepositoryDropResolver.droppedFileURLs(from: providers)

            if AudioDBView.shouldReportDroppedURLLoadFailure(droppedFiles.urls, errors: droppedFiles.errors),
               let error = droppedFiles.errors.first {
                if Self.verbose {
                    os_log(.error, "\(Self.t)⚠️ Failed to load dropped file: \(error.localizedDescription)")
                }
                toast.error(String(localized: "Import failed: %@", bundle: .module)
                    .replacingOccurrences(of: "%@", with: error.localizedDescription))
            } else if AudioDBView.shouldReportPartialDroppedURLLoadFailure(droppedFiles.urls, errors: droppedFiles.errors) {
                if Self.verbose {
                    os_log("\(Self.t)⚠️ Some dropped files could not be loaded")
                }
                toast.warning(String(localized: "Some dropped files could not be loaded", bundle: .module))
            }

            guard AudioDBView.shouldImportDroppedURLs(droppedFiles.urls, after: droppedFiles.errors) else {
                return
            }

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
