import ProviderScene
import ProviderDocsView
import ProviderPlayback
import KernelCore
import ProviderPlugin
import KitAppEvents
import OSLog
import LumiUI
import ProviderBook
import ProviderToast
import SwiftUI
import MagicKit

@MainActor
public final class BookProgressPlugin: AsyncSuperPlugin, SuperLog {
    public let id = "com.coffic.cisum.plugin.book-progress"

    nonisolated static let verbose = false

    public static let shared = BookProgressPlugin()
    public let order = BookProgressPluginInfo.order
    public let iconName = BookProgressPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: "com.coffic.cisum.plugin.book-progress",
        name: BookProgressPluginInfo.title,
        description: BookProgressPluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var playbackCapability: BookProgressPlaybackCapabilityAdapter?
    nonisolated(unsafe) private var libraryCapability: BookProgressLibraryCapabilityAdapter?
    nonisolated(unsafe) private var sceneCapability: BookProgressSceneCapabilityAdapter?
    nonisolated(unsafe) private var toastCapability: BookProgressToastCapabilityAdapter?
    nonisolated(unsafe) private var progressViewModel: BookProgressViewModel?
    nonisolated(unsafe) private var progressObserver: BookProgressObserver?
    /// 控制区进度条（与持久化 ViewModel 分离，只负责显示与拖动）。
    nonisolated(unsafe) private var barCapability: BookProgressBarCapabilityAdapter?
    nonisolated(unsafe) private var barViewModel: BookProgressBarViewModel?
    nonisolated(unsafe) private var barObserver: BookProgressBarObserver?
    /// 场景激活句柄：进度条只在本插件自己的有声书场景登记。
    nonisolated(unsafe) private var sceneHandle: (any SceneProvidingObserverHandle)?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { BookProgressPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { BookProgressPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)🚀 onBoot") }
        // 跨插件 Provider（Scene / Playback）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)🟢 onReady") }
        installState(kernel: kernel)
        installSceneActivation(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        installState(kernel: kernel)
        installSceneActivation(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        sceneHandle?.cancel()
        sceneHandle = nil
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        sceneHandle?.cancel()
        sceneHandle = nil
        sceneBox.scene = nil
        teardownState()
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        let viewModel = resolveViewModel()
        return AnyView(BookProgressPluginRootView(viewModel: viewModel, content: content))
    }

    /// 向播放控制区注入有声书章节进度条（由场景激活决定是否登记）。
    @MainActor
    public func addProgressView() -> AnyView? {
        if let kernel {
            installState(kernel: kernel)
        }
        guard let barViewModel else { return nil }
        return AnyView(BookProgressBarView(viewModel: barViewModel))
    }

    /// 有声书场景才登记进度条；其他场景撤下，交给该场景自己的进度插件。
    @MainActor
    private func installSceneActivation(kernel: KernelCoreContainer) {
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        applyScene(scene.currentScene, kernel: kernel)

        guard sceneHandle == nil else { return }
        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(newScene) = event else { return }
            guard let self, let kernel = self.kernel else { return }
            self.applyScene(newScene, kernel: kernel)
        }
    }

    @MainActor
    private func applyScene(_ scene: AppScene?, kernel: KernelCoreContainer) {
        guard let contribution = kernel.resolveProvider((any PluginContributionProviding).self) else { return }
        guard scene == .audiobooks else {
            contribution.remove(owner: id)
            return
        }
        guard let view = addProgressView() else { return }
        contribution.addProgressView(ownerPluginID: id, view)
    }

    // MARK: - State assembly

    /// 创建并持有播放进度 ViewModel 与观察者（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        installBarState(kernel: kernel)

        guard progressViewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playbackProvider = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene

        // 入口持有 Adapter，ViewModel 以 `weak` 消费。
        let playback = BookProgressPlaybackCapabilityAdapter(playback: playbackProvider)
        let library = BookProgressLibraryCapabilityAdapter(
            books: kernel.resolveProvider(BookDatabaseProviding.self)
        )
        let sceneCapability = BookProgressSceneCapabilityAdapter(scene: scene)
        let toast = BookProgressToastCapabilityAdapter(
            toast: kernel.resolveProvider((any ToastProviding).self)
        )
        self.playbackCapability = playback
        self.libraryCapability = library
        self.sceneCapability = sceneCapability
        self.toastCapability = toast

        let viewModel = BookProgressViewModel(
            targetScene: .audiobooks,
            playback: playback,
            library: library,
            toast: toast
        )
        let observer = BookProgressObserver(
            scene: sceneCapability,
            playback: playback,
            library: library,
            viewModel: viewModel
        )
        progressViewModel = viewModel
        progressObserver = observer
    }

    /// 组装控制区进度条状态（与持久化 ViewModel 相互独立）。
    @MainActor
    private func installBarState(kernel: KernelCoreContainer) {
        guard barViewModel == nil else { return }
        guard let playbackProvider = kernel.resolveProvider((any PlaybackProviding).self) else { return }

        let capability = BookProgressBarCapabilityAdapter(
            playback: playbackProvider,
            books: kernel.resolveProvider(BookDatabaseProviding.self)
        )
        let viewModel = BookProgressBarViewModel(playback: capability)
        barCapability = capability
        barViewModel = viewModel
        barObserver = BookProgressBarObserver(playback: capability, viewModel: viewModel)
    }

    @MainActor
    private func teardownState() {
        progressObserver?.cancel()
        progressObserver = nil
        progressViewModel = nil
        barObserver?.cancel()
        barObserver = nil
        barViewModel = nil
        barCapability = nil
        playbackCapability = nil
        libraryCapability = nil
        sceneCapability = nil
        toastCapability = nil
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModel() -> BookProgressViewModel {
        if let progressViewModel {
            return progressViewModel
        }
        // 视图贡献可能早于 onReady：此时进度条处于不可用状态，等待后续装配。
        let viewModel = BookProgressViewModel(
            targetScene: .audiobooks,
            playback: kernel?.resolveProvider((any PlaybackProviding).self)
                .map(BookProgressPlaybackCapabilityAdapter.init),
            library: BookProgressLibraryCapabilityAdapter(
                books: kernel?.resolveProvider(BookDatabaseProviding.self)
            ),
            toast: kernel?.resolveProvider((any ToastProviding).self)
                .map(BookProgressToastCapabilityAdapter.init)
        )
        progressViewModel = viewModel
        return viewModel
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}
