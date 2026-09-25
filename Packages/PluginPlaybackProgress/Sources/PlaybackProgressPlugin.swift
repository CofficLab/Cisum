import CisumUIComponents
import CisumKernel
import ProviderDocsView
import ProviderPlayback
import SwiftUI
import MagicKit

/// 播放进度插件：向播放控制区注入进度条视图（`setProgressView`）。
public actor PlaybackProgressPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = PlaybackProgressPlugin()
    public static let metadata = PluginMetadata(
        displayName: String(localized: "Playback Progress", bundle: .module),
        description: String(localized: "Provides the progress bar view for the player control area.", bundle: .module),
        iconName: "waveform",
        order: 21,
        policy: .alwaysOn,
        category: .playback,
        version: "1.0.0"
    )

    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var viewModel: PlaybackProgressViewModel?
    nonisolated(unsafe) private var observer: PlaybackProgressObserver?

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { PlaybackProgressPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { PlaybackProgressPluginManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        // 跨插件 Provider 在 onReady 阶段解析。
    }

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
        teardownState()
        self.kernel = nil
    }

    /// 向 `ControlViewProviding` 注入播放进度条视图。
    @MainActor
    public func addProgressView() -> AnyView? {
        installState(kernel: kernel)
        guard let viewModel else { return nil }
        return AnyView(PlaybackProgressView(viewModel: viewModel))
    }

    @MainActor
    private func installState(kernel: CisumKernel?) {
        guard viewModel == nil else { return }
        let capability = makePlaybackCapability(from: kernel?.playback)
        let viewModel = PlaybackProgressViewModel(playbackCapability: capability)
        self.viewModel = viewModel
        observer = PlaybackProgressObserver(playback: kernel?.playback, viewModel: viewModel)
    }

    @MainActor
    private func teardownState() {
        observer?.cancel()
        observer = nil
        viewModel = nil
    }

    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any PlaybackProgressCapability)? {
        guard let playback else { return nil }
        return PlaybackProgressCapabilityAdapter(playback: playback)
    }
}
