import ProviderAudioLike
import ProviderScene
import ProviderDocsView
import ProviderPlayback
import ProviderStorage
import CisumKernelSupport
import CisumUIComponents
import SwiftUI
import MagicKit

@MainActor
public final class AudioLikePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: AudioLikePlugin.self)

    nonisolated static let verbose = false

    public static let shared = AudioLikePlugin()
    public let order = AudioLikePluginInfo.order
    public let iconName = AudioLikePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: AudioLikePlugin.self),
        name: AudioLikePluginInfo.title,
        description: AudioLikePluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var viewModel: AudioLikeViewModel?
    nonisolated(unsafe) private var observer: AudioLikeObserver?
    nonisolated(unsafe) private var likeProvider: AudioLikeProvider?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { AudioLikePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { AudioLikePluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addSettingView() { contrib.addSettingView(view) }
            if let view = self.addSettingNavigationItem() { contrib.addSettingNavigationItem(view) }
        }
        self.kernel = kernel
        // 跨插件 Provider（Scene / Playback）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        try installProvider(kernel: kernel)
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        try installProvider(kernel: kernel)
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        teardownState()
        removeProvider(from: kernel)
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
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
            description: metadata.description,
            iconName: iconName,
            order: order,
            destination: AnyView(AudioLikeSettingsView(viewModel: viewModel))
        )
    }

    // MARK: - State assembly

    /// 创建并持有喜欢状态 ViewModel 与观察者（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
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
    private func installProvider(kernel: KernelCoreContainer) throws {
        guard likeProvider == nil, let storage = kernel.resolveProvider((any StorageProviding).self) else { return }
        let provider = AudioLikeProvider(storage: storage)
        likeProvider = provider
        try kernel.registerProvider((any AudioLikeProviding).self, provider)
    }

    @MainActor
    private func removeProvider(from kernel: KernelCoreContainer) {
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
            playbackCapability: makePlaybackCapability(from: kernel?.resolveProvider((any PlaybackProviding).self)),
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
            await self.kernel?.resolveProvider((any AudioLikeProviding).self)?.allLiked() ?? []
        }
    }

    /// 本地喜欢仓库的保存入口（由插件入口组装，不暴露单例给 ViewModel）。
    @MainActor
    private func makeSaveLikeStatus() -> AudioLikeSaveProvider {
        { @MainActor audioId, liked, url, title in
            guard let provider = self.kernel?.resolveProvider((any AudioLikeProviding).self) else { return }
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