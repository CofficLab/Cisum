import ProviderScene
import ProviderDocsView
import ProviderPlayback
import CisumKernelSupport
import CisumUIComponents
import ProviderAudioLibrary
import SwiftUI
import MagicKit

@MainActor
public final class AudioPlayModePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: AudioPlayModePlugin.self)

    nonisolated static let verbose = false

    public static let shared = AudioPlayModePlugin()
    public let order = AudioPlayModePluginInfo.order
    public let iconName = AudioPlayModePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: AudioPlayModePlugin.self),
        name: AudioPlayModePluginInfo.title,
        description: AudioPlayModePluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var viewModel: AudioPlayModeViewModel?
    nonisolated(unsafe) private var observer: AudioPlayModeObserver?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { AudioPlayModePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { AudioPlayModePluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        // 跨插件 Provider（Scene / Playback）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        sceneBox.scene = nil
        teardownState()
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        return AnyView(AudioPlayModePluginRootView(content: content))
    }

    // MARK: - State assembly

    /// 创建并持有播放模式 ViewModel 与观察者（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard viewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene

        let viewModel = AudioPlayModeViewModel(
            playbackCapability: makePlaybackCapability(from: playback),
            sort: makeSortAction(),
            shuffle: makeShuffleAction(),
            loadPlayMode: makeLoadPlayMode(),
            storePlayMode: makeStorePlayMode()
        )
        self.viewModel = viewModel
        observer = AudioPlayModeObserver(scene: scene, playback: playback, viewModel: viewModel)
    }

    @MainActor
    private func teardownState() {
        observer?.cancel()
        observer = nil
        viewModel = nil
    }

    /// 将内核能力收窄后注入 ViewModel；ViewModel 不持有 Kernel。
    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any AudioPlayModePlaybackCapability)? {
        guard let playback else { return nil }
        return AudioPlayModePlaybackCapabilityAdapter(playback: playback)
    }

    @MainActor
    private func makeSortAction() -> AudioPlayModeSortAction {
        let ordering = kernel?.resolveProvider(AudioLibraryOrderingProviding.self)
        return { @MainActor currentURL in
            guard let ordering else {
                throw AudioLibraryProvidingError.unavailable
            }
            await ordering.sort(url: currentURL, reason: "PlayModeChanged")
        }
    }

    @MainActor
    private func makeShuffleAction() -> AudioPlayModeShuffleAction {
        let ordering = kernel?.resolveProvider(AudioLibraryOrderingProviding.self)
        return { @MainActor currentURL in
            guard let ordering else {
                throw AudioLibraryProvidingError.unavailable
            }
            try await ordering.sortRandom(url: currentURL, reason: "PlayModeChanged", verbose: false)
        }
    }

    /// 播放模式持久化的读取入口（由插件入口组装，不暴露单例给 ViewModel）。
    @MainActor
    private func makeLoadPlayMode() -> AudioPlayModeLoadAction {
        { @MainActor in
            await AudioPlayModeStore.shared.getPlayMode()
        }
    }

    /// 播放模式持久化的保存入口（由插件入口组装，不暴露单例给 ViewModel）。
    @MainActor
    private func makeStorePlayMode() -> AudioPlayModeStoreAction {
        { @MainActor rawValue, shortName in
            await AudioPlayModeStore.shared.storePlayModeRawValue(rawValue, shortName: shortName)
        }
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}