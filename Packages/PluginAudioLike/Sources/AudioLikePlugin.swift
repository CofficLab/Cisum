import KernelCore
import ProviderDocsView
import CisumUIComponents
import ProviderAudioLike
import ProviderStorage
import ProviderPlayback
import ProviderScene
import SwiftUI
import MagicKit

public actor AudioLikePlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = AudioLikePlugin()
    public static let metadata = PluginMetadata(
        displayName: AudioLikePluginInfo.title,
        description: AudioLikePluginInfo.description,
        iconName: AudioLikePluginInfo.iconName,
        order: AudioLikePluginInfo.order,
        policy: .disabled,
        category: .like,
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var viewModel: AudioLikeViewModel?
    nonisolated(unsafe) private var observer: AudioLikeObserver?
    nonisolated(unsafe) private var likeProvider: AudioLikeProvider?

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioLikePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioLikePluginManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        // 跨插件 Provider（Scene / Playback）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        try installProvider(kernel: kernel)
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        try installProvider(kernel: kernel)
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        teardownState()
        removeProvider(from: kernel)
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        sceneBox.scene = nil
        teardownState()
        removeProvider(from: kernel)
        self.kernel = nil
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        let viewModel = resolveViewModel()
        return AnyView(AudioLikePluginRootView(viewModel: viewModel, content: content))
    }

    @MainActor
    public func addSettingView() -> AnyView? {
        nil
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        let viewModel = resolveViewModel()
        return PluginSettingNavigationItem(
            id: "liked-audio",
            title: String(localized: "Liked audio", bundle: .module),
            description: Self.metadata.description,
            iconName: Self.metadata.iconName,
            order: Self.metadata.order,
            destination: AnyView(AudioLikeSettingsView(viewModel: viewModel))
        )
    }

    // MARK: - State assembly

    /// 创建并持有喜欢状态 ViewModel 与观察者（幂等）。
    @MainActor
    private func installState(kernel: CisumKernel) {
        guard viewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene

        let viewModel = AudioLikeViewModel(
            playbackCapability: makePlaybackCapability(from: playback),
            loadLikedAudios: makeLoadLikedAudios(),
            saveLikeStatus: makeSaveLikeStatus()
        )
        let observer = AudioLikeObserver(scene: scene, playback: playback, viewModel: viewModel)
        self.viewModel = viewModel
        self.observer = observer
    }

    @MainActor
    private func installProvider(kernel: CisumKernel) throws {
        guard likeProvider == nil, let storage = kernel.storage else { return }
        let provider = AudioLikeProvider(storage: storage)
        likeProvider = provider
        try kernel.registerAudioLike(provider)
    }

    @MainActor
    private func removeProvider(from kernel: CisumKernel) {
        likeProvider?.shutdown()
        likeProvider = nil
        kernel.unregisterProvider(AudioLikeProviding.self)
    }

    @MainActor
    private func teardownState() {
        observer?.cancel()
        observer = nil
        viewModel = nil
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModel() -> AudioLikeViewModel {
        if let viewModel {
            return viewModel
        }
        let viewModel = AudioLikeViewModel(
            playbackCapability: makePlaybackCapability(from: kernel?.playback),
            loadLikedAudios: makeLoadLikedAudios(),
            saveLikeStatus: makeSaveLikeStatus()
        )
        self.viewModel = viewModel
        return viewModel
    }

    /// 将内核能力收窄后注入 ViewModel；ViewModel 不持有 Kernel。
    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any AudioLikePlaybackCapability)? {
        guard let playback else { return nil }
        return AudioLikePlaybackCapabilityAdapter(playback: playback)
    }

    /// 本地喜欢仓库的加载入口（由插件入口组装，不暴露单例给 ViewModel）。
    @MainActor
    private func makeLoadLikedAudios() -> AudioLikeLoadProvider {
        { @MainActor in
            await self.kernel?.audioLike?.allLiked() ?? []
        }
    }

    /// 本地喜欢仓库的保存入口（由插件入口组装，不暴露单例给 ViewModel）。
    @MainActor
    private func makeSaveLikeStatus() -> AudioLikeSaveProvider {
        { @MainActor audioId, liked, url, title in
            guard let provider = self.kernel?.audioLike else { return }
            try await provider.updateLikeStatus(
                audioId: audioId,
                liked: liked,
                url: url,
                title: title
            )
        }
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}
