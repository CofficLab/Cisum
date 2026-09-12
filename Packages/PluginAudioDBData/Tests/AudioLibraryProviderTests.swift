import Combine
import Foundation
import KernelCore
import ProviderAudioLibrary
import ProviderStorage
import Testing
@testable import PluginAudioDBData

@MainActor
private final class TestStorageObserverHandle: StorageProvidingObserverHandle {
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
private final class TestStorageProvider: @preconcurrency StorageProviding {
    let objectWillChange = ObservableObjectPublisher()

    private(set) var currentStorageLocation: StorageLocation?
    private(set) var storageRoot: URL?
    private var fallbackDatabaseRoot: URL
    private var observers: [UUID: (StorageProvidingEvent) -> Void] = [:]

    init(storageRoot: URL?, databaseRoot: URL) {
        self.storageRoot = storageRoot
        self.fallbackDatabaseRoot = databaseRoot
        currentStorageLocation = storageRoot == nil ? nil : .local
    }

    var hasUsableStorageLocation: Bool { storageRoot != nil }
    var isICloudStorageAvailable: Bool { false }

    var databaseRoot: URL {
        storageRoot?.appendingPathComponent("database", isDirectory: true) ?? fallbackDatabaseRoot
    }

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
        return TestStorageObserverHandle { [weak self] in
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
private func expectHostNotConfigured(_ operation: @MainActor () async throws -> Void) async {
    do {
        try await operation()
        Issue.record("Expected AudioPluginError.hostNotConfigured")
    } catch let error as AudioPluginError {
        #expect(error.localizedDescription == AudioPluginError.hostNotConfigured.localizedDescription)
    } catch {
        Issue.record("Unexpected error: \(error.localizedDescription)")
    }
}

@MainActor
private func waitForLibraryNotifications() async {
    try? await Task.sleep(nanoseconds: 30_000_000)
}

@Suite(.serialized)
@MainActor
struct AudioLibraryProviderTests {
    @Test
    func unavailableStorageReturnsEmptyResultsAndRejectsRequiredOperations() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioLibraryUnavailableTests-\(UUID().uuidString)", isDirectory: true)
        let storage = TestStorageProvider(storageRoot: nil, databaseRoot: root)
        let provider = AudioLibraryProvider(storage: storage)
        defer {
            provider.shutdown()
            try? FileManager.default.removeItem(at: root)
        }

        #expect(provider.audioDisk == nil)
        #expect(provider.supportedExtensions == AudioPluginInfo.supportedExtensions)
        #expect(!provider.isAvailable)
        let repository = await provider.currentRepository()
        #expect(repository.map { _ in true } == nil)
        #expect(await provider.totalCount() == 0)
        #expect(await provider.allURLs(reason: "test").isEmpty)
        #expect(await provider.urls(offset: 0, limit: 10, reason: "test").isEmpty)
        #expect(!(await provider.contains(URL(fileURLWithPath: "/missing.mp3"))))

        await expectHostNotConfigured {
            try await provider.delete(urls: [], verbose: false)
        }
        await expectHostNotConfigured {
            try await provider.sortRandom(url: nil, reason: "test", verbose: false)
        }
        await expectHostNotConfigured {
            _ = try await provider.nextURL(after: nil, verbose: false)
        }
        await expectHostNotConfigured {
            _ = try await provider.previousURL(before: nil, verbose: false)
        }
        await expectHostNotConfigured {
            _ = try await provider.firstURL()
        }
        await expectHostNotConfigured {
            _ = try await provider.lastURL()
        }
    }

    @Test
    func syncedLibrarySupportsQueriesNavigationSortingAndDeletion() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioLibraryProviderTests-\(UUID().uuidString)", isDirectory: true)
        let storageRoot = root.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = AudioLibraryProvider(
            storage: TestStorageProvider(storageRoot: storageRoot, databaseRoot: root.appendingPathComponent("Database"))
        )
        defer { provider.shutdown() }

        let disk = try #require(provider.audioDisk)
        let first = disk.appendingPathComponent("01.mp3")
        let second = disk.appendingPathComponent("02.mp3")
        let unsupported = disk.appendingPathComponent("notes.txt")
        try Data([0x01]).write(to: first)
        try Data([0x02]).write(to: second)
        try Data([0x03]).write(to: unsupported)

        var receivedEvents: [String] = []
        let observer = provider.addObserver { event in
            switch event {
            case .syncing: receivedEvents.append("syncing")
            case let .synced(totalCount): receivedEvents.append("synced:\(totalCount)")
            case let .updated(totalCount): receivedEvents.append("updated:\(totalCount)")
            case let .deleted(urls, totalCount): receivedEvents.append("deleted:\(urls.count):\(totalCount)")
            case .sorting: receivedEvents.append("sorting")
            case .sortCompleted: receivedEvents.append("sortCompleted")
            }
        }

        await provider.sync(urls: [second, unsupported, first], verbose: false, isFirst: true)
        await waitForLibraryNotifications()

        #expect(provider.audioDisk == disk)
        #expect(await provider.totalCount() == 2)
        #expect(await provider.allURLs(reason: "test") == [first, second])
        #expect(await provider.urls(offset: -1, limit: 1, reason: "test") == [first])
        #expect(await provider.urls(offset: 1, limit: 1, reason: "test") == [second])
        #expect(await provider.contains(first))
        #expect(!(await provider.contains(unsupported)))
        #expect(try await provider.firstURL() == first)
        #expect(try await provider.lastURL() == second)
        #expect(try await provider.nextURL(after: first, verbose: false) == second)
        #expect(try await provider.nextURL(after: second, verbose: false) == first)
        #expect(try await provider.previousURL(before: second, verbose: false) == first)
        #expect(try await provider.previousURL(before: first, verbose: false) == second)

        await provider.sort(url: second, reason: "test")
        await waitForLibraryNotifications()
        #expect(await provider.allURLs(reason: "sorted") == [second, first])
        #expect(receivedEvents.contains("synced:2"))
        #expect(receivedEvents.contains("sorting"))
        #expect(receivedEvents.contains("sortCompleted"))

        try await provider.sortRandom(url: second, reason: "test", verbose: false)
        #expect(await provider.allURLs(reason: "random") == [second, first])
        try await provider.delete(urls: [second], verbose: false)
        await waitForLibraryNotifications()

        #expect(!FileManager.default.fileExists(atPath: second.path))
        #expect(await provider.totalCount() == 1)
        #expect(await provider.allURLs(reason: "deleted") == [first])
        #expect(receivedEvents.contains("deleted:1:1"))
        observer.cancel()
    }

