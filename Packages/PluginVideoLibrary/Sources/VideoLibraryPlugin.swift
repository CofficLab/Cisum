import Combine
import LumiUI
import MagicKit
import OSLog
import KernelCore
import ProviderAppState
import ProviderControlView
import ProviderDocsView
import ProviderPlugin
import ProviderScene
import ProviderVideo
import SwiftUI

/// 视频库场景插件。
///
/// 负责三件事：
/// 1. 在「视频库」场景登记视频列表页（`addTabView`）；
/// 2. 在控制区登记播放器画面、控制按钮与进度条；
/// 3. 组装仓库 / 播放两个能力 Adapter，并把它们交给视图模型。
///
/// 场景切换时通过 `SceneProviding` 的观察者撤下贡献，避免与音乐 / 有声书
/// 场景的插件抢占同一个控制区。
@MainActor
public final class VideoLibraryPlugin: AsyncSuperPlugin, SuperLog {
    public let id = "com.coffic.cisum.plugin.video-library"

    nonisolated static let verbose = false

    public static let shared = VideoLibraryPlugin()
    public let order = 12
    public let iconName = "film.stack"
    public let metadata = PluginMetadata(
        id: "com.coffic.cisum.plugin.video-library",
        name: String(localized: "Video Library", bundle: .module),
        description: String(localized: "Browse, organize and play the videos in your own folder.", bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .enabledByDefault,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var viewModel: VideoLibraryViewModel?
    /// 本插件消费的能力 Adapter。视图模型持有它们，故插件必须强持有 Adapter 本身。
    nonisolated(unsafe) private var repositoryCapability: VideoLibraryRepositoryCapability?
    nonisolated(unsafe) private var playbackCapability: VideoLibraryPlaybackCapability?
    nonisolated(unsafe) private var viewModelCancellable: AnyCancellable?
    /// 场景激活句柄：视频场景才登记控制区贡献。
    nonisolated(unsafe) private var sceneHandle: (any SceneProvidingObserverHandle)?

    public init() {}

    // MARK: - Lifecycle

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { VideoLibraryAboutView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if let contribution = kernel.resolveProvider((any PluginContributionProviding).self) {
            registerTabView(contribution: contribution)
        }
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
        installSceneActivation(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
        installSceneActivation(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        sceneHandle?.cancel()
        sceneHandle = nil
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        sceneHandle?.cancel()
        sceneHandle = nil
        teardownState()
        self.kernel = nil
    }

    // MARK: - Contributions

    /// 视频库列表页（仅在视频场景登记）。
    @MainActor
    public func addTabView(reason: String, demoMode: Bool = false) -> (view: AnyView, label: String)? {
        guard currentScene == .videos else { return nil }
        installState(kernel: kernel)
        guard let viewModel else { return nil }
        let label = String(localized: "Video Library", bundle: .module)
        return (AnyView(VideoLibraryView(viewModel: viewModel)), label)
    }

    /// 播放器画面。
    @MainActor
    public func addHeroView() -> AnyView? {
        installState(kernel: kernel)
        guard let viewModel else { return nil }
        return AnyView(VideoPlayerHeroView(viewModel: viewModel))
    }

    /// 播放控制按钮。
    @MainActor
    public func addControlButtonsView() -> AnyView? {
        installState(kernel: kernel)
        guard let viewModel else { return nil }
        return AnyView(VideoControlButtonsView(viewModel: viewModel) { [weak self] in
            self?.kernel?.resolveProvider((any ContentViewVisibilityProviding).self)?.toggleContentView()
        })
    }

    /// 播放进度条。
    @MainActor
    public func addProgressView() -> AnyView? {
        installState(kernel: kernel)
        guard let viewModel else { return nil }
        return AnyView(VideoProgressView(viewModel: viewModel))
    }

    // MARK: - Scene activation

    private var currentScene: AppScene? {
        kernel?.resolveProvider((any SceneProviding).self)?.currentScene
    }

    @MainActor
    private func installSceneActivation(kernel: KernelCoreContainer) {        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        applyScene(scene.currentScene)

        guard sceneHandle == nil else { return }
        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(newScene) = event else { return }
            self?.applyScene(newScene)
        }
    }

    @MainActor
    private func applyScene(_ scene: AppScene?) {
        guard let contribution = kernel?.resolveProvider((any PluginContributionProviding).self) else { return }
        // `remove(owner:)` 会连同标签页一起撤回，因此撤回后必须重新登记标签页。
        contribution.remove(owner: id)
        registerTabView(contribution: contribution)
        guard scene == .videos else { return }
        if let view = addHeroView() {
            contribution.addHeroView(ownerPluginID: id, view)
        }
        if let view = addControlButtonsView() {
            contribution.addControlButtonsView(ownerPluginID: id, view)
        }
        if let view = addProgressView() {
            contribution.addProgressView(ownerPluginID: id, view)
        }
        publishHeroVisibility()
    }

    private func publishHeroVisibility() {
        guard currentScene == .videos else { return }
        guard let viewModel else {
            ControlHeroVisibility.shared.isVisible = false
            ControlHeroVisibility.shared.isProgressVisible = false
            return
        }
        let isVisible = VideoPlayerLayoutPolicy.isHeroVisible(
            repositoryURL: viewModel.repositoryURL,
            itemCount: viewModel.items.count
        )
        ControlHeroVisibility.shared.isVisible = isVisible
        ControlHeroVisibility.shared.isProgressVisible = isVisible
    }

    private func registerTabView(contribution: any PluginContributionProviding) {
        contribution.addTabView(ownerPluginID: id) { reason, demoMode in
            self.addTabView(reason: reason, demoMode: demoMode)
        }
    }

    // MARK: - State assembly

    /// 组装能力 Adapter 与视图模型（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer?) {
        guard viewModel == nil else { return }
        guard let kernel else { return }

        let repository = VideoLibraryRepositoryCapability(
            repository: kernel.resolveProvider((any VideoRepositoryProviding).self)
        )
        let playback = VideoLibraryPlaybackCapability(
            playback: kernel.resolveProvider((any VideoPlaybackProviding).self)
        )
        repositoryCapability = repository
        playbackCapability = playback

        let model = VideoLibraryViewModel(repository: repository, playback: playback)
        model.bind()
        viewModel = model
        viewModelCancellable = model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.publishHeroVisibility() }
    }

    @MainActor
    private func teardownState() {
        viewModelCancellable?.cancel()
        viewModelCancellable = nil
        viewModel?.unbind()
        viewModel = nil
        repositoryCapability = nil
        playbackCapability = nil
        if currentScene == .videos {
            ControlHeroVisibility.shared.isVisible = false
            ControlHeroVisibility.shared.isProgressVisible = false
        }
    }
}
