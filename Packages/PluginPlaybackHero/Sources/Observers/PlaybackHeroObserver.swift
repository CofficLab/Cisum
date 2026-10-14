import MagicKit
import ProviderControlView

/// 播放封面观察者：汇总播放、音乐仓库与场景事件，驱动封面 ViewModel。
@MainActor
final class PlaybackHeroObserver: SuperLog {
    nonisolated static let emoji = "🎤"
    nonisolated static let verbose = false

    private weak var viewModel: PlaybackHeroViewModel?
    private var playbackHandle: (any HeroPlaybackObserverHandle)?
    private var libraryHandle: (any HeroLibraryObserverHandle)?
    private var sceneHandle: (any HeroSceneObserverHandle)?

    init(
        playback: any HeroPlaybackCapability,
        library: any HeroLibraryCapability,
        scene: any HeroSceneCapability,
        viewModel: PlaybackHeroViewModel
    ) {
        self.viewModel = viewModel
        // 场景 Provider 缺失时不隐藏封面：启动早期场景尚未就绪，
        // 若按「非音乐库」处理会让封面在整个会话中都不出现。
        viewModel.applyMusicSceneActive(!scene.isAvailable || scene.currentScene == .music)

        playbackHandle = playback.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .assetChanged(let url):
                self.viewModel?.applyAssetChanged(url)
                self.publishHeroVisibility()
            case .stateChanged(let state):
                self.viewModel?.applyStateChanged(state)
                self.publishHeroVisibility()
            }
        }

        libraryHandle = library.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .becameEmpty:
                self.viewModel?.applyRepositoryEmpty(true)
                self.publishHeroVisibility()
            case .becameNonEmpty:
                self.viewModel?.applyRepositoryEmpty(false)
                self.publishHeroVisibility()
            }
        }

        sceneHandle = scene.addObserver { [weak self] event in
            guard let self else { return }
            guard case .selectionChanged(let newScene) = event else { return }
            self.viewModel?.applyMusicSceneActive(newScene == .music)
            self.publishHeroVisibility()
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