    @Test
    func storageAvailabilityChangesInvalidateRepositoryAndShutdownCancelsObserver() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioLibraryStorageObserverTests-\(UUID().uuidString)", isDirectory: true)
        let firstStorageRoot = root.appendingPathComponent("First", isDirectory: true)
        let secondStorageRoot = root.appendingPathComponent("Second", isDirectory: true)
        let storage = TestStorageProvider(storageRoot: firstStorageRoot, databaseRoot: root.appendingPathComponent("FallbackDB"))
        let provider = AudioLibraryProvider(storage: storage)
        defer {
            provider.shutdown()
            try? FileManager.default.removeItem(at: root)
        }

        let firstRepository = try #require(await provider.currentRepository())
        #expect(storage.activeObserverCount == 1)
        storage.updateStorageRoot(secondStorageRoot)
        let secondRepository = try #require(await provider.currentRepository())

        #expect(firstRepository !== secondRepository)
        #expect(await firstRepository.getStorageRoot() == firstStorageRoot.appendingPathComponent(AudioPluginInfo.effectiveDBDirName, isDirectory: true))
        #expect(await secondRepository.getStorageRoot() == secondStorageRoot.appendingPathComponent(AudioPluginInfo.effectiveDBDirName, isDirectory: true))

        provider.shutdown()
        #expect(storage.activeObserverCount == 0)
    }

