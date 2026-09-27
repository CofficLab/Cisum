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
            case .stateChanged(let state):
                self.viewModel?.applyStateChanged(state)
            default: break
            }
        }

        libraryHandle = library?.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .repositoryEmpty:
                self.viewModel?.applyRepositoryEmpty(true)
            case .synced(let totalCount), .updated(let totalCount), .deleted(_, let totalCount):
                if totalCount > 0 {
                    self.viewModel?.applyRepositoryEmpty(false)
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
            }
        }
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
