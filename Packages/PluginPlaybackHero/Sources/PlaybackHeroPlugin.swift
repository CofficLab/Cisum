import ProviderAppState
import ProviderDocsView
import ProviderPlayback
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

/// 播放封面插件：向播放控制区注入封面/标题区视图（`setHeroView`）。
@MainActor
public final class PlaybackHeroPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: PlaybackHeroPlugin.self)

    nonisolated static let verbose = false

    public static let shared = PlaybackHeroPlugin()
    public let order = 19
    public let iconName = "photo"
    public let metadata = PluginMetadata(
        id: String(describing: PlaybackHeroPlugin.self),
        name: String(localized: "Playback Cover", bundle: .module),
        description: String(localized: "Provides the cover and title view for the player control area.", bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var viewModel: PlaybackHeroViewModel?
    nonisolated(unsafe) private var observer: PlaybackHeroObserver?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { PlaybackHeroPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { PlaybackHeroPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addHeroView() { contrib.addHeroView(view) }
            if let view = self.addRightAlbumView() { contrib.addRightAlbumView(view) }
        }
        self.kernel = kernel
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        installState(kernel: kernel)
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        observer?.cancel()
        observer = nil
        viewModel = nil
        self.kernel = nil
    }

    /// 向 `ControlViewProviding` 注入封面/标题区视图。
    @MainActor
    public func addHeroView() -> AnyView? {
        installState(kernel: kernel)
        guard let viewModel else { return nil }
        return AnyView(
            PlaybackHeroView(
                viewModel: viewModel,
                isDemoMode: kernel?.resolveProvider((any AppStateProviding).self)?.isDemoMode ?? false
            )
        )
    }

    /// 向宽窗口的右侧专辑区域注入同一份播放状态驱动的媒体视图。
    @MainActor
    public func addRightAlbumView() -> AnyView? {
        installState(kernel: kernel)
        guard let viewModel else { return nil }
        return AnyView(PlaybackHeroRightAlbumView(viewModel: viewModel))
    }

    @MainActor
    private func installState(kernel: KernelCoreContainer?) {
        guard viewModel == nil else { return }
        guard let playback = kernel?.resolveProvider((any PlaybackProviding).self) else { return }
        let media = kernel?.resolveProvider((any PlaybackMediaProviding).self)
        let capability = PlaybackHeroPlaybackCapabilityAdapter(playback: playback, media: media)
        let viewModel = PlaybackHeroViewModel(playbackCapability: capability)
        self.viewModel = viewModel
        observer = PlaybackHeroObserver(playback: playback, viewModel: viewModel)
    }
}