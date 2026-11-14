import MagicKit

/// 场景变更观察者：订阅场景能力，驱动视图模型重新读取状态。
@MainActor
final class SceneProvidingObserver: SuperLog {
    nonisolated static let emoji = "🖼️"
    nonisolated static let verbose = false

    private weak var viewModel: SceneSelectionViewModel?
    private var handle: (any SceneSelectionObserverHandle)?

    init(selection: any SceneSelectionCapability, viewModel: SceneSelectionViewModel) {
        self.viewModel = viewModel
        // Initial sync：先同步当前快照，再安装监听，避免丢失监听安装前的状态。
        viewModel.handleSelectionChanged()
        handle = selection.addObserver { [weak self] _ in
            self?.viewModel?.handleSelectionChanged()
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}