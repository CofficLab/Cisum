import ProviderDocsView
import ProviderPlayback
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
import SwiftUI
import MagicKit

/// 播放进度插件：向播放控制区注入进度条视图（`setProgressView`）。
@MainActor
public final class PlaybackProgressPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: PlaybackProgressPlugin.self)

    nonisolated static let verbose = false

    public static let shared = PlaybackProgressPlugin()
    public let order = 21
    public let iconName = "waveform"
    public let metadata = PluginMetadata(
        id: String(describing: PlaybackProgressPlugin.self),
        name: String(localized: "Playback Progress", bundle: .module),
        description: String(localized: "Provides the progress bar view for the player control area.", bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var viewModel: PlaybackProgressViewModel?
    nonisolated(unsafe) private var observer: PlaybackProgressObserver?

    /// 进度能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式强持有，
    /// 否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var playbackCapability: ProgressBarCapabilityAdapter?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { PlaybackProgressPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { PlaybackProgressPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        // 跨插件 Provider 在 onReady 阶段解析。
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
        registerContribution(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
        registerContribution(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        teardownState()
        self.kernel = nil
    }

    /// 向 `ControlViewProviding` 注入播放进度条视图。
    @MainActor
    public func addProgressView() -> AnyView? {
        installState(kernel: kernel)
        guard let viewModel else { return nil }
        return AnyView(
            PlaybackProgressView(viewModel: viewModel)
                .appDebugBadge("Progress Bar", alignment: .bottomLeading)
        )
    }

    @MainActor
    private func registerContribution(kernel: KernelCoreContainer) {
        guard let view = addProgressView(),
              let contribution = kernel.resolveProvider((any PluginContributionProviding).self) else { return }
        contribution.addProgressView(ownerPluginID: id, view)
    }

    @MainActor
    private func installState(kernel: KernelCoreContainer?) {
        guard viewModel == nil else { return }
        let playback = ProgressBarCapabilityAdapter(
            playback: kernel?.resolveProvider((any PlaybackProviding).self)
        )
        playbackCapability = playback
        let viewModel = PlaybackProgressViewModel(playback: playback)
        self.viewModel = viewModel
        observer = PlaybackProgressObserver(playback: playback, viewModel: viewModel)
    }

    @MainActor
    private func teardownState() {
        observer?.cancel()
        observer = nil
        viewModel = nil
        playbackCapability = nil
    }

}
