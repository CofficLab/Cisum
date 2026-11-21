import ProviderBook
import ProviderPlayback
import ProviderScene
import ProviderDocsView
import KernelCore
import ProviderPlugin
import KitAppEvents
import LumiUI
import OSLog
import SwiftUI
import MagicKit

@MainActor
public final class BookScenePlugin: AsyncSuperPlugin, SuperLog {
    public let id = "com.coffic.cisum.plugin.book-scene"

    nonisolated static let verbose = false

    public static let shared = BookScenePlugin()
    public let order = BookScenePluginInfo.order
    public let iconName = BookScenePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: "com.coffic.cisum.plugin.book-scene",
        name: BookScenePluginInfo.title,
        description: BookScenePluginInfo.description,
        version: "1.0.0",
        category: .core,
        stage: .stable,
        policy: .enabledByDefault,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { BookScenePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { BookScenePluginManualView() })
        }
    }

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var setSceneAction: (@MainActor (AppScene) -> Void)?

    private nonisolated(unsafe) var heroViewModel: BookHeroViewModel?
    private nonisolated(unsafe) var heroObserver: BookHeroObserver?
    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    private nonisolated(unsafe) var playbackCapability: BookHeroPlaybackCapabilityAdapter?
    private nonisolated(unsafe) var libraryCapability: BookHeroLibraryCapabilityAdapter?
    /// 场景激活句柄：封面只在本插件自己的有声书场景登记。
    private nonisolated(unsafe) var sceneHandle: (any SceneProvidingObserverHandle)?

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addPosterView() { contrib.addPosterView(ownerPluginID: id, view) }
        }
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)🚀 onBoot") }
        // 跨插件 Provider（Scene）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再解析 Scene / Playback Provider。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)🟢 onReady") }
        installSceneAction(kernel: kernel)
        installState(kernel: kernel)
        installSceneActivation(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        installSceneAction(kernel: kernel)
        installState(kernel: kernel)
        installSceneActivation(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        sceneHandle?.cancel()
        sceneHandle = nil
        teardownState()
        setSceneAction = nil
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        sceneHandle?.cancel()
        sceneHandle = nil
        teardownState()
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        setSceneAction = nil
    }

    @MainActor
    public func addPosterView() -> AnyView? {
        AnyView(
            BookScenePluginPosterView(setCurrentScene: setSceneAction ?? { _ in })
                // .appDebugBadge("Audiobooks", alignment: .bottomLeading)
        )
    }

    /// 向控制区注入有声书封面/标题区（仅在有声书场景登记）。
    @MainActor
    public func addHeroView() -> AnyView? {
        installState(kernel: kernel)
        guard let heroViewModel else { return nil }
        return AnyView(BookHeroView(viewModel: heroViewModel))
    }

    /// 向宽窗口的右侧封面区注入同一份状态驱动的书籍封面。
    @MainActor
    public func addRightAlbumView() -> AnyView? {
        installState(kernel: kernel)
        guard let heroViewModel else { return nil }
        return AnyView(BookHeroRightAlbumView(viewModel: heroViewModel))
    }

    /// 有声书场景才登记封面贡献；其他场景撤下，交给该场景自己的封面插件。
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
        // `remove(owner:)` 会连同海报一起撤回；海报是场景入口卡，与场景切换无关，
        // 每轮登记后都补回，避免切换场景把它弄丢。
        contribution.remove(owner: id)
        if let poster = addPosterView() {
            contribution.addPosterView(ownerPluginID: id, poster)
        }
        guard scene == .audiobooks else { return }
        if let view = addHeroView() {
            contribution.addHeroView(ownerPluginID: id, view)
        }
        if let view = addRightAlbumView() {
            contribution.addRightAlbumView(ownerPluginID: id, view)
        }
    }

    // MARK: - State assembly

    /// 组装封面 ViewModel 与观察者（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer?) {
        guard heroViewModel == nil else { return }
        guard let kernel,
              let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self),
              let books = kernel.resolveProvider(BookDatabaseProviding.self) else { return }

        let playbackCapability = BookHeroPlaybackCapabilityAdapter(playback: playback)
        let libraryCapability = BookHeroLibraryCapabilityAdapter(books: books)
        self.playbackCapability = playbackCapability
        self.libraryCapability = libraryCapability

        let viewModel = BookHeroViewModel(
            playback: playbackCapability,
            library: libraryCapability
        )
        heroViewModel = viewModel
        heroObserver = BookHeroObserver(
            playback: playbackCapability,
            library: libraryCapability,
            scene: scene,
            viewModel: viewModel
        )
    }

    @MainActor
    private func teardownState() {
        heroObserver?.cancel()
        heroObserver = nil
        heroViewModel = nil
        playbackCapability = nil
        libraryCapability = nil
    }

    @MainActor
    private func installSceneAction(kernel: KernelCoreContainer) {
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        self.setSceneAction = { @MainActor sceneValue in
            scene.setCurrentScene(sceneValue)
        }
    }
}