    @Test
    func pluginLifecycleIndexesExistingAudioAndRegistersNavigation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioDBDataPluginLifecycle-\(UUID().uuidString)", isDirectory: true)
        let storageRoot = root.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = TestStorageProvider(storageRoot: storageRoot, databaseRoot: root.appendingPathComponent("Database"))
        let kernel = CisumKernelContainer()
        try kernel.registerStorage(storage)
        let plugin = AudioDBDataPlugin()
        let audioURL = storageRoot
            .appendingPathComponent(AudioPluginInfo.effectiveDBDirName, isDirectory: true)
            .appendingPathComponent("existing-track.mp3")
        try FileManager.default.createDirectory(
            at: audioURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0x01, 0x02]).write(to: audioURL)

        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)

        let library = try #require(kernel.audioLibrary)
        let navigation = try #require(kernel.audioTrackNavigation)
        for _ in 0..<100 where await library.totalCount() == 0 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(await library.totalCount() == 1)
        #expect(await library.contains(audioURL))
        let firstURL = try await navigation.firstURL()
        #expect(firstURL?.resolvingSymlinksInPath().standardizedFileURL.path == audioURL.resolvingSymlinksInPath().standardizedFileURL.path)
        #expect(storage.activeObserverCount == 2)

        let addedURL = audioURL.deletingLastPathComponent().appendingPathComponent("added-track.mp3")
        try Data([0x03, 0x04]).write(to: addedURL)
        for _ in 0..<100 where await library.totalCount() != 2 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(await library.contains(addedURL))
        #expect(await library.totalCount() == 2)

        try FileManager.default.removeItem(at: addedURL)
        for _ in 0..<100 where await library.totalCount() != 1 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(await library.totalCount() == 1)

        let switchedRoot = root.appendingPathComponent("SwitchedDocuments", isDirectory: true)
        let switchedAudioDisk = switchedRoot
            .appendingPathComponent(AudioPluginInfo.effectiveDBDirName, isDirectory: true)
        let switchedAudioURL = switchedAudioDisk.appendingPathComponent("switched-track.mp3")
        try FileManager.default.createDirectory(at: switchedAudioDisk, withIntermediateDirectories: true)
        try Data([0x05, 0x06]).write(to: switchedAudioURL)
        storage.updateStorageRoot(switchedRoot)

        for _ in 0..<100 {
            if await library.totalCount() == 1, await library.contains(switchedAudioURL) {
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(await library.totalCount() == 1)
        #expect(await library.contains(switchedAudioURL))

        try await plugin.onDisable(kernel: kernel)
        #expect(kernel.audioLibrary == nil)
        #expect(kernel.audioTrackNavigation == nil)
        #expect(storage.activeObserverCount == 0)

        try await plugin.onEnable(kernel: kernel)
        let reenabledNavigation = try #require(kernel.audioTrackNavigation)
        for _ in 0..<100 where await kernel.audioLibrary?.totalCount() == 0 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(await kernel.audioLibrary?.totalCount() == 1)

        storage.updateStorageRoot(nil)
        await #expect(throws: AudioPluginError.self) {
            try await reenabledNavigation.nextURL(after: nil, verbose: false)
        }
        await #expect(throws: AudioPluginError.self) {
            try await reenabledNavigation.previousURL(before: nil, verbose: false)
        }
        await #expect(throws: AudioPluginError.self) {
            try await reenabledNavigation.firstURL()
        }
        await #expect(throws: AudioPluginError.self) {
            try await reenabledNavigation.lastURL()
        }

        try await plugin.onShutdown(kernel: kernel)
        #expect(kernel.audioLibrary == nil)
        #expect(kernel.audioTrackNavigation == nil)
        #expect(storage.activeObserverCount == 0)
    }

    @Test
    func navigationProviderReportsUnavailableLibraryWhenStorageWasNotInjected() async throws {
        let kernel = CisumKernelContainer()
        let plugin = AudioDBDataPlugin()

        try await plugin.onReady(kernel: kernel)

        let navigation = try #require(kernel.audioTrackNavigation)
        await #expect(throws: AudioPluginError.self) {
            try await navigation.nextURL(after: nil, verbose: false)
        }

        try await plugin.onShutdown(kernel: kernel)
        #expect(kernel.audioTrackNavigation == nil)
        #expect(kernel.audioLibrary == nil)
    }
}
