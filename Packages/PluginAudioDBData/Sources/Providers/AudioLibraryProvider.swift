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
final class AudioLibraryProvider: AudioLibraryProviding, AudioLibraryOrderingProviding, SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = true

    private let storage: any StorageProviding
    private var cachedRepo: AudioRepo?
    private var storageObserver: AudioStorageObserver?
    private var eventTokens: [NSObjectProtocol] = []
    private var observers: [WeakAudioLibraryObserver] = []

    init(storage: any StorageProviding) {
        self.storage = storage
        storageObserver = AudioStorageObserver(provider: storage) { [weak self] _ in
            self?.invalidateRepository()
        }
        installEventBridge()
    }

    func shutdown() {
        storageObserver?.cancel()
        storageObserver = nil
        eventTokens.forEach { NotificationCenter.default.removeObserver($0) }
        eventTokens.removeAll()
        observers.removeAll()
        cachedRepo = nil
    }

    // MARK: - AudioLibraryProviding

    private var repository: AudioRepo? {
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

    func currentRepository() async -> AudioRepo? {
        await repository
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
        guard let repo = await repository else { return 0 }
        return await repo.getTotalCount()
    }

    func allURLs(reason: String) async -> [URL] {
        guard let repo = await repository else { return [] }
        return await repo.getAll(reason: reason)
    }

    func urls(offset: Int, limit: Int, reason: String) async -> [URL] {
        guard let repo = await repository else { return [] }
        return await repo.get(offset: offset, limit: limit, reason: reason)
    }

    func contains(_ url: URL) async -> Bool {
        guard let repo = await repository else { return false }
        return await repo.find(url) != nil
    }

    func delete(urls: [URL], verbose: Bool) async throws {
        guard let repo = await repository else {
            throw AudioPluginError.hostNotConfigured
        }
        try await repo.deleteAudios(urls, verbose: verbose)
    }

    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {
        guard let repo = await repository else { return }
        await repo.sync(urls, verbose: verbose, isFirst: isFirst)
    }

    func sort(url: URL?, reason: String) async {
        guard let repo = await repository else { return }
        await repo.sort(url, reason: reason)
    }

    func sortRandom(url: URL?, reason: String, verbose: Bool) async throws {
        guard let repo = await repository else {
            throw AudioPluginError.hostNotConfigured
        }
        try await repo.sortRandom(url, reason: reason, verbose: verbose)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioLibraryProvidingEvent) -> Void
    ) -> any AudioLibraryProvidingObserverHandle {
        let observer = AudioLibraryObserver(owner: self, callback: callback)
        observers.append(WeakAudioLibraryObserver(observer))
        return observer
    }

    func invalidateRepository() {
        cachedRepo = nil
    }

    func nextURL(after current: URL?, verbose: Bool) async throws -> URL? {
        guard let repo = await repository else { throw AudioPluginError.hostNotConfigured }
        return try await repo.getNextOf(current, verbose: verbose)
    }

    func previousURL(before current: URL?, verbose: Bool) async throws -> URL? {
        guard let repo = await repository else { throw AudioPluginError.hostNotConfigured }
        return try await repo.getPrevOf(current, verbose: verbose)
    }

    func firstURL() async throws -> URL? {
        guard let repo = await repository else { throw AudioPluginError.hostNotConfigured }
        return try await repo.getFirst()
    }

    func lastURL() async throws -> URL? {
        guard let repo = await repository else { throw AudioPluginError.hostNotConfigured }
        return try await repo.getLast()
    }

    private func installEventBridge() {
        let center = NotificationCenter.default
        eventTokens.append(center.addObserver(forName: .dbSyncing, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.notify(.syncing) }
        })
        eventTokens.append(center.addObserver(forName: .dbSynced, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.notify(.synced(totalCount: await self.totalCount()))
            }
        })
        eventTokens.append(center.addObserver(forName: .dbUpdated, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.notify(.updated(totalCount: await self.totalCount()))
            }
        })
        eventTokens.append(center.addObserver(forName: .dbDeleted, object: nil, queue: .main) { [weak self] notification in
            let urls = notification.userInfo?["urls"] as? [URL] ?? []
            Task { @MainActor in
                guard let self else { return }
                self.notify(.deleted(urls: urls, totalCount: await self.totalCount()))
            }
        })
        eventTokens.append(center.addObserver(forName: .DBSorting, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.notify(.sorting) }
        })
        eventTokens.append(center.addObserver(forName: .DBSortDone, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.notify(.sortCompleted) }
        })
    }

    private func notify(_ event: AudioLibraryProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        for observer in observers {
            observer.observer?.invoke(event)
        }
    }
}

@MainActor
private final class AudioLibraryObserver: AudioLibraryProvidingObserverHandle {
    private weak var owner: AudioLibraryProvider?
    private let callback: (AudioLibraryProvidingEvent) -> Void
    private var cancelled = false

    init(owner: AudioLibraryProvider, callback: @escaping (AudioLibraryProvidingEvent) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        owner?.removeObserver(self)
    }

    func invoke(_ event: AudioLibraryProvidingEvent) {
        guard !cancelled else { return }
        callback(event)
    }
}

@MainActor
private final class WeakAudioLibraryObserver {
    weak var observer: AudioLibraryObserver?

    init(_ observer: AudioLibraryObserver) {
        self.observer = observer
    }
}

private extension AudioLibraryProvider {
    func removeObserver(_ observer: AudioLibraryObserver) {
        observers.removeAll { $0.observer === observer }
    }
}
