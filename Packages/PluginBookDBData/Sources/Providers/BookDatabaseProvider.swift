import ProviderBookData
import CisumProviderStorage
import Foundation
import MagicKit
import OSLog
import ProviderBook

@MainActor
final class BookDatabaseProvider: BookDatabaseProviding, SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = false

    private let storage: any StorageProviding
    private var cachedRepository: BookRepo?
    private var storageObserver: (any StorageProvidingObserverHandle)?
    private var observers: [WeakBookProvidingObserver] = []

    /// 当前书籍的持久化仓库。
    ///
    /// 注入而非直接用 `BookSettingRepo.shared`：让单元测试可以给它一个
    /// 独立的偏好存储，避免读写开发者的真实偏好与真实 iCloud 键值库。
    private let bookSettings: BookSettingRepo

    init(storage: any StorageProviding, bookSettings: BookSettingRepo = .shared) {
        self.storage = storage
        self.bookSettings = bookSettings
        storageObserver = storage.addObserver { [weak self] event in
            self?.invalidateRepository()
        }
    }

    func shutdown() {
        storageObserver?.cancel()
        storageObserver = nil
        invalidateRepository()
    }

    var bookDisk: URL? {
        guard let root = storage.storageRoot else { return nil }
        return try? root
            .appendingPathComponent(BookPluginInfo.dirName, isDirectory: true)
            .ensureDirectory()
    }

    var isAvailable: Bool {
        bookDisk != nil
    }

    var databaseRoot: URL {
        storage.databaseRoot
    }

    private func repository() async -> BookRepo? {
        if let cachedRepository {
            return cachedRepository
        }

        guard let disk = bookDisk else { return nil }
        let pluginID = "com.coffic.cisum.plugin.book-db-data"
        // 迁移旧目录（books_db/books_cover → BookDBDataPlugin → 当前 id）。
        // 必须在目标目录被创建之前迁移，否则迁移永远不执行。
        migrateLegacyDirectoryIfNeeded(pluginID: pluginID)
        let pluginDir = storage.pluginDataDirectory(for: pluginID)
        let container = await Task.detached(priority: .utility) {
            try? BookConfig.getContainer(pluginDirectory: pluginDir)
        }.value
        guard let container else { return nil }

        let repository = try? BookRepo(
            disk: disk,
            db: BookDB(
                container,
                reason: "BookDBDataPlugin",
                eventHandler: { [weak self] event in self?.notify(event) }
            )
        )
        cachedRepository = repository
        return repository
    }

    /// 迁移历史目录到当前插件目录（如果需要）。
    ///
    /// 目录名随插件 id 变过两轮（`books_db` → `BookDBDataPlugin` → 反向 DNS），
    /// 历史目录名由存储层统一登记，这里只负责调用。
    ///
    /// 封面目录 `books_cover` 历史上与数据库目录**平级**，而插件目录里它
    /// 在 `books_cover/` 子目录下，因此需要单独搬一次。
    private func migrateLegacyDirectoryIfNeeded(pluginID: String) {
        let dataRoot = storage.databaseRoot
        let currentDirectory = dataRoot.appendingPathComponent(pluginID, isDirectory: true)

        PluginDataDirectoryMigration.migrate(
            legacyDirectoryNames: PluginDataDirectoryHistory.legacyDirectoryNames(for: pluginID),
            pluginID: pluginID,
            dataRootDirectory: dataRoot
        )

        // 封面目录：历史布局里与数据库目录平级，插件布局里是子目录。
        let legacyCoverDirectory = dataRoot.appendingPathComponent("books_cover", isDirectory: true)
        if FileManager.default.fileExists(atPath: legacyCoverDirectory.path) {
            let newCoverDirectory = currentDirectory.appendingPathComponent("books_cover", isDirectory: true)
            PluginDataDirectoryMigration.migrate(from: legacyCoverDirectory, to: newCoverDirectory)
        }
    }

    func totalCount() async -> Int {
        await books(reason: "BookDatabaseProvider.totalCount").count
    }

    func books(reason: String) async -> [BookDTO] {
        if Self.verbose {
            os_log("\(Self.t)🚀 books ➡️ \(reason)")
        }
        guard let repository = await repository() else {
            os_log(.error, "\(Self.t)❌ repository is nil")
            return []
        }
        return await repository.getAll(reason: reason)
    }

    func syncImportedItems(_ items: [URL]) async throws {
        guard let repository = await repository() else {
            throw BookPluginError.initialization(reason: "Book repository is unavailable")
        }
        try await repository.syncImportedItems(items)
    }

    func coverData(for bookURL: URL) async -> Data? {
        await repository()?.getCoverData(for: bookURL)
    }

    func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO? {
        await repository()?.playbackState(for: bookURL)
    }

    func savePlaybackState(
        for bookURL: URL,
        currentURL: URL?,
        time: TimeInterval?
    ) async throws {
        guard let repository = await repository() else {
            throw BookPluginError.initialization(reason: "Book repository is unavailable")
        }
        try await repository.savePlaybackState(
            for: bookURL,
            currentURL: currentURL,
            time: time
        )
    }

    func currentBookURL() -> URL? {
        bookSettings.getCurrent()
    }

    func currentBookTime() -> TimeInterval? {
        bookSettings.getCurrentTime()
    }

    func storeCurrentBookURL(_ url: URL?) {
        bookSettings.storeCurrent(url)
    }

    func storeCurrentBookTime(_ time: TimeInterval) {
        bookSettings.storeCurrentTime(time)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping @MainActor @Sendable (BookProvidingEvent) -> Void
    ) -> any BookProvidingObserverHandle {
        let observer = BookProvidingObserver(owner: self, callback: callback)
        observers.append(WeakBookProvidingObserver(observer))
        observer.storageHandle = storage.addObserver { [weak observer] event in
            guard case .locationChanged = event else { return }
            observer?.invoke(.storageLocationChanged)
        }
        return observer
    }

    func invalidateRepository() {
        cachedRepository?.shutdown()
        cachedRepository = nil
    }

    private func notify(_ event: BookProvidingEvent) {
        switch event {
        case .librarySyncing, .librarySynced, .libraryChanged, .libraryDeleted:
            BookCoverRepo.clearCache()
        case .playbackStateChanged, .storageLocationChanged:
            break
        }
        observers.removeAll { $0.observer == nil }
        observers.forEach { $0.observer?.invoke(event) }
    }

    fileprivate func removeObserver(_ observer: BookProvidingObserver) {
        observers.removeAll { $0.observer === observer }
    }
}

@MainActor
private final class BookProvidingObserver: BookProvidingObserverHandle {
    private weak var owner: BookDatabaseProvider?
    private let callback: @MainActor @Sendable (BookProvidingEvent) -> Void
    fileprivate var storageHandle: (any StorageProvidingObserverHandle)?
    private var cancelled = false

    init(
        owner: BookDatabaseProvider,
        callback: @escaping @MainActor @Sendable (BookProvidingEvent) -> Void
    ) {
        self.owner = owner
        self.callback = callback
    }

    func invoke(_ event: BookProvidingEvent) {
        guard !cancelled else { return }
        callback(event)
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        storageHandle?.cancel()
        storageHandle = nil
        owner?.removeObserver(self)
    }
}

@MainActor
private final class WeakBookProvidingObserver {
    weak var observer: BookProvidingObserver?

    init(_ observer: BookProvidingObserver) {
        self.observer = observer
    }
}
