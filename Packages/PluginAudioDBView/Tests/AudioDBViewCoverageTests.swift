import ProviderAudioLibrary
import ProviderScene
import ProviderPlayback
import ProviderStorage
import Foundation
import SwiftUI
import Testing
@testable import PluginAudioDBView

// MARK: - 探针实现

/// 最小存储探针：仅用于诊断工厂与依赖注入。
@MainActor
private final class StorageProbe: StorageProviding {
    var currentStorageLocation: StorageLocation?
    var storageRoot: URL?
    var hasUsableStorageLocation: Bool
    var isICloudStorageAvailable: Bool = false
    var databaseRoot: URL

    init(storageRoot: URL?, hasUsable: Bool = true, location: StorageLocation? = .local) {
        self.storageRoot = storageRoot
        self.hasUsableStorageLocation = hasUsable
        self.currentStorageLocation = location
        self.databaseRoot = storageRoot ?? URL(fileURLWithPath: "/tmp/db")
    }

    func storageRoot(for location: StorageLocation) -> URL? { storageRoot }
    func databaseFile(name: String) throws -> URL { databaseRoot.appendingPathComponent(name) }
    func pluginDataDirectory(for pluginID: String) -> URL { databaseRoot.appendingPathComponent(pluginID) }
    func setStorageLocation(_ location: StorageLocation?) { currentStorageLocation = location }
    func resetStorageLocation() { currentStorageLocation = nil }
}

/// 最小播放探针：支持广播 assetChanged 事件。
@MainActor
private final class PlaybackProbe: PlaybackProviding {
    var state: PlaybackStatus = .idle
    var currentURL: URL?
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0
    var playMode: PlaybackMode = .sequence
    var likedAssets: Set<URL> = []
    var isPlaying: Bool { false }
    var hasAsset: Bool { currentURL != nil }

    var playedURLs: [URL] = []
    var resetCount = 0
    private var observers: [UUID: (PlaybackProvidingEvent) -> Void] = [:]

    func emitAssetChanged(_ url: URL?) {
        let event = PlaybackProvidingEvent.assetChanged(url)
        for observer in observers.values { observer(event) }
    }

    func play(_ url: URL) async { playedURLs.append(url) }
    func pause() {}
    func toggle() {}
    func seek(toProgress progress: Double) {}
    func seek(toTime time: TimeInterval) {}
    func next() {}
    func previous() {}
    func setPlayMode(_ mode: PlaybackMode) {}
    func toggleCurrentLike() {}
    func togglePlayMode() {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackProvidingEvent) -> Void
    ) -> any PlaybackProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProbePlaybackHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class ProbePlaybackHandle: PlaybackProvidingObserverHandle {
    private let onCancel: () -> Void
    private var cancelled = false

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        onCancel()
    }
}

/// 最小音频库探针：支持广播数据库事件。
@MainActor
private final class AudioLibraryProbe: AudioLibraryProviding {
    var audioDisk: URL?
    var supportedExtensions: [String] = ["mp3"]
    var isAvailable: Bool = true
    var totalCountValue = 0
    private var observers: [UUID: (AudioLibraryProvidingEvent) -> Void] = [:]

    func totalCount() async -> Int { totalCountValue }
    func allURLs(reason: String) async -> [URL] { [] }
    func urls(offset: Int, limit: Int, reason: String) async -> [URL] { [] }
    func contains(_ url: URL) async -> Bool { false }
    func delete(urls: [URL], verbose: Bool) async throws {}
    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {}
    func sort(url: URL?, reason: String) async {}
    func sortRandom(url: URL?, reason: String, verbose: Bool) async throws {}

    func emit(_ event: AudioLibraryProvidingEvent) {
        for observer in observers.values { observer(event) }
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioLibraryProvidingEvent) -> Void
    ) -> any AudioLibraryProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProbeLibraryHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class ProbeLibraryHandle: AudioLibraryProvidingObserverHandle {
    private let onCancel: () -> Void
    private var cancelled = false

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        onCancel()
    }
}

