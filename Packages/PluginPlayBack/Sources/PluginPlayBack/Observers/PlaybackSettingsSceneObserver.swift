import ProviderScene
import MagicKit

/// 设置页场景监听器：订阅场景能力，驱动
/// `PluginPlayBackSettingsViewModel` 的当前场景高亮与各场景文件列表联动。
@MainActor
final class PlaybackSettingsSceneObserver: SuperLog {
    nonisolated static let emoji = "🖼️"
    nonisolated static let verbose = false

    private weak var viewModel: PluginPlayBackSettingsViewModel?
    private var handle: (any PlaybackSceneObserverHandle)?

    init(scene: any PlaybackSceneCapability, viewModel: PluginPlayBackSettingsViewModel) {
        self.viewModel = viewModel
        // Initial sync：先同步当前快照，再安装监听，避免丢失监听安装前的状态。
        viewModel.handleSceneChanged(scene.currentScene)
        handle = scene.addObserver { [weak self] event in
            guard case .selectionChanged(let newScene) = event else { return }
            self?.viewModel?.handleSceneChanged(newScene)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}