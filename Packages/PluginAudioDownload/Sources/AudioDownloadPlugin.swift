import CisumKernel
import ProviderDocsView
import CisumUIComponents
import ProviderPlayback
import ProviderScene
import SwiftUI
import MagicKit

public actor AudioDownloadPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = AudioDownloadPlugin()
    public static let metadata = PluginMetadata(
        displayName: AudioDownloadPluginInfo.title,
        description: AudioDownloadPluginInfo.description,
        iconName: AudioDownloadPluginInfo.iconName,
        order: AudioDownloadPluginInfo.order,
        category: .playback,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioDownloadPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioDownloadPluginManualView() })
        }
    }

    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private var viewModel: AudioDownloadViewModel?
    nonisolated(unsafe) private var observer: AudioDownloadObserver?

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
        return AnyView(AudioDownloadPluginRootView(content: content))
    }

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: CisumKernel) {
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
