import ProviderAudioLibrary
import CisumProviderStorage
import Foundation
import MagicKit
import OSLog

/// 音频数据库 Provider：负责构造 `AudioRepo` 并暴露给视图层。
///
/// 由 `AudioDBDataPlugin` 在启动时创建并注册到内核；视图层插件通过
/// `AudioLibraryProviding` 协议使用它，不再自行构造数据库。
@MainActor
final class AudioLibraryProvider: AudioLibraryProviding, AudioLibraryOrderingProviding, SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.cisum", category: "plugin.audio-db-data")

    private let storage: any StorageProviding
    private var cachedRepo: AudioRepo?

    /// 订阅权益能力：数据层据此判断本次同步是否受容量限制。
    ///
    /// 惰性解析商店 Provider（boot 顺序不固定）；未就绪时按「受限」处理，
    /// 宁可先挡住超限文件，也不要让免费用户绕过上限。
    private let entitlement: any AudioDataEntitlementCapability
    private var storageObserver: AudioStorageObserver?
    private var observers: [WeakAudioLibraryObserver] = []
    private var repositoryIsKnownEmpty: Bool?

    init(
        storage: any StorageProviding,
        entitlement: any AudioDataEntitlementCapability
    ) {
        self.storage = storage
        self.entitlement = entitlement
        storageObserver = AudioStorageObserver(
            storage: AudioDataStorageCapabilityAdapter(storage: storage)
        ) { [weak self] _ in
            self?.invalidateRepository()
        }
    }

    func shutdown() {
        storageObserver?.cancel()
        storageObserver = nil
        observers.removeAll()
        cachedRepo = nil
        repositoryIsKnownEmpty = nil
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
            let repo = try? AudioRepo(
                container: container,
                disk: disk,
                reason: "AudioDBDataPlugin",
                eventHandler: { [weak self] event in
                    await MainActor.run { self?.notify(event) }
                }
            )
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

    /// 仓库是否确认为空：结论来自扫描状态本身。
    ///
    /// `repositoryIsKnownEmpty` 是三态：`nil` 表示还没扫过（不知道），
    /// `true` 表示扫完了且确认为空。只有 `true` 才算「仓库是空的」——
    /// 未扫描时数据库里同样没有记录，那不是空仓库的证据。
    var isRepositoryEmpty: Bool {
        repositoryIsKnownEmpty == true
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

        // 容量兜底：应用内写入走闸门，但仓库目录对用户可见——用户可以直接
        // 把文件拷进去。目录监控会把它们同步进来，这里挡住超限的那部分，
        // 只让它留在磁盘上而不进索引（付费后额度放宽，下一次同步自然回来）。
        let admitted = await capacityAdmittedURLs(urls, isFirst: isFirst)

        await repo.sync(admitted, verbose: verbose, isFirst: isFirst)
    }

    /// 按容量上限筛选本次同步允许进入索引的文件。
    private func capacityAdmittedURLs(_ urls: [URL], isFirst: Bool) async -> [URL] {
        guard !urls.isEmpty else { return urls }
        guard entitlement.isCapacityLimited else { return urls }

        // 首次全量同步：索引里还没有任何记录，existingCount 为 0。
        // 增量同步：索引里已有的文件已占用额度。
        let existingCount = isFirst ? 0 : await totalCount()
        let limit = AudioPluginInfo.maxAudioCount

        let admitted = AudioSyncCapacityGuard.admittedURLs(
            urls: urls,
            existingCount: existingCount,
            fileLimit: limit
        )
        if admitted.count < urls.count {
            Self.logger.warning(
                "\(Self.t)⚠️ Sync capacity guard: admitted \(admitted.count)/\(urls.count) file(s) (limit \(limit), existing \(existingCount))"
            )
        }
        return admitted
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
        if repositoryIsKnownEmpty == true {
            observer.invoke(.repositoryEmpty)
        }
        return observer
    }

    func invalidateRepository() {
        cachedRepo = nil
        repositoryIsKnownEmpty = nil
        notify(.repositoryAvailabilityChanged)
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

    private func notify(_ event: AudioLibraryProvidingEvent) {
        let isEmpty: Bool?
        switch event {
        case .synced(let totalCount), .updated(let totalCount), .deleted(_, let totalCount):
            isEmpty = totalCount == 0
        case .syncing, .repositoryEmpty, .repositoryAvailabilityChanged, .sorting, .sortCompleted:
            isEmpty = nil
        }

        let shouldPublishEmpty = isEmpty == true && repositoryIsKnownEmpty != true
        if let isEmpty {
            repositoryIsKnownEmpty = isEmpty
        }

        observers.removeAll { $0.observer == nil }
        for observer in observers {
            observer.observer?.invoke(event)
        }

        if shouldPublishEmpty {
            observers.removeAll { $0.observer == nil }
            for observer in observers {
                observer.observer?.invoke(.repositoryEmpty)
            }
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
