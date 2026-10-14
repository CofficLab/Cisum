import MagicKit

/// 音频根视图的存储变化观察者（迁移 Phase 2）。
///
/// 订阅存储能力的变化信号，驱动 `AudioRootViewModel` 重建容器并产生
/// toast 信号；取代 `AudioRootView` 直接订阅存储通知的做法。
@MainActor
final class AudioStorageObserver: SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = false

    private weak var viewModel: AudioRootViewModel?
    private var handle: (any AudioRootStorageObserverHandle)?

    init(storage: any AudioRootStorageCapability, viewModel: AudioRootViewModel) {
        self.viewModel = viewModel
        // Initial sync：存储已配置时先构建一次容器，再安装监听。
        if storage.hasUsableStorageLocation {
            viewModel.reloadContainer()
        }
        handle = storage.addObserver { [weak self] _ in
            self?.viewModel?.reloadContainer()
            self?.viewModel?.handleStorageLocationChanged()
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}