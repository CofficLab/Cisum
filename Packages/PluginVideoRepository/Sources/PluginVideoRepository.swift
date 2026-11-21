import KernelCore
import ProviderDocsView
import ProviderPlugin
import ProviderVideo
import CisumProviderStorage
import Foundation

/// 视频仓库数据层插件。
///
/// 该插件是视频仓库的唯一组装入口：它注册 `VideoRepositoryProviding`，
/// 负责在共享存储根目录下建立视频子仓库、扫描目录，以及标签 / 评分 /
/// 播放进度等用户元数据。UI 插件只消费 Provider，不自行碰文件系统。
@MainActor
public final class PluginVideoRepository: AsyncSuperPlugin {
    public let id = "com.coffic.cisum.plugin.video-repository"

    public static let shared = PluginVideoRepository()
    public let order = 10
    public let iconName = "externaldrive.badge.timachine"
    public let metadata = PluginMetadata(
        id: "com.coffic.cisum.plugin.video-repository",
        name: "Video Repository",
        description: "Provides the video repository: folder selection, scanning and file metadata.",
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .enabledByDefault,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var provider: VideoRepositoryProvider?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { VideoRepositoryAboutView() })
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
        provider?.reloadRepository()
        await seedUITestVideoIfRequested()
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        try installProvider(kernel: kernel)
        provider?.reloadRepository()
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
    private func seedUITestVideoIfRequested() async {
        #if DEBUG
        let names = UITestVideoSeed.requestedFileNames()
        guard !names.isEmpty, let provider, let repositoryURL = provider.repositoryURL else { return }
        do {
            for name in names {
                try await UITestVideoSeed.makeVideo(at: repositoryURL.appendingPathComponent(name))
            }
            provider.refresh()
        } catch {
            VideoRepositoryProvider.logger.error("UI test video seed failed: \(error.localizedDescription)")
        }
        #endif
    }

    @MainActor
    private func installProvider(kernel: KernelCoreContainer) throws {
        guard provider == nil,
              let storage = kernel.resolveProvider((any StorageProviding).self) else { return }

        let directory = storage.pluginDataDirectory(for: id)
        let provider = VideoRepositoryProvider(storage: storage, pluginDataDirectory: directory)
        do {
            try kernel.registerProvider((any VideoRepositoryProviding).self, provider)
            self.provider = provider
        } catch {
            provider.shutdown()
            throw error
        }
    }

    @MainActor
    private func removeProvider(from kernel: KernelCoreContainer) {
        guard provider != nil else { return }
        provider?.shutdown()
        kernel.unregisterProvider((any VideoRepositoryProviding).self)
        provider = nil
    }
}
