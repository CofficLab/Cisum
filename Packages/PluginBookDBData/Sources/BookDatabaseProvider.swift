import Foundation
import ProviderBook
import ProviderBookData
import ProviderStorage

@MainActor
final class BookDatabaseProvider: BookDatabaseProviding {
    private let storage: any StorageProviding
    private var cachedRepository: BookRepo?
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
        cachedRepository = nil
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
            db: BookDB(container, reason: "BookDBDataPlugin")
        )
        cachedRepository = repository
        return repository
    }

    func totalCount() async -> Int {
        await books(reason: "BookDatabaseProvider.totalCount").count
    }

    func books(reason: String) async -> [BookDTO] {
        await repository()?.getAll(reason: reason) ?? []
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
        _ callback: @escaping @Sendable (BookProvidingEvent) -> Void
    ) -> any BookProvidingObserverHandle {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .bookDBSyncing,
            .bookDBSynced,
            .bookDBUpdated,
            .bookDBDeleted,
            .bookDBSortDone,
            .bookStateUpdated,
        ]
        var tokens: [NSObjectProtocol] = []
        for name in names {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let deletedURLs = notification.userInfo?["urls"] as? [URL] ?? []
                let playbackURL = notification.userInfo?["url"] as? URL
                Task { @MainActor in
                    guard let self else { return }
                    if name == .bookDBSyncing || name == .bookDBSynced || name == .bookDBUpdated || name == .bookDBDeleted || name == .bookDBSortDone {
                        BookCoverRepo.clearCache()
                    }
                    if name == .bookDBSyncing {
                        callback(.librarySyncing)
                    } else if name == .bookDBSynced {
                        callback(.librarySynced)
                    } else if name == .bookDBDeleted {
                        callback(.libraryDeleted(urls: deletedURLs))
                    } else if name == .bookDBSortDone {
                        callback(.librarySorted)
                    } else if name == .bookStateUpdated {
                        callback(.playbackStateChanged(url: playbackURL))
                    } else {
                        callback(.libraryChanged(totalCount: await self.totalCount()))
                    }
                }
            })
        }
        let storageHandle = storage.addObserver { event in
            guard case .locationChanged = event else { return }
            callback(.storageLocationChanged)
        }
        return BookProvidingNotificationObserverHandle(tokens: tokens, storageHandle: storageHandle)
    }

    func invalidateRepository() {
        cachedRepository = nil
    }
}

@MainActor
private final class BookProvidingNotificationObserverHandle: BookProvidingObserverHandle {
    private var tokens: [NSObjectProtocol]
    private var storageHandle: (any StorageProvidingObserverHandle)?

    init(
        tokens: [NSObjectProtocol],
        storageHandle: (any StorageProvidingObserverHandle)?
    ) {
        self.tokens = tokens
        self.storageHandle = storageHandle
    }

    func cancel() {
        let center = NotificationCenter.default
        tokens.forEach { center.removeObserver($0) }
        tokens.removeAll()
        storageHandle?.cancel()
        storageHandle = nil
    }

}
