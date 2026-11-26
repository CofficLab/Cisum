import MagicKit
import OSLog
import KernelCore
import ProviderDocsView
import ProviderPlugin
import ProviderRootView
import ProviderScene
import ProviderVideo
import SwiftUI

/// 视频库场景插件。
///
/// 负责三件事：
/// 1. 在「视频库」场景登记资料库页（`addTabView`），并隐藏根布局的播放器头部，
///    让资料库铺满整个窗口；
/// 2. 在 macOS 根布局登记沉浸播放器覆盖层（iOS / visionOS 由页面自己全屏呈现）；
/// 3. 组装仓库 / 播放两个能力 Adapter，并把它们交给视图模型。
///
/// 场景切换时通过 `SceneProviding` 的观察者增减贡献，离开视频场景即还原外壳。
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
    nonisolated(unsafe) private var rootOverlayInstalled = false
    nonisolated(unsafe) private var sceneHandle: (any SceneProvidingObserverHandle)?
    #if os(macOS)
    private lazy var windowPresenter = VideoSceneWindowPresenter()
    #endif

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
        installState(kernel: kernel)
        if let contribution = kernel.resolveProvider((any PluginContributionProviding).self) {
            registerTabView(contribution: contribution)
        }
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        activate(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        activate(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        deactivate(kernel: kernel)
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        deactivate(kernel: kernel)
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        self.kernel = nil
    }

    // MARK: - Activation

    @MainActor
    private func activate(kernel: KernelCoreContainer) {
        self.kernel = kernel
        installState(kernel: kernel)
        installRootOverlay(kernel: kernel)
        installSceneActivation(kernel: kernel)
    }

    /// 撤下全部场景贡献并还原外壳；停用与关机共用。
    @MainActor
    private func deactivate(kernel: KernelCoreContainer) {
        sceneHandle?.cancel()
        sceneHandle = nil
        applyScene(nil, kernel: kernel)
        kernel.resolveProvider((any RootViewProviding).self)?.removeOverlays(ids: ["\(id).player"])
        rootOverlayInstalled = false
        teardownState()
    }

    // MARK: - Contributions

    /// 视频库资料库页（仅在视频场景登记）。
    @MainActor
    public func addTabView(reason: String, demoMode: Bool = false) -> (view: AnyView, label: String)? {
        guard currentScene == .videos else { return nil }
        installState(kernel: kernel)
        guard let viewModel else { return nil }
        let label = String(localized: "Video Library", bundle: .module)
        return (AnyView(makeLibraryView(viewModel: viewModel)), label)
    }

    @MainActor
    private func makeLibraryView(viewModel: VideoLibraryViewModel) -> some View {
        VideoLibraryView(viewModel: viewModel) { [weak self] in
            self?.retryWindowPresentation()
        }
    }

    @MainActor
    private func retryWindowPresentation() {
        #if os(macOS)
        windowPresenter.retryIfNeeded()
        #endif
    }

    // MARK: - Scene activation

    @MainActor
    private func installRootOverlay(kernel: KernelCoreContainer) {
        #if os(macOS)
        guard !rootOverlayInstalled,
              let root = kernel.resolveProvider((any RootViewProviding).self),
              let viewModel else { return }
        root.addOverlays([
            RootOverlayItem(id: "\(id).player", order: 8_000) { content in
                content.overlay {
                    VideoPlayerRootOverlay(viewModel: viewModel)
                }
            },
        ])
        rootOverlayInstalled = true
        #endif
    }

    private var currentScene: AppScene? {
        kernel?.resolveProvider((any SceneProviding).self)?.currentScene
    }

    @MainActor
    private func installSceneActivation(kernel: KernelCoreContainer) {
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        applyScene(scene.currentScene, kernel: kernel)

        guard sceneHandle == nil else { return }
        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(newScene) = event else { return }
            self?.applyScene(newScene, kernel: kernel)
        }
    }

    /// 按场景增减贡献：视频场景接管整个窗口，其余场景还原播放器外壳。
    @MainActor
    private func applyScene(_ scene: AppScene?, kernel: KernelCoreContainer) {
        let contribution = kernel.resolveProvider((any PluginContributionProviding).self)
        let root = kernel.resolveProvider((any RootViewProviding).self)
        // `remove(owner:)` 会连同标签页一起撤回，因此每次都重新登记。
        contribution?.remove(owner: id)

        guard scene == .videos else {
            root?.setContentHeaderViewHidden(false)
            viewModel?.dismissPlayer()
            #if os(macOS)
            windowPresenter.deactivate()
            #endif
            return
        }

        if let contribution {
            registerTabView(contribution: contribution)
        }
        root?.setContentHeaderViewHidden(true)
        #if os(macOS)
        windowPresenter.activate()
        #endif
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
    }

    @MainActor
    private func teardownState() {
        viewModel?.dismissPlayer()
        viewModel?.unbind()
        viewModel = nil
        repositoryCapability = nil
        playbackCapability = nil
    }
}
