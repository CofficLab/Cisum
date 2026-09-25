import ProviderScene
import ProviderDocsView
import ProviderPlayback
import CisumKernelSupport
import CisumUIComponents
import SwiftUI
import MagicKit

@MainActor
public final class AudioDownloadPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: AudioDownloadPlugin.self)

    nonisolated static let verbose = false

    public static let shared = AudioDownloadPlugin()
    public let order = AudioDownloadPluginInfo.order
    public let iconName = AudioDownloadPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: AudioDownloadPlugin.self),
        name: AudioDownloadPluginInfo.title,
        description: AudioDownloadPluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { AudioDownloadPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { AudioDownloadPluginManualView() })
        }
    }

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private var viewModel: AudioDownloadViewModel?
    nonisolated(unsafe) private var observer: AudioDownloadObserver?

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
        return AnyView(AudioDownloadPluginRootView(content: content))
    }

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard viewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene

        let capability = AudioDownloadPlaybackCapabilityAdapter(playback: playback)
        let viewModel = AudioDownloadViewModel(playbackCapability: capability)
        self.viewModel = viewModel
        observer = AudioDownloadObserver(
            scene: scene,
            playback: playback,
            viewModel: viewModel
        )
    }

    @MainActor
    private func teardownState() {
        observer?.cancel()
        observer = nil
        viewModel = nil
    }


    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}