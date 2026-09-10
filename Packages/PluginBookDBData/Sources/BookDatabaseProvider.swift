import Foundation
import ProviderBook
import ProviderStorage

@MainActor
final class BookDatabaseProvider: BookDatabaseProviding {
    private let storage: any StorageProviding
    private var cachedRepository: BookRepo?
    private var storageObserver: (any StorageProvidingObserverHandle)?

    init(storage: any StorageProviding) {
        self.storage = storage
        storageObserver = storage.addObserver { [weak self] _ in
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

    func repository() async -> BookRepo? {
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
        guard let repository = await repository() else { return 0 }
        return await repository.getAll(reason: "BookDatabaseProvider.totalCount").count
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping @Sendable (BookProvidingEvent) -> Void
    ) -> any BookProvidingObserverHandle {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .bookDBSynced,
            .bookDBUpdated,
            .bookDBDeleted,
            .bookDBSortDone,
        ]
        var tokens: [NSObjectProtocol] = []
        for name in names {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    callback(.libraryChanged(totalCount: await self.totalCount()))
                }
            })
        }
        return BookProvidingNotificationObserverHandle(tokens: tokens)
    }

    func invalidateRepository() {
        cachedRepository = nil
    }
}

@MainActor
private final class BookProvidingNotificationObserverHandle: BookProvidingObserverHandle {
    private var tokens: [NSObjectProtocol]

    init(tokens: [NSObjectProtocol]) {
        self.tokens = tokens
    }

    func cancel() {
        let center = NotificationCenter.default
        tokens.forEach { center.removeObserver($0) }
        tokens.removeAll()
    }

}
