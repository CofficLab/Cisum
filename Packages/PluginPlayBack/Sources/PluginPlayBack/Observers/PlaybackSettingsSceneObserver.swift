import ProviderScene
import MagicKit

/// 设置页场景监听器：订阅 `SceneProviding` 的场景切换事件，驱动
/// `PluginPlayBackSettingsViewModel` 的当前场景高亮与各场景文件列表联动。
@MainActor
final class PlaybackSettingsSceneObserver: SuperLog {
    nonisolated static let emoji = "🖼️"
    nonisolated static let verbose = false

    private weak var viewModel: PluginPlayBackSettingsViewModel?
    private var handle: (any SceneProvidingObserverHandle)?

    init(provider: (any SceneProviding)?, viewModel: PluginPlayBackSettingsViewModel) {
        self.viewModel = viewModel
        // Initial sync：先同步当前快照，再安装监听，避免丢失监听安装前的状态。
        viewModel.handleSceneChanged(provider?.currentScene)
        handle = provider?.addObserver { [weak self] event in
            guard case .selectionChanged(let scene) = event else { return }
            self?.viewModel?.handleSceneChanged(scene)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
