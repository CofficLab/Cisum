import ProviderAppState
import ProviderDocsView
import ProviderPlayback
import ProviderAudioLibrary
import ProviderScene
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
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
    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var playbackCapability: HeroPlaybackCapabilityAdapter?
    nonisolated(unsafe) private var mediaCapability: HeroMediaCapabilityAdapter?
    nonisolated(unsafe) private var libraryCapability: HeroLibraryCapabilityAdapter?
    nonisolated(unsafe) private var sceneCapability: HeroSceneCapabilityAdapter?
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
        self.kernel = kernel
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        installState(kernel: kernel)

        guard let contribution = kernel.resolveProvider((any PluginContributionProviding).self) else { return }
        if let view = addHeroView() {
            contribution.addHeroView(ownerPluginID: id, view)
        }
        if let view = addRightAlbumView() {
            contribution.addRightAlbumView(ownerPluginID: id, view)
        }
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        observer?.cancel()
        observer = nil
        viewModel = nil
        playbackCapability = nil
        mediaCapability = nil
        libraryCapability = nil
        sceneCapability = nil
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
            .appDebugBadge("Playback Cover", alignment: .topTrailing)
        )
    }

    /// 向宽窗口的右侧专辑区域注入同一份播放状态驱动的媒体视图。
    @MainActor
    public func addRightAlbumView() -> AnyView? {
        installState(kernel: kernel)
        guard let viewModel else { return nil }
        return AnyView(
            PlaybackHeroRightAlbumView(viewModel: viewModel)
                .appDebugBadge("Right Album", alignment: .bottomLeading)
        )
    }

    @MainActor
    private func installState(kernel: KernelCoreContainer?) {
        guard viewModel == nil else { return }
        guard let playbackProvider = kernel?.resolveProvider((any PlaybackProviding).self) else { return }
        let playback = HeroPlaybackCapabilityAdapter(playback: playbackProvider)
        let media = HeroMediaCapabilityAdapter(
            media: kernel?.resolveProvider((any PlaybackMediaProviding).self)
        )
        let library = HeroLibraryCapabilityAdapter(
            library: kernel?.resolveProvider((any AudioLibraryProviding).self)
        )
        let scene = HeroSceneCapabilityAdapter(
            scene: kernel?.resolveProvider((any SceneProviding).self)
        )
        playbackCapability = playback
        mediaCapability = media
        libraryCapability = library
        sceneCapability = scene

        let viewModel = PlaybackHeroViewModel(
            playback: playback,
            media: media,
            isMusicSceneActive: scene.currentScene == .music
        )
        self.viewModel = viewModel
        observer = PlaybackHeroObserver(
            playback: playback,
            library: library,
            scene: scene,
            viewModel: viewModel
        )
    }
}
