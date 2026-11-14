import MagicKit

/// 存储变更观察者：订阅存储能力，驱动 `StorageSettingsViewModel` 刷新。
@MainActor
final class StorageProvidingObserver: SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = false

    private weak var viewModel: StorageSettingsViewModel?
    private var handle: (any StorageSettingsObserverHandle)?

    init(storage: any StorageSettingsCapability, viewModel: StorageSettingsViewModel) {
        self.viewModel = viewModel
        // Initial sync：先同步当前快照，再安装监听，避免丢失监听安装前的状态。
        viewModel.handleProviderChanged()
        handle = storage.addObserver { [weak self] _ in
            self?.viewModel?.handleProviderChanged()
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}