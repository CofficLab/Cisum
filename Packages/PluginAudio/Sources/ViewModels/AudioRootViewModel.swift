import Foundation
import MagicKit

enum AudioRootError: Error, Equatable {
    case storageMissing
    case initialization(String)
}

/// 音频根视图的加载状态容器（迁移 Phase 2）。
///
/// 集中管理音频库可用性、错误与存储变化信号；由插件入口持有并注入
/// `AudioStorageObserver`，View 只观察本 ViewModel，不再直接订阅存储通知。
@MainActor
final class AudioRootViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = true

    @Published private(set) var error: AudioRootError?
    @Published private(set) var isInitializing = true
    /// 存储位置变化信号：Observer 写入，View 通过 `.onChange` 弹全局 toast。
    @Published private(set) var storageLocationDidChangeNotice: UUID?

    private var initGeneration = 0
    private let hasStorageLocation: @MainActor () -> Bool

    init(hasStorageLocation: @escaping @MainActor () -> Bool) {
        self.hasStorageLocation = hasStorageLocation
    }

    /// 重建容器。代际（generation）保护保证旧任务结果不会覆盖新状态。
    func reloadContainer() {
        initGeneration += 1
        let generation = initGeneration
        isInitializing = true
        error = nil

        guard hasStorageLocation() else {
            isInitializing = false
            error = .storageMissing
            return
        }
        guard generation == self.initGeneration else { return }
        isInitializing = false
    }

    /// 存储位置变化：产生新信号供 View 弹 toast。
    func handleStorageLocationChanged() {
        storageLocationDidChangeNotice = UUID()
    }
}
