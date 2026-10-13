import MagicKit
import ProviderScene

/// 音频进度的播放与外部环境观察者（迁移 Phase 5）。
///
/// 订阅播放进度事件与外部环境信号，转发到 `AudioProgressViewModel`；
/// 取代原 `AudioProgressRootView` 的 `.onReceive` 与
/// `AudioProgressStorageResetModifier`。
@MainActor
final class AudioProgressObserver: SuperLog {
    nonisolated static let emoji = "⏱️"
    nonisolated static let verbose = false

    private weak var viewModel: AudioProgressViewModel?
    private var playbackHandle: (any PlaybackProgressObserverHandle)?
    private var environmentHandle: (any ProgressEnvironmentObserverHandle)?
    private var currentScene: AppScene?

    init(
        playback: any PlaybackProgressCapability,
        environment: any ProgressEnvironmentCapability,
        viewModel: AudioProgressViewModel
    ) {
        self.viewModel = viewModel
        currentScene = environment.currentScene
        viewModel.handleSceneChange(from: nil, to: environment.currentScene)

        environmentHandle = environment.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .sceneChanged(let scene):
                let previousScene = self.currentScene
                self.currentScene = scene
                self.viewModel?.handleSceneChange(from: previousScene, to: scene)
            case .filesDeleted(let urls):
                self.viewModel?.handleDBDeleted(deletedURLs: urls)
            case .storageLocationReset:
                self.viewModel?.handleStorageLocationDidReset()
            }
        }

        playbackHandle = playback.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .stateChanged(let state):
                self.viewModel?.handlePlayManStateChanged(state == .playing)
            case .assetChanged(let url):
                self.viewModel?.handlePlayManAssetChanged(url)
            }
        }
    }

    func cancel() {
        environmentHandle?.cancel()
        environmentHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
        currentScene = nil
    }
}