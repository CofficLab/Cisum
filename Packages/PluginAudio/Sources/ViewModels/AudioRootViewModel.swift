import Foundation
import MagicKit
import ProviderToast

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
    nonisolated static let verbose = false

    @Published private(set) var error: AudioRootError?
    @Published private(set) var isInitializing = true
    /// 存储位置变化信号：Observer 写入，View 通过 `.onChange` 弹全局 toast。
    @Published private(set) var storageLocationDidChangeNotice: UUID?

    private var initGeneration = 0
    /// 存储与提示能力（Capabilities 目录收窄）。
    ///
    /// **强持有**：入口 teardown 先释放本容器再释放能力；能力内部对 Provider
    /// 为 `weak`，强持有能力不会延长 Provider 的生命周期。
    private let storage: (any AudioRootStorageCapability)?
    private let toast: (any AudioRootToastCapability)?

    init(
        storage: (any AudioRootStorageCapability)?,
        toast: (any AudioRootToastCapability)? = nil
    ) {
        self.storage = storage
        self.toast = toast
    }

    /// 重建容器。代际（generation）保护保证旧任务结果不会覆盖新状态。
    func reloadContainer() {
        initGeneration += 1
        let generation = initGeneration
        isInitializing = true
        error = nil

        guard storage?.hasUsableStorageLocation == true else {
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
        toast?.info(String(localized: "Storage location has changed", bundle: .module))
    }
}
