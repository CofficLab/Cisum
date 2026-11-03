import ProviderAudioLike
import CisumProviderStorage
import Foundation
import KernelCore
import ProviderPlugin
import KitAppEvents

/// 喜欢数据的唯一实现入口。
///
/// SwiftData 模型、容器和去重策略都留在本插件内，对外只暴露
/// `AudioLikeProviding`。
@MainActor
final class AudioLikeProvider: AudioLikeProviding {
    private let storage: any StorageProviding
    private var storageObserver: (any StorageProvidingObserverHandle)?

    init(storage: any StorageProviding) {
        self.storage = storage
        configureRepository()
        storageObserver = storage.addObserver { [weak self] _ in
            self?.configureRepository()
        }
    }

    func shutdown() {
        storageObserver?.cancel()
        storageObserver = nil
    }

    func isLiked(url: URL) async -> Bool {
        await AudioLikeRepo.shared.isLiked(url: url)
    }

    func allLiked() async -> [AudioLikeItem] {
        await AudioLikeRepo.shared.getAllLiked().map {
            AudioLikeItem(audioId: $0.audioId, url: $0.url, title: $0.title, liked: $0.liked)
        }
    }

    func updateLikeStatus(audioId: String, liked: Bool, url: URL?, title: String?) async throws {
        try await AudioLikeRepo.shared.updateLikeStatus(
            audioId: audioId,
            liked: liked,
            url: url,
            title: title
        )
    }

    private func configureRepository() {
        let pluginID = "com.coffic.cisum.plugin.audio-like"
        // 迁移旧目录（audio_like → AudioLikePlugin → 当前 id）。
        // 必须在目标目录被创建之前迁移，否则迁移永远不执行。
        migrateLegacyDirectoryIfNeeded(pluginID: pluginID)
        let pluginDir = storage.pluginDataDirectory(for: pluginID)
        let databaseURL = pluginDir.appendingPathComponent("audio_like.db", isDirectory: false)
        AudioLikeRepositoryConfiguration.configure(databaseURL: databaseURL)
    }

    /// 迁移历史目录到当前插件目录（如果需要）。
    ///
    /// 目录名随插件 id 变过两轮（`audio_like` → `AudioLikePlugin` → 反向 DNS），
    /// 历史目录名由存储层统一登记，这里只负责调用。
    private func migrateLegacyDirectoryIfNeeded(pluginID: String) {
        PluginDataDirectoryMigration.migrate(
            legacyDirectoryNames: PluginDataDirectoryHistory.legacyDirectoryNames(for: pluginID),
            pluginID: pluginID,
            dataRootDirectory: storage.databaseRoot
        )
    }
}