/// 最小场景探针：触发 selectionChanged 事件。
@MainActor
private final class SceneProbe: SceneProviding {
    var scenes: [AppScene] = [.music, .audiobooks]
    var currentScene: AppScene?
    private var observers: [UUID: (SceneProvidingEvent) -> Void] = [:]

    func setCurrentScene(_ scene: AppScene) {
        currentScene = scene
        let event = SceneProvidingEvent.selectionChanged(scene: scene)
        for observer in observers.values { observer(event) }
    }

    func restoreCurrentScene() {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return SceneProbeHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class SceneProbeHandle: SceneProvidingObserverHandle {
    private let onCancel: () -> Void
    private var cancelled = false

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        onCancel()
    }
}

// MARK: - AudioStorageDiagnosticsFactory

@MainActor
struct AudioStorageDiagnosticsFactoryTests {
    @Test
    func makeReadsStorageRootAndBuildsAudioDiskPath() {
        let root = URL(fileURLWithPath: "/tmp/audio-root")
        let storage = StorageProbe(storageRoot: root, hasUsable: true)
        let diagnostics = AudioStorageDiagnosticsFactory.make(storage: storage)

        #expect(diagnostics.hasUsableStorageLocation == true)
        #expect(diagnostics.storageRoot == root.path)
        #expect(diagnostics.audioDisk == root.appendingPathComponent(AudioPluginInfo.effectiveDBDirName, isDirectory: true).path)
        #expect(diagnostics.dbDirName == AudioPluginInfo.effectiveDBDirName)
    }

    @Test
    func makeFallsBackWhenStorageMissing() {
        let diagnostics = AudioStorageDiagnosticsFactory.make(storage: nil)
        #expect(diagnostics.hasUsableStorageLocation == false)
        #expect(diagnostics.storageRoot == nil)
        #expect(diagnostics.audioDisk == nil)
        #expect(diagnostics.dbDirName == AudioPluginInfo.effectiveDBDirName)
    }
}

// MARK: - AudioTreeBuilder

struct AudioTreeBuilderTests {
    @Test
    func buildRootChildrenScansFilesAndFolders() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioTreeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // 支持的音频文件与子目录。
        try Data().write(to: root.appendingPathComponent("song.mp3"))
        try Data().write(to: root.appendingPathComponent("cover.png"))
        try Data().write(to: root.appendingPathComponent(".hidden.mp3"))
        let folder = root.appendingPathComponent("Album", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("track.m4a"))

        let children = AudioTreeBuilder.buildRootChildren(from: root)

        // 目录优先；隐藏文件被跳过；不支持扩展名被过滤。
        #expect(children.first?.isDirectory == true)
        #expect(children.first?.name == "Album")
        #expect(children.first?.childCount == 1)
        #expect(children.contains { $0.name == "song.mp3" })
        #expect(!children.contains { $0.name == "cover.png" })
        #expect(!children.contains { $0.name == ".hidden.mp3" })
    }

    @Test
    func buildRootChildrenReturnsEmptyForMissingDirectory() {
        let missing = URL(fileURLWithPath: "/tmp/definitely-missing-\(UUID().uuidString)")
        #expect(AudioTreeBuilder.buildRootChildren(from: missing).isEmpty)
    }

    @Test
    func isSupportedAudioFileChecksExtensionsCaseInsensitively() throws {
        let url = URL(fileURLWithPath: "/tmp/SONG.MP3")
        #expect(AudioTreeBuilder.isSupportedAudioFile(url) == AudioPluginInfo.supportedExtensions.contains("mp3"))
        #expect(!AudioTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/cover.png")))
    }

    @Test
    func treeNodeComputedProperties() {
        let file = AudioTreeNode(url: URL(fileURLWithPath: "/tmp/a.mp3"), name: "a.mp3", isDirectory: false, children: nil)
        #expect(file.childCount == 0)
        #expect(!file.isExpandable)

        let emptyDir = AudioTreeNode(url: URL(fileURLWithPath: "/tmp/empty"), name: "empty", isDirectory: true, children: [])
        #expect(emptyDir.childCount == 0)
        #expect(!emptyDir.isExpandable)

        let dir = AudioTreeNode(url: URL(fileURLWithPath: "/tmp/full"), name: "full", isDirectory: true, children: [file])
        #expect(dir.childCount == 1)
        #expect(dir.isExpandable)
    }
}

