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
        // 迁移旧目录：books_db/books_cover → BookDBDataPlugin（对齐 Lumi 规范）
        migrateLegacyBookDirectoriesIfNeeded()
        let pluginDir = storage.pluginDataDirectory(for: "BookDBDataPlugin")
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

    /// 迁移旧目录到新目录（如果需要）。
    ///
    /// 旧版本使用 `databaseRoot/books_db/` 和 `databaseRoot/books_cover/` 目录，
    /// 新版本改用 `pluginDataDirectory(for: "BookDBDataPlugin")` 目录。
    /// 此方法在首次启动时迁移旧数据，确保用户的书籍数据库和封面不丢失。
    private func migrateLegacyBookDirectoriesIfNeeded() {
        let legacyDBDir = storage.databaseRoot.appendingPathComponent("books_db", isDirectory: true)
        let legacyCoverDir = storage.databaseRoot.appendingPathComponent("books_cover", isDirectory: true)
        // 用只解析路径的 API：pluginDataDirectory 会创建目录，
        // 那样「新目录是否存在」的判断将永远为真，迁移就永远不会执行。
        let currentDir = storage.pluginDataDirectoryPath(for: "BookDBDataPlugin")

        // 优先迁移数据库目录（更重要）：它整体变成插件目录。
        if PluginDataDirectoryMigration.migrate(from: legacyDBDir, to: currentDir) {
            // 封面目录跟着进入插件目录内。
            if FileManager.default.fileExists(atPath: legacyCoverDir.path) {
                let newCoverDir = currentDir.appendingPathComponent("books_cover", isDirectory: true)
                PluginDataDirectoryMigration.migrate(from: legacyCoverDir, to: newCoverDir)
            }
            return
        }

        // 数据库目录不存在时，若只有封面目录，则单独迁移。
        if FileManager.default.fileExists(atPath: legacyCoverDir.path) {
            let newCoverDir = currentDir.appendingPathComponent("books_cover", isDirectory: true)
            PluginDataDirectoryMigration.migrate(from: legacyCoverDir, to: newCoverDir)
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
