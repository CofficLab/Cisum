import Foundation
import KernelCore
import ProviderAudioLike
import ProviderStorage

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
        guard let databaseURL = try? storage.databaseFile(name: "audio_like") else { return }
        AudioLikeRepositoryConfiguration.configure(databaseURL: databaseURL)
    }
}
