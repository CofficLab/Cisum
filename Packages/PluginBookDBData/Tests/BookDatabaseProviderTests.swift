import Combine
import Foundation
import KernelCore
import ProviderBook
import ProviderStorage
import Testing
@testable import PluginBookDBData

private func canonicalBookPaths(_ urls: [URL]) -> [String] {
    urls.map { $0.resolvingSymlinksInPath().standardizedFileURL.path }
}

@MainActor
private final class BookTestStorageObserverHandle: StorageProvidingObserverHandle {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel?()
        onCancel = nil
    }
}

@MainActor
private final class BookTestStorageProvider: @preconcurrency StorageProviding {
    let objectWillChange = ObservableObjectPublisher()

    private(set) var currentStorageLocation: StorageLocation?
    private(set) var storageRoot: URL?
    private let fallbackDatabaseRoot: URL
    private var observers: [UUID: (StorageProvidingEvent) -> Void] = [:]

    init(storageRoot: URL?, databaseRoot: URL) {
        self.storageRoot = storageRoot
        self.fallbackDatabaseRoot = databaseRoot
        currentStorageLocation = storageRoot == nil ? nil : .local
    }

    var hasUsableStorageLocation: Bool { storageRoot != nil }
    var isICloudStorageAvailable: Bool { false }
    var databaseRoot: URL { storageRoot?.appendingPathComponent("database") ?? fallbackDatabaseRoot }

    func storageRoot(for location: StorageLocation) -> URL? {
        location == .local ? storageRoot : nil
    }

    func databaseFile(name: String) throws -> URL {
        let directory = databaseRoot.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(name).db")
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        let directory = databaseRoot.appendingPathComponent(pluginID, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func setStorageLocation(_ location: StorageLocation?) {
        currentStorageLocation = location
        if location != .local { storageRoot = nil }
        notify(.locationChanged(location))
    }

    func resetStorageLocation() {
        currentStorageLocation = nil
        storageRoot = nil
        notify(.locationChanged(nil))
    }

    func addObserver(
        _ callback: @escaping (StorageProvidingEvent) -> Void
    ) -> any StorageProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return BookTestStorageObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func updateStorageRoot(_ root: URL?) {
        storageRoot = root
        currentStorageLocation = root == nil ? nil : .local
        notify(.storageAvailabilityChanged)
    }

    var activeObserverCount: Int { observers.count }

    private func notify(_ event: StorageProvidingEvent) {
        for callback in observers.values {
            callback(event)
        }
    }
}

@MainActor
private final class BookEventRecorder {
    private(set) var events: [String] = []

    func record(_ event: BookProvidingEvent) {
        switch event {
        case .librarySyncing:
            events.append("syncing")
        case .librarySynced:
            events.append("synced")
        case let .libraryChanged(totalCount):
            events.append("changed:\(totalCount)")
        case let .libraryDeleted(urls):
            events.append("deleted:\(urls.count)")
        case .librarySorted:
            events.append("sorted")
        case let .playbackStateChanged(url):
            events.append("playback:\(url?.lastPathComponent ?? "nil")")
        case .storageLocationChanged:
            events.append("storage")
        }
    }
}

@Suite(.serialized)
@MainActor
struct BookDatabaseProviderTests {
    @Test
    func unavailableStorageReturnsEmptyReadsAndRejectsWrites() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookDatabaseUnavailable-\(UUID().uuidString)", isDirectory: true)
        let storage = BookTestStorageProvider(storageRoot: nil, databaseRoot: root)
        let provider = BookDatabaseProvider(storage: storage)
        defer {
            provider.shutdown()
            try? FileManager.default.removeItem(at: root)
        }

        #expect(provider.bookDisk == nil)
        #expect(!provider.isAvailable)
        #expect(provider.databaseRoot == root)
        #expect(await provider.totalCount() == 0)
        #expect(await provider.books(reason: "unavailable").isEmpty)
        #expect(await provider.coverData(for: URL(fileURLWithPath: "/missing/book.mp3")) == nil)
        #expect(await provider.playbackState(for: URL(fileURLWithPath: "/missing/book.mp3")) == nil)

        await #expect(throws: BookPluginError.self) {
            try await provider.syncImportedItems([URL(fileURLWithPath: "/missing/book.mp3")])
        }
        await #expect(throws: BookPluginError.self) {
            try await provider.savePlaybackState(
                for: URL(fileURLWithPath: "/missing/book.mp3"),
                currentURL: nil,
                time: nil
            )
        }

