import ProviderScene
import ProviderDocsView
import ProviderPlayback
import KernelCore
import ProviderPlugin
import KitAppEvents
import CisumUIComponents
import LumiUI
import OSLog
import ProviderSettingView
import SwiftUI
import MagicKit

@MainActor
public final class BookLikePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: BookLikePlugin.self)

    nonisolated static let verbose = false

    public static let shared = BookLikePlugin()
    public let order = BookLikePluginInfo.order
    public let iconName = BookLikePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: BookLikePlugin.self),
        name: BookLikePluginInfo.title,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var likeViewModel: BookLikeViewModel?
    nonisolated(unsafe) private var likeObserver: BookLikeObserver?

    /// 本插件消费的能力 Adapter。Observer 只在 init 期间使用能力安装订阅，
    /// 但入口仍显式持有以满足组装层所有权约定（Capabilities 规范第 5 条）。
    nonisolated(unsafe) private var bookLikeSceneCapability: BookLikeSceneCapabilityAdapter?
    nonisolated(unsafe) private var bookLikePlaybackCapability: BookLikePlaybackCapabilityAdapter?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { BookLikePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { BookLikePluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addSettingView() { contrib.addSettingView(ownerPluginID: id, view) }
            if let entry = makeSettingEntry() { kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([entry]) }
        }
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
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["liked-books"])
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
    public func makeSettingEntry() -> SettingEntryItem? {
        let viewModel = resolveViewModel()
        return SettingEntryItem(
            id: "liked-books",
            title: String(localized: "Liked Books", bundle: .module),
            systemImage: iconName,
            order: order,
            detail: {
            BookLikeSettingsView(viewModel: viewModel)
        }
        )
    }

    // MARK: - State assembly

    /// 创建并持有喜欢状态 ViewModel 与观察者（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard likeViewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene
        if Self.verbose { os_log("\(Self.t)🔧 installState") }

        // 入口强持有 Adapter，ViewModel / Observer 以 Bool 或参数消费。
        let sceneCapability = BookLikeSceneCapabilityAdapter(scene: scene)
        let playbackCapability = BookLikePlaybackCapabilityAdapter(playback: playback)
        bookLikeSceneCapability = sceneCapability
        bookLikePlaybackCapability = playbackCapability

        let viewModel = BookLikeViewModel(
            isPlaybackAvailable: true,
            loadLikedBooks: makeLoadLikedBooks(),
            saveLikeStatus: makeSaveLikeStatus()
        )
        let observer = BookLikeObserver(
            scene: sceneCapability,
            playback: playbackCapability,
            viewModel: viewModel
        )
        likeViewModel = viewModel
        likeObserver = observer
    }

    @MainActor
    private func teardownState() {
        if Self.verbose { os_log("\(Self.t)🧹 teardownState") }
        likeObserver?.cancel()
        likeObserver = nil
        likeViewModel = nil
        bookLikeSceneCapability = nil
        bookLikePlaybackCapability = nil
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModel() -> BookLikeViewModel {
        if let likeViewModel {
            return likeViewModel
        }
        // 视图贡献可能早于 boot：此时喜欢保存处于停用状态，等待后续装配。
        let viewModel = BookLikeViewModel(
            isPlaybackAvailable: kernel?.resolveProvider((any PlaybackProviding).self) != nil,
            loadLikedBooks: makeLoadLikedBooks(),
            saveLikeStatus: makeSaveLikeStatus()
        )
        likeViewModel = viewModel
        return viewModel
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
