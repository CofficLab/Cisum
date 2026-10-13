import ProviderControlView
import ProviderPlayback
import ProviderAudioLibrary
import ProviderScene
import MagicKit

/// 播放封面观察者：汇总播放、音乐仓库与场景事件，驱动封面 ViewModel。
@MainActor
final class PlaybackHeroObserver: SuperLog {
    nonisolated static let emoji = "🎤"
    nonisolated static let verbose = false

    private weak var viewModel: PlaybackHeroViewModel?
    private var playbackHandle: (any PlaybackProvidingObserverHandle)?
    private var libraryHandle: (any AudioLibraryProvidingObserverHandle)?
    private var sceneHandle: (any SceneProvidingObserverHandle)?

    init(
        playback: (any PlaybackProviding)?,
        library: (any AudioLibraryProviding)? = nil,
        scene: (any SceneProviding)? = nil,
        viewModel: PlaybackHeroViewModel
    ) {
        self.viewModel = viewModel
        viewModel.applyMusicSceneActive(scene.map { $0.currentScene == .music } ?? true)
        playbackHandle = playback?.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .assetChanged(let url):
                self.viewModel?.applyAssetChanged(url)
                self.publishHeroVisibility()
            case .stateChanged(let state):
                self.viewModel?.applyStateChanged(state)
                self.publishHeroVisibility()
            default: break
            }
        }

        libraryHandle = library?.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .repositoryEmpty:
                self.viewModel?.applyRepositoryEmpty(true)
                self.publishHeroVisibility()
            case .synced(let totalCount), .updated(let totalCount), .deleted(_, let totalCount):
                if totalCount > 0 {
                    self.viewModel?.applyRepositoryEmpty(false)
                    self.publishHeroVisibility()
                }
            case .syncing, .repositoryAvailabilityChanged, .sorting, .sortCompleted:
                break
            }
        }

        sceneHandle = scene?.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .selectionChanged(let scene):
                self.viewModel?.applyMusicSceneActive(scene == .music)
                self.publishHeroVisibility()
            }
        }
    }

    /// 把封面呈现状态广播给控制区与根布局（替代失效的 preference 链路）。
    private func publishHeroVisibility() {
        ControlHeroVisibility.shared.isVisible = viewModel?.isHeroVisible ?? true
    }

    func cancel() {
        playbackHandle?.cancel()
        playbackHandle = nil
        libraryHandle?.cancel()
        libraryHandle = nil
        sceneHandle?.cancel()
        sceneHandle = nil
    }
}
