import ProviderStorage
import MagicKit

/// 音频根视图的存储变化观察者（迁移 Phase 2）。
///
/// 订阅 `StorageProviding` 的存储位置/可用性变化，驱动 `AudioRootViewModel`
/// 重建容器并产生 toast 信号；取代 `AudioRootView` 直接订阅存储通知的做法。
@MainActor
final class AudioStorageObserver: SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = false

    private weak var viewModel: AudioRootViewModel?
    private var handle: (any StorageProvidingObserverHandle)?

    init(provider: any StorageProviding, viewModel: AudioRootViewModel) {
        self.viewModel = viewModel
        // Initial sync：存储已配置时先构建一次容器，再安装监听。
        if provider.hasUsableStorageLocation {
            viewModel.reloadContainer()
        }
        handle = provider.addObserver { [weak self] event in
            switch event {
            case .locationChanged, .storageAvailabilityChanged:
                self?.viewModel?.reloadContainer()
                self?.viewModel?.handleStorageLocationChanged()
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
