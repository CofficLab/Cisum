import Foundation
import SwiftUI
import MagicKit

/// 音频设置页的唯一数据来源（迁移 Phase 5）。
///
/// 持有刷新令牌、仓库磁盘指标（大小/位置/文件数）与加载防竞代逻辑；
/// 视图只读取本 ViewModel 并在刷新令牌变化时触发 `refresh()`。
@MainActor
final class AudioSettingsViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var refreshToken = 0

    // MARK: - 磁盘指标（由 refresh() 写入）

    /// 当前仓库目录；nil 表示无法获取。
    @Published private(set) var disk: URL?
    @Published private(set) var description: String = ""
    @Published private(set) var diskSize: String?
    @Published private(set) var fileCount: Int = 0

    private var refreshGeneration = 0
    private let audioDisk: @MainActor () -> URL?

    init(audioDisk: @escaping @MainActor () -> URL?) {
        self.audioDisk = audioDisk
    }

    func handleStorageLocationChanged() {
        refreshToken += 1
    }

    // MARK: - Data

    /// 重新读取仓库指标；带 generation 防竞代。
    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration

        disk = audioDisk()

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
                AudioLibraryMetrics(
                    diskSize: requestedDisk.getSizeReadable(),
                    fileCount: requestedDisk.filesCountRecursively()
                )
            }.value

            guard AudioSettingsMetricsPolicy.shouldApplyMetrics(
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