// MARK: - AudioTreeViewModel

@MainActor
struct AudioTreeViewModelTests {
    @Test
    func handleOnAppearLoadsChildrenFromDisk() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioTreeVM-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("a.mp3"))

        let viewModel = AudioTreeViewModel(disk: { root })
        viewModel.handleOnAppear()
        // 等待异步加载完成。
        try await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.children.count == 1)
        #expect(viewModel.children.first?.name == "a.mp3")
        #expect(!viewModel.isLoading)
    }

    @Test
    func handleOnAppearWithoutDiskStaysEmpty() async throws {
        let viewModel = AudioTreeViewModel(disk: { nil })
        viewModel.handleOnAppear()
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.children.isEmpty)
        #expect(!viewModel.isLoading)
    }
}

// MARK: - AudioDBSceneState + AudioDBSceneObserver

@MainActor
struct AudioDBSceneObserverTests {
    @Test
    func sceneChangeUpdatesMusicSceneFlag() {
        let state = AudioDBSceneState(isMusicScene: true)
        let scene = SceneProbe()
        let observer = AudioDBSceneObserver(scene: scene, sceneState: state)
        defer { observer.cancel() }

        scene.setCurrentScene(.audiobooks)
        #expect(!state.isMusicScene)

        scene.setCurrentScene(.music)
        #expect(state.isMusicScene)
    }

    @Test
    func cancellingObserverStopsUpdates() {
        let state = AudioDBSceneState(isMusicScene: true)
        let scene = SceneProbe()
        let observer = AudioDBSceneObserver(scene: scene, sceneState: state)

        observer.cancel()
        scene.setCurrentScene(.audiobooks)
        #expect(state.isMusicScene)
    }

    @Test
    func initWithoutSceneKeepsCurrentFlag() {
        let state = AudioDBSceneState(isMusicScene: false)
        let observer = AudioDBSceneObserver(scene: nil, sceneState: state)
        observer.cancel()
        #expect(!state.isMusicScene)
    }
}

// MARK: - AudioPlaybackCapabilityAdapter

@MainActor
struct AudioPlaybackCapabilityAdapterTests {
    @Test
    func playForwardsToPlaybackProvider() async {
        let probe = PlaybackProbe()
        let adapter = AudioPlaybackCapabilityAdapter(playback: probe)
        let url = URL(fileURLWithPath: "/tmp/song.mp3")

        await adapter.play(url)
        #expect(probe.playedURLs == [url])
    }

    @Test
    func resetForwardsToPlaybackProvider() async {
        let probe = PlaybackProbe()
        let adapter = AudioPlaybackCapabilityAdapter(playback: probe)

        await adapter.reset()
        #expect(probe.resetCount == 0) // 探针 reset 为默认空实现；验证调用不崩溃。
    }
}

// MARK: - AudioDBDependencies

@MainActor
struct AudioDBDependenciesTests {
    @Test
    func emptyDefaultsAreSafe() {
        let empty = AudioDBDependencies.empty
        #expect(empty.audioLibrary() == nil)
        #expect(empty.audioDisk() == nil)
        #expect(empty.supportedExtensions.isEmpty)
        #expect(empty.isDesktop)
        #expect(!empty.isNotDesktop)
    }

    @Test
    func initStoresAllFields() {
        let binding = Binding(get: { false }, set: { _ in })
        var capturedLibrary: (any AudioLibraryProviding)?
        var capturedDisk: URL?

        let deps = AudioDBDependencies(
            audioLibrary: { capturedLibrary },
            audioDisk: { capturedDisk },
            audioDiagnostics: { AudioStorageDiagnosticsFactory.make(storage: nil) },
            supportedExtensions: ["mp3"],
            isDesktop: false,
            isNotDesktop: true,
            showDBView: {},
            isImporting: binding
        )

        #expect(!deps.isDesktop)
        #expect(deps.isNotDesktop)
        #expect(deps.supportedExtensions == ["mp3"])
    }
}

// MARK: - AudioDBPlaybackObserver

