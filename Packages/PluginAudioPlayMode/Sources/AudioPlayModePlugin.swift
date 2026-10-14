import ProviderScene
import ProviderDocsView
import ProviderPlayback
import KernelCore
import ProviderPlugin
import KitAppEvents
import LumiUI
import ProviderAudioLibrary
import ProviderToast
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

    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var playbackCapability: AudioPlayModeCapabilityAdapter?
    nonisolated(unsafe) private var sceneCapability: AudioPlayModeSceneCapabilityAdapter?
    nonisolated(unsafe) private var orderingCapability: AudioQueueOrderingCapabilityAdapter?
    nonisolated(unsafe) private var toastCapability: AudioPlayModeToastCapabilityAdapter?

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

        // 入口强持有 Adapter，ViewModel / Observer 以 `weak` 或参数消费。
        let playbackCapability = AudioPlayModeCapabilityAdapter(playback: playback)
        let sceneCapability = AudioPlayModeSceneCapabilityAdapter(scene: scene)
        let orderingCapability = AudioQueueOrderingCapabilityAdapter(
            ordering: kernel.resolveProvider(AudioLibraryOrderingProviding.self)
        )
        let toastCapability = AudioPlayModeToastCapabilityAdapter(
            toast: kernel.resolveProvider((any ToastProviding).self)
        )
        self.playbackCapability = playbackCapability
        self.sceneCapability = sceneCapability
        self.orderingCapability = orderingCapability
        self.toastCapability = toastCapability

        let viewModel = AudioPlayModeViewModel(
            playback: playbackCapability,
            ordering: orderingCapability,
            loadPlayMode: makeLoadPlayMode(),
            storePlayMode: makeStorePlayMode(),
            toast: toastCapability
        )
        self.viewModel = viewModel
        observer = AudioPlayModeObserver(
            scene: sceneCapability,
            playback: playbackCapability,
            viewModel: viewModel
        )
    }

    @MainActor
    private func teardownState() {
        observer?.cancel()
        observer = nil
        viewModel = nil
        playbackCapability = nil
        sceneCapability = nil
        orderingCapability = nil
        toastCapability = nil
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
