import ProviderAudioLike
import ProviderScene
import ProviderDocsView
import ProviderPlayback
import CisumProviderStorage
import ProviderToast
import KernelCore
import ProviderPlugin
import KitAppEvents
import LumiUI
import ProviderSettingView
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
            if let view = self.addSettingView() { contrib.addSettingView(ownerPluginID: id, view) }
            if let entry = makeSettingEntry() { kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([entry]) }
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
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["liked-audio"])
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
    public func makeSettingEntry() -> SettingEntryItem? {
        let viewModel = resolveViewModel()
        return SettingEntryItem(
            id: "liked-audio",
            title: String(localized: "Liked audio", bundle: .module),
            systemImage: iconName,
            order: order,
            detail: {
            AudioLikeSettingsView(viewModel: viewModel)
        }
        )
    }

    // MARK: - State assembly

    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var repositoryCapability: AudioLikeRepositoryCapabilityAdapter?
    nonisolated(unsafe) private var playbackCapability: AudioLikePlaybackCapabilityAdapter?
    nonisolated(unsafe) private var sceneCapability: AudioLikeSceneCapabilityAdapter?
    nonisolated(unsafe) private var toastCapability: AudioLikeToastCapabilityAdapter?

    /// 创建并持有喜欢状态 ViewModel 与观察者（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard viewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene

        // 入口强持有 Adapter；仓库能力内部惰性解析本插件注册的 Provider。
        let repository = AudioLikeRepositoryCapabilityAdapter { @MainActor [weak self] in
            self?.kernel?.resolveProvider((any AudioLikeProviding).self)
        }
        let playbackCapability = AudioLikePlaybackCapabilityAdapter(playback: playback)
        let sceneCapability = AudioLikeSceneCapabilityAdapter(scene: scene)
        let toastCapability = AudioLikeToastCapabilityAdapter(
            toast: kernel.resolveProvider((any ToastProviding).self)
        )
        repositoryCapability = repository
        self.playbackCapability = playbackCapability
        self.sceneCapability = sceneCapability
        self.toastCapability = toastCapability

        let viewModel = AudioLikeViewModel(
            isPlaybackAvailable: true,
            repository: repository,
            toast: toastCapability
        )
        let observer = AudioLikeObserver(
            scene: sceneCapability,
            playback: playbackCapability,
            viewModel: viewModel
        )
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
        repositoryCapability = nil
        playbackCapability = nil
        sceneCapability = nil
        toastCapability = nil
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModel() -> AudioLikeViewModel {
        if let viewModel {
            return viewModel
        }
        // 视图贡献可能早于 boot：仓库能力内部惰性解析，无需在此重新装配观察者。
        let repository = AudioLikeRepositoryCapabilityAdapter { @MainActor [weak self] in
            self?.kernel?.resolveProvider((any AudioLikeProviding).self)
        }
        repositoryCapability = repository
        let viewModel = AudioLikeViewModel(
            isPlaybackAvailable: kernel?.resolveProvider((any PlaybackProviding).self) != nil,
            repository: repository,
            toast: kernel?.resolveProvider((any ToastProviding).self)
                .map(AudioLikeToastCapabilityAdapter.init)
        )
        self.viewModel = viewModel
        return viewModel
    }



    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}
