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
        // 迁移旧目录：audio_like → AudioLikePlugin（对齐 Lumi 规范）
        migrateLegacyAudioLikeDirectoryIfNeeded()
        let pluginDir = storage.pluginDataDirectory(for: "AudioLikePlugin")
        let databaseURL = pluginDir.appendingPathComponent("audio_like.db", isDirectory: false)
        AudioLikeRepositoryConfiguration.configure(databaseURL: databaseURL)
    }

    /// 迁移旧目录到新目录（如果需要）。
    ///
    /// 旧版本使用 `databaseFile(name: "audio_like")` 创建 `<databaseRoot>/audio_like/` 目录，
    /// 新版本改用 `pluginDataDirectory(for: "AudioLikePlugin")` 创建 `<databaseRoot>/AudioLikePlugin/` 目录。
    /// 此方法在首次启动时迁移旧数据，确保用户的喜欢数据不丢失。
    private func migrateLegacyAudioLikeDirectoryIfNeeded() {
        let legacyDir = storage.databaseRoot.appendingPathComponent("audio_like", isDirectory: true)
        let currentDir = storage.pluginDataDirectory(for: "AudioLikePlugin")
        PluginDataDirectoryMigration.migrate(from: legacyDir, to: currentDir)
    }
}