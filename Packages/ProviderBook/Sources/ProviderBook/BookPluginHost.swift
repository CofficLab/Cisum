import Foundation
import ProviderBook

public enum BookPluginHost {
    public typealias DBRootProvider = @MainActor () throws -> URL
    public typealias StorageRootProvider = @MainActor () -> URL?

    nonisolated(unsafe) private static var dbRootProvider: DBRootProvider?
    nonisolated(unsafe) private static var storageRootProvider: StorageRootProvider?
    nonisolated(unsafe) private static var storageLocationDidChangeNotificationsValue: [Notification.Name] = []

    @MainActor
    public static func configure(
        dbRoot: @escaping DBRootProvider,
        storageRoot: @escaping StorageRootProvider,
        storageLocationDidChangeNotifications: [Notification.Name]
    ) {
        dbRootProvider = dbRoot
        storageRootProvider = storageRoot
        storageLocationDidChangeNotificationsValue = storageLocationDidChangeNotifications
    }

    @MainActor
    public static func getDBRootDir() throws -> URL {
        guard let dbRootProvider else {
            throw BookPluginError.configurationMissing
        }
        return try dbRootProvider()
    }

    @MainActor
    public static func getStorageRoot() -> URL? {
        storageRootProvider?()
    }

    @MainActor
    public static var storageLocationDidChangeNotifications: [Notification.Name] {
        storageLocationDidChangeNotificationsValue
    }

    /// Shared book-library access used by feature plugins.
    ///
    /// The implementation lives behind this provider target so feature plugins
    /// do not need to import the `PluginBook` lifecycle target.
    @MainActor
    public static func getBookDisk() -> URL? {
        guard let storageRoot = getStorageRoot() else { return nil }
        return try? storageRoot
            .appendingPathComponent(BookPluginInfo.dirName, isDirectory: true)
            .ensureDirectory()
    }

    @MainActor
    public static func getBookRepoAsync() async -> BookRepo? {
        let dbRoot = try? getDBRootDir()
        guard let dbRoot, let disk = getBookDisk() else { return nil }

        let container = await Task.detached(priority: .utility) {
            try? BookConfig.getContainer(dbRootURL: dbRoot)
        }.value
        guard let container else { return nil }

        return try? BookRepo(
            disk: disk,
            db: BookDB(container, reason: "BookPluginHost.background")
        )
    }
}
