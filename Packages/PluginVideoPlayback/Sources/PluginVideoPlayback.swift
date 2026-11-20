import KernelCore
import ProviderDocsView
import ProviderPlugin
import ProviderVideo
import Foundation

/// 视频播放插件。
///
/// 注册 `VideoPlaybackProviding`：视频场景的播放状态、进度与画面都由它提供。
/// 引擎本身（mpv / AVPlayer / VideoToolbox）是插件内部细节，外部只看到
/// 统一的播放能力。
@MainActor
public final class PluginVideoPlayback: AsyncSuperPlugin {
    public let id = "com.coffic.cisum.plugin.video-playback"

    public static let shared = PluginVideoPlayback()
    public let order = 11
    public let iconName = "play.rectangle"
    public let metadata = PluginMetadata(
        id: "com.coffic.cisum.plugin.video-playback",
        name: "Video Playback",
        description: "Provides video playback for the video library scene.",
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var provider: VideoPlaybackProvider?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { VideoPlaybackAboutView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        try installProvider(kernel: kernel)
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        try installProvider(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        try installProvider(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        removeProvider(from: kernel)
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        removeProvider(from: kernel)
        self.kernel = nil
    }

    @MainActor
    private func installProvider(kernel: KernelCoreContainer) throws {
        guard provider == nil else { return }
        let provider = VideoPlaybackProvider()
        do {
            try kernel.registerProvider((any VideoPlaybackProviding).self, provider)
            self.provider = provider
        } catch {
            throw error
        }
    }

    @MainActor
    private func removeProvider(from kernel: KernelCoreContainer) {
        guard provider != nil else { return }
        provider?.stop()
        kernel.unregisterProvider((any VideoPlaybackProviding).self)
        provider = nil
    }
}
