import KernelCore
import ProviderDocsView
import CisumUIComponents
import ProviderAudioLibrary
import ProviderPlayback
import ProviderScene
import SwiftUI

public actor AudioProgressPlugin: SuperPlugin, SuperLog {
    public static let shared = AudioProgressPlugin()
    public nonisolated static let emoji = "💾"
    public static let verbose = false
    public static let metadata = PluginMetadata(
        displayName: String(localized: String.LocalizationValue(AudioProgressPluginInfo.titleKey), bundle: .module),
        description: String(localized: String.LocalizationValue(AudioProgressPluginInfo.descriptionKey), bundle: .module),
        iconName: "waveform",
        order: 0,
        category: .playback,
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var progressViewModel: AudioProgressViewModel?
    nonisolated(unsafe) private var progressObserver: AudioProgressObserver?

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioProgressPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioProgressPluginManualView() })
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
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        teardownState()
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
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
    private func installState(kernel: CisumKernel) {
        guard progressObserver == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene

        let viewModel = AudioProgressViewModel(
            audioScene: .music,
            playbackCapability: makePlaybackCapability(from: playback),
            audioLibrary: { kernel.audioLibrary },
            audioLike: { kernel.audioLike },
            saveWidgetData: { title, artist, isPlaying, coverArt in
                AudioProgressHost.saveWidgetData(title: title, artist: artist, isPlaying: isPlaying, coverArt: coverArt)
            }
        )
        let observer = AudioProgressObserver(
            scene: scene,
            playback: playback,
            library: kernel.audioLibrary,
            storage: kernel.storage,
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
            playbackCapability: makePlaybackCapability(from: kernel?.playback),
            audioLibrary: { self.kernel?.audioLibrary },
            audioLike: { self.kernel?.audioLike },
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
