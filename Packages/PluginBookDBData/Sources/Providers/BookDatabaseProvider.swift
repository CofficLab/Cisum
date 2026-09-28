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

    init(storage: any StorageProviding) {
        self.storage = storage
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
        let dbRoot = databaseRoot
        let container = await Task.detached(priority: .utility) {
            try? BookConfig.getContainer(dbRootURL: dbRoot)
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
        BookSettingRepo.getCurrent()
    }

    func currentBookTime() -> TimeInterval? {
        BookSettingRepo.getCurrentTime()
    }

    func storeCurrentBookURL(_ url: URL?) {
        BookSettingRepo.storeCurrent(url)
    }

    func storeCurrentBookTime(_ time: TimeInterval) {
        BookSettingRepo.storeCurrentTime(time)
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
