import CisumKernel
import ProviderDocsView
import CisumUIComponents
import OSLog
import ProviderPlayback
import ProviderScene
import SwiftUI
import MagicKit

public actor BookLikePlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = BookLikePlugin()
    public static let metadata = PluginMetadata(
        displayName: BookLikePluginInfo.title,
        description: BookLikePluginInfo.description,
        iconName: BookLikePluginInfo.iconName,
        order: BookLikePluginInfo.order,
        policy: .disabled,
        category: .like,
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var likeViewModel: BookLikeViewModel?
    nonisolated(unsafe) private var likeObserver: BookLikeObserver?

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { BookLikePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { BookLikePluginManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)🚀 onBoot") }
        // 跨插件 Provider（Scene / Playback）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        if Self.verbose { os_log("\(Self.t)🟢 onReady") }
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        teardownState()
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        sceneBox.scene = nil
        teardownState()
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        let viewModel = resolveViewModel()
        return AnyView(BookLikePluginRootView(viewModel: viewModel, content: content))
    }

    @MainActor
    public func addSettingView() -> AnyView? {
        nil
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        let viewModel = resolveViewModel()
        return PluginSettingNavigationItem(
            id: "liked-books",
            title: String(localized: "Liked Books", bundle: .module),
            description: Self.metadata.description,
            iconName: Self.metadata.iconName,
            order: Self.metadata.order,
            destination: AnyView(BookLikeSettingsView(viewModel: viewModel))
        )
    }

    // MARK: - State assembly

    /// 创建并持有喜欢状态 ViewModel 与观察者（幂等）。
    @MainActor
    private func installState(kernel: CisumKernel) {
        guard likeViewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene
        if Self.verbose { os_log("\(Self.t)🔧 installState") }

        let viewModel = BookLikeViewModel(
            playbackCapability: makePlaybackCapability(from: playback),
            loadLikedBooks: makeLoadLikedBooks(),
            saveLikeStatus: makeSaveLikeStatus()
        )
        let observer = BookLikeObserver(scene: scene, playback: playback, viewModel: viewModel)
        likeViewModel = viewModel
        likeObserver = observer
    }

    @MainActor
    private func teardownState() {
        if Self.verbose { os_log("\(Self.t)🧹 teardownState") }
        likeObserver?.cancel()
        likeObserver = nil
        likeViewModel = nil
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModel() -> BookLikeViewModel {
        if let likeViewModel {
            return likeViewModel
        }
        let viewModel = BookLikeViewModel(
            playbackCapability: makePlaybackCapability(from: kernel?.playback),
            loadLikedBooks: makeLoadLikedBooks(),
            saveLikeStatus: makeSaveLikeStatus()
        )
        likeViewModel = viewModel
        return viewModel
    }

    /// 将内核能力收窄后注入 ViewModel；ViewModel 不持有 Kernel。
    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any BookLikePlaybackCapability)? {
        guard let playback else { return nil }
        return BookLikePlaybackCapabilityAdapter(playback: playback)
    }

    /// 喜欢列表的加载入口（由插件入口组装，不暴露单例给 ViewModel）。
    @MainActor
    private func makeLoadLikedBooks() -> BookLikeLoadProvider {
        { @MainActor in
            BookLikeStore.likedBooks()
        }
    }

    /// 喜欢状态的保存入口（由插件入口组装，不暴露单例给 ViewModel）。
    @MainActor
    private func makeSaveLikeStatus() -> BookLikeSaveProvider {
        { @MainActor liked, url in
            BookLikeStore.setLiked(liked, url: url)
        }
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}
