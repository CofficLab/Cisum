import MagicKit
import ProviderAudioLike
import ProviderAudioLibrary
import ProviderScene
import ProviderDocsView
import ProviderPlayback
import CisumProviderStorage
import KernelCore
import ProviderPlugin
import KitAppEvents
import CisumUIComponents
import LumiUI
import SwiftUI

@MainActor
public final class AudioProgressPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: AudioProgressPlugin.self)

    public static let shared = AudioProgressPlugin()
    public nonisolated static let emoji = "💾"
    public static let verbose = false
    public let order = 0
    public let iconName = "waveform"
    public let metadata = PluginMetadata(
        id: String(describing: AudioProgressPlugin.self),
        name: String(localized: String.LocalizationValue(AudioProgressPluginInfo.titleKey), bundle: .module),
        description: String(localized: String.LocalizationValue(AudioProgressPluginInfo.descriptionKey), bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var progressViewModel: AudioProgressViewModel?
    nonisolated(unsafe) private var progressObserver: AudioProgressObserver?

    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    /// `library` 内部惰性解析 Provider，因此可跨 boot 阶段长期复用同一实例。
    nonisolated(unsafe) private var playbackCapability: PlaybackProgressCapabilityAdapter?
    nonisolated(unsafe) private var libraryCapability: ProgressAudioLibraryCapabilityAdapter?
    nonisolated(unsafe) private var environmentCapability: ProgressEnvironmentCapabilityAdapter?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { AudioProgressPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { AudioProgressPluginManualView() })
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
        let viewModel = resolveViewModel()
        return AnyView(AudioProgressPluginRootView(viewModel: viewModel, content: content))
    }

    // MARK: - State assembly

    /// 创建并持有播放进度 ViewModel 与观察者（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard progressObserver == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene

        let playbackCapability = PlaybackProgressCapabilityAdapter(playback: playback)
        let environment = ProgressEnvironmentCapabilityAdapter(
            scene: scene,
            library: kernel.resolveProvider((any AudioLibraryProviding).self),
            storage: kernel.resolveProvider((any StorageProviding).self)
        )
        self.playbackCapability = playbackCapability
        self.environmentCapability = environment

        let viewModel = AudioProgressViewModel(
            audioScene: .music,
            playback: playbackCapability,
            library: makeLibraryCapability(kernel: kernel),
            audioLike: { kernel.resolveProvider((any AudioLikeProviding).self) },
            saveWidgetData: { title, artist, isPlaying, coverArt in
                AudioProgressHost.saveWidgetData(title: title, artist: artist, isPlaying: isPlaying, coverArt: coverArt)
            }
        )
        let observer = AudioProgressObserver(
            playback: playbackCapability,
            environment: environment,
            viewModel: viewModel
        )
        progressViewModel = viewModel
        progressObserver = observer
    }

    @MainActor
    private func teardownState() {
        progressObserver?.cancel()
        progressObserver = nil
        progressViewModel = nil
        playbackCapability = nil
        environmentCapability = nil
    }

    /// 组装音频库能力：内部惰性解析内核 Provider，跨 boot 阶段稳定可用。
    @MainActor
    private func makeLibraryCapability(kernel: KernelCoreContainer? = nil) -> ProgressAudioLibraryCapabilityAdapter {
        if let kernel, let libraryCapability { return libraryCapability }
        let capability = ProgressAudioLibraryCapabilityAdapter {
            @MainActor [weak self] in
            (kernel ?? self?.kernel)?.resolveProvider((any AudioLibraryProviding).self)
        }
        if kernel != nil { libraryCapability = capability }
        return capability
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModel() -> AudioProgressViewModel {
        if let progressViewModel {
            return progressViewModel
        }
        // 视图贡献可能早于 onReady：此时进度条处于不可用状态，等待后续装配。
        let playback = PlaybackProgressCapabilityAdapter(
            playback: kernel?.resolveProvider((any PlaybackProviding).self)
        )
        playbackCapability = playback
        let viewModel = AudioProgressViewModel(
            audioScene: .music,
            playback: playback,
            library: makeLibraryCapability(),
            audioLike: { self.kernel?.resolveProvider((any AudioLikeProviding).self) },
            saveWidgetData: { title, artist, isPlaying, coverArt in
                AudioProgressHost.saveWidgetData(title: title, artist: artist, isPlaying: isPlaying, coverArt: coverArt)
            }
        )
        progressViewModel = viewModel
        return viewModel
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}
