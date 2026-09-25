import ProviderAudioLike
import ProviderAudioLibrary
import ProviderScene
import ProviderDocsView
import ProviderPlayback
import ProviderStorage
import CisumKernelSupport
import CisumUIComponents
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

        let viewModel = AudioProgressViewModel(
            audioScene: .music,
            playbackCapability: makePlaybackCapability(from: playback),
            audioLibrary: { kernel.resolveProvider((any AudioLibraryProviding).self) },
            audioLike: { kernel.resolveProvider((any AudioLikeProviding).self) },
            saveWidgetData: { title, artist, isPlaying, coverArt in
                AudioProgressHost.saveWidgetData(title: title, artist: artist, isPlaying: isPlaying, coverArt: coverArt)
            }
        )
        let observer = AudioProgressObserver(
            scene: scene,
            playback: playback,
            library: kernel.resolveProvider((any AudioLibraryProviding).self),
            storage: kernel.resolveProvider((any StorageProviding).self),
            viewModel: viewModel,
        )
        progressViewModel = viewModel
        progressObserver = observer
    }

    @MainActor
    private func teardownState() {
        progressObserver?.cancel()
        progressObserver = nil
        progressViewModel = nil
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModel() -> AudioProgressViewModel {
        if let progressViewModel {
            return progressViewModel
        }
        let viewModel = AudioProgressViewModel(
            audioScene: .music,
            playbackCapability: makePlaybackCapability(from: kernel?.resolveProvider((any PlaybackProviding).self)),
            audioLibrary: { self.kernel?.resolveProvider((any AudioLibraryProviding).self) },
            audioLike: { self.kernel?.resolveProvider((any AudioLikeProviding).self) },
            saveWidgetData: { title, artist, isPlaying, coverArt in
                AudioProgressHost.saveWidgetData(title: title, artist: artist, isPlaying: isPlaying, coverArt: coverArt)
            }
        )
        progressViewModel = viewModel
        return viewModel
    }

    /// 将内核能力收窄后注入 ViewModel；ViewModel 不持有 Kernel。
    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any AudioProgressPlaybackCapability)? {
        guard let playback else { return nil }
        return AudioProgressPlaybackCapabilityAdapter(playback: playback)
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}