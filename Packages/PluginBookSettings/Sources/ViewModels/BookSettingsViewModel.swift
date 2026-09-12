import Foundation
import OSLog
import ProviderBook
import SwiftUI
import MagicKit

/// 书籍设置的刷新状态容器（迁移 Phase 5）。
///
/// 持有刷新令牌，存储位置变化时递增以触发设置视图刷新；
/// 取代原 `BookSettingsPluginView` 的 `@State refreshToken` 与
/// `BookSettingsStorageChangeModifier`。
@MainActor
final class BookSettingsViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var refreshToken = 0

    // MARK: - 磁盘指标（由 refresh() 写入）

    /// 当前仓库目录；nil 表示无法获取。
    @Published private(set) var disk: URL?
    @Published private(set) var description: String = ""
    @Published private(set) var diskSize: String?
    @Published private(set) var fileCount: Int = 0

    private var refreshGeneration = 0
    private let bookDisk: @MainActor () -> URL?

    init(bookDisk: @escaping @MainActor () -> URL?) {
        self.bookDisk = bookDisk
    }

    func handleStorageLocationChanged() {
        refreshToken += 1
        if Self.verbose { os_log("\(Self.t)🔁 存储位置变化，刷新令牌 → \(self.refreshToken)") }
    }

    // MARK: - Data

    /// 重新读取仓库指标；带 generation 防竞代。
    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration

        disk = bookDisk()

        guard let requestedDisk = disk else {
            description = ""
            fileCount = 0
            diskSize = nil
            return
        }

        if requestedDisk.checkIsICloud(verbose: false) {
            description = String(localized: "iCloud Drive, will sync", bundle: .module)
        } else {
            description = String(localized: "Local directory, will not sync", bundle: .module)
        }
        diskSize = nil
        fileCount = 0

        Task {
            let metrics = await Task.detached(priority: .utility) {
                BookLibraryMetrics(
                    diskSize: requestedDisk.getSizeReadable(),
                    fileCount: requestedDisk.filesCountRecursively()
                )
            }.value

            guard BookSettingsMetricsPolicy.shouldApplyMetrics(
                currentDisk: self.disk,
                requestedDisk: requestedDisk,
                currentGeneration: self.refreshGeneration,
                resultGeneration: generation
            ) else { return }

            diskSize = metrics.diskSize
            fileCount = metrics.fileCount
        }
    }
}