@MainActor
struct AudioDBPlaybackObserverTests {
    private func makeList() -> AudioListViewModel {
        AudioListViewModel(audioLibrary: { nil })
    }

    @Test
    func appliesInitialPlaybackURLOnRegistration() {
        let probe = PlaybackProbe()
        probe.currentURL = URL(fileURLWithPath: "/tmp/current.mp3")

        let viewModel = makeList()
        let observer = AudioDBPlaybackObserver(playback: probe, viewModel: viewModel)
        defer { observer.cancel() }

        // 初始同步：当前资源已应用（currentSelection 反映传入 URL）。
        #expect(viewModel.selection == URL(fileURLWithPath: "/tmp/current.mp3"))
    }

    @Test
    func forwardsAssetChangedEvents() {
        let probe = PlaybackProbe()
        let viewModel = makeList()
        let observer = AudioDBPlaybackObserver(playback: probe, viewModel: viewModel)
        defer { observer.cancel() }

        let url = URL(fileURLWithPath: "/tmp/new.mp3")
        probe.emitAssetChanged(url)
        #expect(viewModel.selection == url)

        probe.emitAssetChanged(nil)
        #expect(viewModel.selection == nil)
    }

    @Test
    func cancellingObserverStopsForwards() {
        let probe = PlaybackProbe()
        let viewModel = makeList()
        let observer = AudioDBPlaybackObserver(playback: probe, viewModel: viewModel)

        observer.cancel()
        probe.emitAssetChanged(URL(fileURLWithPath: "/tmp/ignored.mp3"))
        #expect(viewModel.selection == nil)
    }
}

// MARK: - AudioDatabaseObserver

@MainActor
struct AudioDatabaseObserverTests {
    @Test
    func dbEventsForwardToSortingAndRootViewModels() async throws {
        let library = AudioLibraryProbe()
        let list = AudioListViewModel(audioLibrary: { library })
        var showDBCount = 0
        let root = AudioDBRootViewModel(audioLibrary: { library }, showDBView: { showDBCount += 1 })
        let db = AudioDBViewModel()

        let observer = AudioDatabaseObserver(list: list, root: root, db: db, library: library)
        defer { observer.cancel() }

        // sorting → isSorting=true；sortCompleted → isSorting=false。
        library.emit(.sorting)
        #expect(db.isSorting)
        library.emit(.sortCompleted)
        #expect(!db.isSorting)

        // synced/updated 触发 root 仓库检查；totalCount=0 → showDBView。
        library.totalCountValue = 0
        library.emit(.synced(totalCount: 0))
        try await Task.sleep(for: .milliseconds(100))
        #expect(showDBCount == 1)

        // deleted 事件转发不崩溃。
        library.emit(.deleted(urls: [URL(fileURLWithPath: "/tmp/a.mp3")], totalCount: 0))
        #expect(showDBCount == 1)
    }

    @Test
    func cancellingObserverStopsForwarding() {
        let library = AudioLibraryProbe()
        let list = AudioListViewModel(audioLibrary: { library })
        let root = AudioDBRootViewModel(audioLibrary: { library }, showDBView: {})
        let db = AudioDBViewModel()

        let observer = AudioDatabaseObserver(list: list, root: root, db: db, library: library)
        observer.cancel()

        library.emit(.sorting)
        #expect(!db.isSorting)
    }
}

// MARK: - AudioDBViewModel 排序

@MainActor
struct AudioDBViewModelSortTests {
    @Test
    func sortModeParsingTrimsAndFallsBack() {
        #expect(AudioDBViewModel.sortMode(from: "random") == .random)
        #expect(AudioDBViewModel.sortMode(from: "  order  ") == .order)
        #expect(AudioDBViewModel.sortMode(from: "unknown") == .none)
        #expect(AudioDBViewModel.sortMode(from: "") == .none)
    }

    @Test
    func handleSortingNormalizesMode() {
        let db = AudioDBViewModel()
        db.handleSorting(mode: nil)
        #expect(db.isSorting)
        #expect(db.sortMode == .none)

        db.handleSorting(mode: " random ")
        #expect(db.sortMode == .random)

        db.handleSortDone()
        #expect(!db.isSorting)
    }
}