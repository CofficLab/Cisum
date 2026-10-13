import Combine
import ProviderAudioLibrary
import ProviderPlayback
import ProviderPlugin
import ProviderScene
import SwiftUI

@MainActor
final class CisumRootLayoutViewModel: ObservableObject {
    private let pluginProvider: (any PluginProviding)?
    private var pluginHandle: (any PluginProvidingObserverHandle)?
    @Published private(set) var contributionRevision = 0

    /// 播放器区是否处于「呈现内容」态（有当前曲目，且音乐场景仓库非空）。
    ///
    /// 由播放/场景/仓库事件驱动，用于控制控制区高度（收起 150 / 展开 250）。
    /// 之前该状态依赖 `PlaybackHeroVisibilityKey` preference 从插件注入的
    /// Hero 视图跨多层传到根布局，实测该链路不可靠（preference 停留在默认值，
    /// 收起断言恒失败）；按项目的 Observer 架构规范改为事件直达。
    @Published private(set) var isPlaybackHeroPresenting = false

    private var playbackHandle: (any PlaybackProvidingObserverHandle)?
    private var sceneHandle: (any SceneProvidingObserverHandle)?
    private var libraryHandle: (any AudioLibraryProvidingObserverHandle)?
    private var hasCurrentAsset = false
    private var isRepositoryEmpty = false
    private var isMusicSceneActive = true

    init(pluginProvider: (any PluginProviding)?) {
        self.pluginProvider = pluginProvider
    }

    /// 绑定播放 / 场景 / 仓库 Provider 并建立订阅。
    ///
    /// 必须延迟到内核启动完成（视图 onAppear）后调用：这些 Provider 由插件
    /// 在 onBoot/onReady 注册，内核贡献聚合期间调用 `resolveProvider` 会卡死。
    func attach(
        playback: (any PlaybackProviding)?,
        scene: (any SceneProviding)?,
        library: (any AudioLibraryProviding)?
    ) {
        guard playbackHandle == nil, sceneHandle == nil, libraryHandle == nil else { return }
        hasCurrentAsset = playback?.currentURL != nil
        if let scene {
            isMusicSceneActive = scene.currentScene == .music
        }
        recomputeHeroVisibility()

        playbackHandle = playback?.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .assetChanged(let url):
                self.hasCurrentAsset = url != nil
                self.recomputeHeroVisibility()
            default:
                break
            }
        }

        sceneHandle = scene?.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .selectionChanged(let scene):
                self.isMusicSceneActive = scene == .music
                self.recomputeHeroVisibility()
            }
        }

        libraryHandle = library?.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .repositoryEmpty:
                self.isRepositoryEmpty = true
                self.recomputeHeroVisibility()
            case .synced(let totalCount), .updated(let totalCount), .deleted(_, let totalCount):
                if totalCount > 0 {
                    self.isRepositoryEmpty = false
                    self.recomputeHeroVisibility()
                }
            default:
                break
            }
        }
    }

    var toolbarButtons: [(id: String, view: AnyView)] {
        _ = contributionRevision
        return pluginProvider?.getToolBarButtons() ?? []
    }

    var statusViews: [AnyView] {
        _ = contributionRevision
        return pluginProvider?.getStatusViews() ?? []
    }

    /// 与 `PlaybackHeroViewModel.isHeroVisible` 相同的呈现条件。
    private func recomputeHeroVisibility() {
        isPlaybackHeroPresenting = hasCurrentAsset && !(isMusicSceneActive && isRepositoryEmpty)
    }

    func start() {
        guard pluginHandle == nil else { return }
        pluginHandle = pluginProvider?.addObserver { [weak self] event in
            guard case .contributionsChanged = event else { return }
            self?.contributionRevision &+= 1
        }
    }

    func cancel() {
        pluginHandle?.cancel()
        pluginHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
        sceneHandle?.cancel()
        sceneHandle = nil
        libraryHandle?.cancel()
        libraryHandle = nil
    }
}
