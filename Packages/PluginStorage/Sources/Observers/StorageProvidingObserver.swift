import ProviderStorage
import MagicKit

@MainActor
final class StorageProvidingObserver: SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = false

    private weak var viewModel: StorageSettingsViewModel?
    private var handle: (any StorageProvidingObserverHandle)?

    init(provider: any StorageProviding, viewModel: StorageSettingsViewModel) {
        self.viewModel = viewModel
        // Initial sync：先同步当前快照，再安装监听，避免丢失监听安装前的状态。
        viewModel.handleProviderChanged()
        handle = provider.addObserver { [weak self] event in
            _ = event
            self?.viewModel?.handleProviderChanged()
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