        #expect(storage.activeObserverCount == 1)
        provider.shutdown()
        #expect(storage.activeObserverCount == 0)
    }

    @Test
    func librarySyncPlaybackStateAndStorageChangesUseCurrentRepository() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookDatabaseProvider-\(UUID().uuidString)", isDirectory: true)
        let firstStorageRoot = root.appendingPathComponent("First", isDirectory: true)
        let secondStorageRoot = root.appendingPathComponent("Second", isDirectory: true)
        let firstDisk = firstStorageRoot.appendingPathComponent(BookPluginInfo.dirName, isDirectory: true)
        let secondDisk = secondStorageRoot.appendingPathComponent(BookPluginInfo.dirName, isDirectory: true)
        try FileManager.default.createDirectory(at: firstDisk, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDisk, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let previousSyncTime = UserDefaults.standard.object(forKey: "BookLastUpdateTime")
        defer {
            if let previousSyncTime {
                UserDefaults.standard.set(previousSyncTime, forKey: "BookLastUpdateTime")
            } else {
                UserDefaults.standard.removeObject(forKey: "BookLastUpdateTime")
            }
        }

        let firstBook = firstDisk.appendingPathComponent("first.mp3")
        let importedBook = firstDisk.appendingPathComponent("imported.m4b")
        let secondBook = secondDisk.appendingPathComponent("second.aac")
        try Data([0x01, 0x02]).write(to: firstBook)
        try Data([0x05, 0x06]).write(to: secondBook)

        let storage = BookTestStorageProvider(storageRoot: firstStorageRoot, databaseRoot: root.appendingPathComponent("FallbackDB"))
        let provider = BookDatabaseProvider(storage: storage)
        defer { provider.shutdown() }

        #expect(provider.isAvailable)
        let initialBooks = await provider.books(reason: "initial-sync")
        #expect(canonicalBookPaths(initialBooks.map(\.url)) == canonicalBookPaths([firstBook]))
        #expect(await provider.totalCount() == 1)
        #expect(await provider.coverData(for: firstBook) == nil)
        #expect(await provider.playbackState(for: firstBook) == nil)

        try Data([0x03, 0x04]).write(to: importedBook)
        try await provider.syncImportedItems([importedBook])
        let importedBooks = await provider.books(reason: "after-import")
        #expect(canonicalBookPaths(importedBooks.map(\.url)) == canonicalBookPaths([firstBook, importedBook]))
        #expect(await provider.totalCount() == 2)

        let chapter = firstDisk.appendingPathComponent("chapter.mp3")
        try await provider.savePlaybackState(for: firstBook, currentURL: chapter, time: 12.5)
        #expect(await provider.playbackState(for: firstBook) == BookPlaybackStateDTO(currentURL: chapter, time: 12.5))

        storage.updateStorageRoot(secondStorageRoot)
        let switchedBooks = await provider.books(reason: "after-storage-change")
        #expect(canonicalBookPaths(switchedBooks.map(\.url)) == canonicalBookPaths([secondBook]))
        #expect(await provider.totalCount() == 1)
        #expect(await provider.playbackState(for: firstBook) == nil)

        provider.shutdown()
        #expect(storage.activeObserverCount == 0)
    }

    @Test
    func providerNotificationsMapToEventsAndCancelCleanly() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookDatabaseObserver-\(UUID().uuidString)", isDirectory: true)
        let storage = BookTestStorageProvider(storageRoot: nil, databaseRoot: root)
        let provider = BookDatabaseProvider(storage: storage)
        let recorder = BookEventRecorder()
        let observer = provider.addObserver { event in
            Task { @MainActor in recorder.record(event) }
        }
        let book = URL(fileURLWithPath: "/library/novel.mp3")

        NotificationCenter.default.post(name: .bookDBSyncing, object: nil)
        NotificationCenter.default.post(name: .bookDBSynced, object: nil)
        NotificationCenter.default.post(name: .bookDBUpdated, object: nil)
        NotificationCenter.default.post(name: .bookDBDeleted, object: nil, userInfo: ["urls": [book]])
        NotificationCenter.default.post(name: .bookDBSortDone, object: nil)
        NotificationCenter.default.post(name: .bookStateUpdated, object: nil, userInfo: ["url": book])
        storage.setStorageLocation(.local)

        let expectedEvents: Set<String> = [
            "syncing", "synced", "changed:0", "deleted:1", "sorted", "playback:novel.mp3", "storage",
        ]
        for _ in 0..<100 where !expectedEvents.isSubset(of: Set(recorder.events)) {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(expectedEvents.isSubset(of: Set(recorder.events)))

        observer.cancel()
        let eventCountAfterCancellation = recorder.events.count
        NotificationCenter.default.post(name: .bookDBUpdated, object: nil)
        storage.resetStorageLocation()
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(recorder.events.count == eventCountAfterCancellation)
        provider.shutdown()
        try? FileManager.default.removeItem(at: root)
    }

    @Test
    func pluginLifecycleSkipsRegistrationUntilStorageIsAvailable() async throws {
        let kernel = CisumKernelContainer()
        let plugin = BookDBDataPlugin()

        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)
        #expect(kernel.resolveProvider(BookDatabaseProviding.self) == nil)

        try await plugin.onEnable(kernel: kernel)
        #expect(kernel.resolveProvider(BookDatabaseProviding.self) == nil)

        try await plugin.onDisable(kernel: kernel)
        try await plugin.onShutdown(kernel: kernel)
        #expect(kernel.resolveProvider(BookDatabaseProviding.self) == nil)
    }

    @Test
    func pluginLifecycleRegistersAndRemovesProviderWhenStorageIsAvailable() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookDatabasePluginLifecycle-\(UUID().uuidString)", isDirectory: true)
        let storageRoot = root.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = BookTestStorageProvider(storageRoot: storageRoot, databaseRoot: root.appendingPathComponent("Database"))
        let kernel = CisumKernelContainer()
        try kernel.registerStorage(storage)
        let plugin = BookDBDataPlugin()

        try await plugin.onBoot(kernel: kernel)
        let initialProvider = try #require(kernel.resolveProvider(BookDatabaseProviding.self))
        try await plugin.onReady(kernel: kernel)
        #expect(kernel.resolveProvider(BookDatabaseProviding.self) as AnyObject? === initialProvider)
        #expect(storage.activeObserverCount == 1)

        try await plugin.onDisable(kernel: kernel)
        #expect(kernel.resolveProvider(BookDatabaseProviding.self) == nil)
        #expect(storage.activeObserverCount == 0)

        try await plugin.onEnable(kernel: kernel)
        #expect(kernel.resolveProvider(BookDatabaseProviding.self) != nil)
        #expect(storage.activeObserverCount == 1)

        try await plugin.onShutdown(kernel: kernel)
        #expect(kernel.resolveProvider(BookDatabaseProviding.self) == nil)
        #expect(storage.activeObserverCount == 0)
    }

    @Test
    func failedProviderRegistrationDoesNotStealOrLeakExistingProvider() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookDatabaseDuplicateProvider-\(UUID().uuidString)", isDirectory: true)
        let storageRoot = root.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = BookTestStorageProvider(storageRoot: storageRoot, databaseRoot: root.appendingPathComponent("Database"))
        let existingProvider = BookDatabaseProvider(storage: storage)
        let kernel = CisumKernelContainer()
        try kernel.registerStorage(storage)
        try kernel.registerProvider(BookDatabaseProviding.self, existingProvider)
        let plugin = BookDBDataPlugin()

        await #expect(throws: CisumKernelError.self) {
            try await plugin.onBoot(kernel: kernel)
        }
        #expect(storage.activeObserverCount == 1)

        try await plugin.onShutdown(kernel: kernel)
        #expect(kernel.resolveProvider(BookDatabaseProviding.self) as AnyObject? === existingProvider)
        #expect(storage.activeObserverCount == 1)

        kernel.unregisterProvider(BookDatabaseProviding.self)
        existingProvider.shutdown()
        #expect(storage.activeObserverCount == 0)
    }
}
