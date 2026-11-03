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

        seedRepositoryConclusion(library: library)
        publishHeroVisibility()
    }

    /// 补上仓库状态的**初值**。
    ///
    /// 事件流只报告**变化**，订阅时仓库可能早已扫完（数据层在
    /// `addObserver` 时会重放一次「确认为空」，但「确认非空」不会重放）。
    /// 不补初值的话，仓库有歌的情况下 idle 占位永远不会亮起——
    /// 这正是启动态空播放器要修的那一屏。
    private func seedRepositoryConclusion(library: any HeroLibraryCapability) {
        switch library.repositoryScanState {
        case .unknown:
            // 还没扫过：不下结论。占位若在此刻出现，启动瞬间会闪一下。
            return
        case .empty:
            viewModel?.applyRepositoryEmpty(true)
        case .nonEmpty:
            viewModel?.applyRepositoryEmpty(false)
        }
    }

    /// 把封面呈现状态广播给控制区与根布局（替代失效的 preference 链路）。
    ///
    /// 「呈现」包含两种形态：真实封面（有当前曲目）与 idle 占位
    /// （仓库有歌但还没选）。两者都需要控制区给这块区域留出高度，
    /// 否则占位态下区域仍然空着——那就等于没修。
    ///
    /// 仓库为空时归空仓库引导管：引导占据顶部，Hero 与占位都不出现。
    private func publishHeroVisibility() {
        guard let viewModel else {
            ControlHeroVisibility.shared.isVisible = true
            return
        }
        ControlHeroVisibility.shared.isVisible = viewModel.isHeroVisible || viewModel.showsIdlePlaceholder
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
