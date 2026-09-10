import Foundation
import MagicKit
import OSLog
import ProviderAudioLibrary
import ProviderStorage

/// 音频数据库 Provider：负责构造 `AudioRepo` 并暴露给视图层。
///
/// 由 `AudioDBDataPlugin` 在启动时创建并注册到内核；视图层插件通过
/// `AudioLibraryProviding` 协议使用它，不再自行构造数据库。
@MainActor
final class AudioLibraryProvider: AudioLibraryProviding, ObservableObject, SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = false

    private let storage: any StorageProviding
    private var cachedRepo: AudioRepo?
    private var storageObserver: (any StorageProvidingObserverHandle)?

    init(storage: any StorageProviding) {
        self.storage = storage
        storageObserver = storage.addObserver { [weak self] event in
            self?.invalidateRepository()
        }
    }

    func shutdown() {
        storageObserver?.cancel()
        storageObserver = nil
        cachedRepo = nil
    }

    // MARK: - AudioLibraryProviding

    var audioRepo: AudioRepo? {
        get async {
            if let cachedRepo {
                return cachedRepo
            }
            guard let disk = audioDisk else { return nil }
            guard let databaseURL = try? storage.databaseFile(name: "audio") else { return nil }
            guard let container = try? AudioConfigRepo.getContainer(databaseURL: databaseURL) else { return nil }
            let repo = try? AudioRepo(container: container, disk: disk, reason: "AudioDBDataPlugin")
            cachedRepo = repo
            return repo
        }
    }

    var audioDisk: URL? {
        guard let root = storage.storageRoot else { return nil }
        return try? root
            .appendingPathComponent(AudioPluginInfo.effectiveDBDirName, isDirectory: true)
            .ensureDirectory()
    }

    var supportedExtensions: [String] {
        AudioPluginInfo.supportedExtensions
    }

    var isAvailable: Bool {
        audioDisk != nil
    }

    func totalCount() async -> Int {
        guard let repo = await audioRepo else { return 0 }
        return await repo.getTotalCount()
    }

    func invalidateRepository() {
        cachedRepo = nil
    }
}
