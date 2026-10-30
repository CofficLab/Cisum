import ProviderAudioLibrary
import ProviderScene
import ProviderPlayback
import CisumProviderStorage
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
private final class PlaybackProbe: AudioLibraryPlaybackCapability {
    var currentURL: URL?

    var playedURLs: [URL] = []
    /// 被「加载但未自动播放」的资源。
    var loadedURLs: [URL] = []
    var resetCount = 0
    private var observers: [UUID: (AudioLibraryPlaybackEvent) -> Void] = [:]

    func emitAssetChanged(_ url: URL?) {
        let event = AudioLibraryPlaybackEvent.assetChanged(url: url)
        for observer in observers.values { observer(event) }
    }

    func play(_ url: URL) async { playedURLs.append(url) }
    func load(_ url: URL) async { loadedURLs.append(url) }
    func reset() async { resetCount += 1 }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioLibraryPlaybackEvent) -> Void
    ) -> any AudioLibraryPlaybackObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProbePlaybackHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class ProbePlaybackHandle: AudioLibraryPlaybackObserverHandle {
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
private final class AudioLibraryProbe: AudioLibraryCapability {
    var audioDisk: URL?
    var supportedExtensions: [String] = ["mp3"]
    var isAvailable: Bool = true
    var totalCountValue = 0
    /// 仓库中的文件列表（按稳定顺序）。
    var urlsValue: [URL] = []
    private var observers: [UUID: (AudioLibraryEvent) -> Void] = [:]

    func totalCount() async -> Int { totalCountValue }
    func allURLs(reason: String) async -> [URL] { urlsValue }
    func urls(offset: Int, limit: Int, reason: String) async -> [URL] {
        guard offset < urlsValue.count else { return [] }
        let upper = min(offset + limit, urlsValue.count)
        return Array(urlsValue[offset ..< upper])
    }
    func delete(urls: [URL], verbose: Bool) async throws {}
    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {}

    func emit(_ event: AudioLibraryEvent) {
        for observer in observers.values { observer(event) }
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioLibraryEvent) -> Void
    ) -> any AudioLibraryObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProbeLibraryHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class ProbeLibraryHandle: AudioLibraryObserverHandle {
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
private final class SceneProbe: MusicLibrarySceneCapability {
    var currentScene: AppScene?
    private var observers: [UUID: (MusicLibrarySceneEvent) -> Void] = [:]

    func setCurrentScene(_ scene: AppScene) {
        currentScene = scene
        let event = MusicLibrarySceneEvent.selectionChanged(scene: scene)
        for observer in observers.values { observer(event) }
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (MusicLibrarySceneEvent) -> Void
    ) -> any MusicLibrarySceneObserverHandle {
        let id = UUID()
        observers[id] = callback
        return SceneProbeHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class SceneProbeHandle: MusicLibrarySceneObserverHandle {
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
        let observer = AudioDBSceneObserver(scene: MusicLibrarySceneCapabilityAdapter(scene: nil), sceneState: state)
        observer.cancel()
        #expect(!state.isMusicScene)
    }
}

// MARK: - AudioDBDependencies

@MainActor
struct AudioDBDependenciesTests {
    @Test
    func emptyDefaultsAreSafe() {
        let empty = AudioDBDependencies.empty
        #expect(empty.library.isAvailable == false)
        #expect(empty.audioDisk() == nil)
        #expect(empty.supportedExtensions.isEmpty)
        #expect(empty.isDesktop)
        #expect(!empty.isNotDesktop)
    }

    @Test
    func initStoresAllFields() {
        let binding = Binding(get: { false }, set: { _ in })
        let capturedDisk: URL? = nil

        let deps = AudioDBDependencies(
            library: AudioLibraryCapabilityAdapter(resolve: { nil }),
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
        AudioListViewModel(library: AudioLibraryCapabilityAdapter(resolve: { nil }))
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

@MainActor
struct AudioListRepositoryPresentationTests {
    @Test
    func hidesEmptyRepositoryStateUntilAnAvailableRepositoryLoadsSuccessfully() async throws {
        let unavailableLibrary = AudioLibraryProbe()
        unavailableLibrary.isAvailable = false
        let unavailableList = AudioListViewModel(library: unavailableLibrary)
        unavailableList.handleOnAppear()
        try await waitForInitialListLoad(unavailableList)

        #expect(!unavailableList.isConfirmedRepositoryEmpty)

        let availableLibrary = AudioLibraryProbe()
        let emptyList = AudioListViewModel(library: availableLibrary)
        emptyList.handleOnAppear()
        try await waitForInitialListLoad(emptyList)

        #expect(emptyList.isConfirmedRepositoryEmpty)
    }

    private func waitForInitialListLoad(_ viewModel: AudioListViewModel) async throws {
        for _ in 0 ..< 100 {
            if !viewModel.isLoading { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Audio list did not finish its initial load in time")
    }
}

// MARK: - AudioDatabaseObserver

@MainActor
struct AudioDatabaseObserverTests {
    @Test
    func storageAvailabilityChangeRetriesPreviouslyUnavailableRepository() async throws {
        let library = AudioLibraryProbe()
        library.isAvailable = false
        let list = AudioListViewModel(library: library)
        let observer = AudioDatabaseObserver(list: list, root: nil, db: nil, library: library)
        defer { observer.cancel() }

        list.handleOnAppear()
        try await Task.sleep(for: .milliseconds(20))
        #expect(!list.isConfirmedRepositoryEmpty)

        library.isAvailable = true
        library.emit(.repositoryAvailabilityChanged)
        try await waitForListLoad(list)

        #expect(list.isConfirmedRepositoryEmpty)
    }

    @Test
    func dbEventsForwardToSortingAndRootViewModels() async throws {
        let library = AudioLibraryProbe()
        let list = AudioListViewModel(library: library)
        var showDBCount = 0
        let root = AudioDBRootViewModel(library: library, showDBView: { showDBCount += 1 })
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
        library.emit(.synced)
        try await Task.sleep(for: .milliseconds(100))
        #expect(showDBCount == 1)

        // deleted 事件转发不崩溃。
        library.emit(.deleted(urls: [URL(fileURLWithPath: "/tmp/a.mp3")]))
        #expect(showDBCount == 1)
    }

    @Test
    func cancellingObserverStopsForwarding() {
        let library = AudioLibraryProbe()
        let list = AudioListViewModel(library: library)
        let root = AudioDBRootViewModel(library: library, showDBView: {})
        let db = AudioDBViewModel()

        let observer = AudioDatabaseObserver(list: list, root: root, db: db, library: library)
        observer.cancel()

        library.emit(.sorting)
        #expect(!db.isSorting)
    }

    private func waitForListLoad(_ viewModel: AudioListViewModel) async throws {
        for _ in 0 ..< 100 {
            if !viewModel.isLoading { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Audio list did not finish its repository-availability refresh in time")
    }
}

// MARK: - 未选择文件时自动选中第一项

/// 仓库有文件、用户尚未选择任何文件时，列表应自动选中第一项。
///
/// 判据是「用户没有选择过任何文件」：已经存在选中项时不得被覆盖。
@MainActor
struct AudioListAutoSelectionTests {
    @Test
    func selectsFirstFileWhenRepositoryHasFilesAndNothingIsSelected() async throws {
        let library = AudioLibraryProbe()
        let first = URL(fileURLWithPath: "/tmp/cisum-auto-first.mp3")
        let second = URL(fileURLWithPath: "/tmp/cisum-auto-second.mp3")
        library.urlsValue = [first, second]
        library.totalCountValue = 2

        let list = AudioListViewModel(library: library)
        list.handleOnAppear()
        try await waitForInitialLoad(list)

        #expect(list.selection == first)
    }

    /// 自动选中必须让**播放器**持有该文件，否则播放区（封面 + 标题）仍是空的。
    ///
    /// 封面与标题的数据源是播放器的 `currentURL`，不是列表的 `selection`：
    /// 只改 `selection` 的话，`PlaybackHeroViewModel.isHeroVisible` 仍为 false，
    /// 封面区高度归零，用户看到的是一片空白（而非首曲信息）。
    @Test
    func loadsFirstFileIntoPlayerSoHeroHasACurrentTrack() async throws {
        let library = AudioLibraryProbe()
        let first = URL(fileURLWithPath: "/tmp/cisum-hero-first.mp3")
        let second = URL(fileURLWithPath: "/tmp/cisum-hero-second.mp3")
        library.urlsValue = [first, second]
        library.totalCountValue = 2

        let playback = PlaybackProbe()
        let list = AudioListViewModel(library: library, playback: playback)
        list.handleOnAppear()
        try await waitForInitialLoad(list)
        try await waitForPlaybackLoad(playback)

        #expect(list.selection == first)
        #expect(playback.loadedURLs == [first], "首曲必须被加载到播放器，封面区才有内容")
        #expect(playback.playedURLs.isEmpty, "兜底加载不应自动播放——不替用户决定开始出声")
    }

    /// 已有当前曲目时不得再兜底加载：用户意图优先。
    @Test
    func doesNotLoadAnythingWhenPlayerAlreadyHasACurrentTrack() async throws {
        let library = AudioLibraryProbe()
        let first = URL(fileURLWithPath: "/tmp/cisum-hero-keep-first.mp3")
        let second = URL(fileURLWithPath: "/tmp/cisum-hero-keep-second.mp3")
        library.urlsValue = [first, second]
        library.totalCountValue = 2

        let playback = PlaybackProbe()
        let list = AudioListViewModel(library: library, playback: playback)
        // 模拟「播放器已有当前曲目」：走正式入口，让 currentAsset 与
        // selection 同步到播放器的实际状态。
        list.applyExternalPlayback(url: second)
        list.handleOnAppear()
        try await waitForInitialLoad(list)
        try await waitForPlaybackLoad(playback)

        #expect(playback.loadedURLs.isEmpty, "已有当前曲目时不应覆盖用户的播放状态")
        #expect(list.selection == second)
    }

    @Test
    func doesNotSelectAnythingWhenRepositoryIsEmpty() async throws {
        let library = AudioLibraryProbe()
        library.urlsValue = []
        library.totalCountValue = 0

        let list = AudioListViewModel(library: library)
        list.handleOnAppear()
        try await waitForInitialLoad(list)

        #expect(list.selection == nil)
    }

    @Test
    func keepsExistingSelectionInsteadOfOverwritingItWithFirstFile() async throws {
        let library = AudioLibraryProbe()
        let first = URL(fileURLWithPath: "/tmp/cisum-auto-keep-first.mp3")
        let second = URL(fileURLWithPath: "/tmp/cisum-auto-keep-second.mp3")
        library.urlsValue = [first, second]
        library.totalCountValue = 2

        let list = AudioListViewModel(library: library)
        list.applyExternalPlayback(url: second)
        list.handleOnAppear()
        try await waitForInitialLoad(list)

        #expect(list.selection == second)
    }

    private func waitForInitialLoad(_ viewModel: AudioListViewModel) async throws {
        for _ in 0 ..< 100 {
            if !viewModel.isLoading { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Audio list did not finish its initial load in time")
    }

    /// 兜底加载在 `Task` 中执行，等待它落地。
    private func waitForPlaybackLoad(_ probe: PlaybackProbe) async throws {
        for _ in 0 ..< 100 where probe.loadedURLs.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
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

// MARK: - 下载进度与数据库刷新的解耦

/// 回归：iCloud 下载期间，进度环曾反复「闪一下进度 → 退回未下载图标」。
///
/// 成因是一条真实的因果链：
/// `NSMetadataQuery` 把每次下载百分比推送都算作目录变更 → 库同步发出
/// `synced`/`updated` → `AudioDatabaseObserver` 转发 → ViewModel 刷新当前页 →
/// 旧实现在这里 `downloadStore.removeAll()`，把刚播报的进度抹掉。
///
/// 这里锁定的是修复后的所有权约定：**数据库刷新不得影响下载进度**。
@MainActor
struct CloudDownloadProgressSurvivesDatabaseRefreshTests {
    private func tempURL(_ name: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cisum-dl-\(name)")
    }

    /// 核心回归：`synced` / `updated` 事件不得抹掉进行中的下载进度。
    @Test
    func databaseSyncEventsDoNotClearInFlightDownloadProgress() async throws {
        let library = AudioLibraryProbe()
        let list = AudioListViewModel(library: library)
        let observer = AudioDatabaseObserver(list: list, root: nil, db: nil, library: library)
        defer { observer.cancel() }

        let url = tempURL("in-flight.wav")
        list.applyDownloadProgress(url: url, progress: 0.42)

        // 下载期间，`NSMetadataQuery` 会因百分比变化反复触发目录同步事件。
        library.emit(.syncing)
        library.emit(.synced)
        try await Task.sleep(for: .milliseconds(50))
        library.emit(.syncing)
        library.emit(.updated)
        try await Task.sleep(for: .milliseconds(50))

        // 进度必须原封不动：这是「闪一下」的判据。
        #expect(list.downloadStore.progress(for: url) { 0 } == 0.42)
        #expect(list.downloadStore.hasActiveDownloads)
    }

    /// 列表重载（当前页刷新）同样不得清空进度。
    @Test
    func currentPageReloadKeepsDownloadProgress() async throws {
        let library = AudioLibraryProbe()
        let list = AudioListViewModel(library: library)
        let observer = AudioDatabaseObserver(list: list, root: nil, db: nil, library: library)
        defer { observer.cancel() }

        let url = tempURL("reload.wav")
        list.applyDownloadProgress(url: url, progress: 0.77)

        list.handleDBSynced()
        try await Task.sleep(for: .milliseconds(80))

        #expect(list.downloadStore.progress(for: url) { 0 } == 0.77)
    }

    /// 反复刷新也不应退化——旧实现每刷新一次就丢一次。
    @Test
    func repeatedRefreshesNeverErodeProgress() async throws {
        let library = AudioLibraryProbe()
        let list = AudioListViewModel(library: library)
        let observer = AudioDatabaseObserver(list: list, root: nil, db: nil, library: library)
        defer { observer.cancel() }

        let url = tempURL("erode.wav")
        list.applyDownloadProgress(url: url, progress: 0.3)

        for _ in 0..<10 {
            library.emit(.updated)
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(list.downloadStore.progress(for: url) { 0 } == 0.3)
    }

    /// 删除事件仍然必须清理进度——所有权约定要双向成立，不能矫枉过正。
    @Test
    func deletionStillClearsProgress() {
        let library = AudioLibraryProbe()
        let list = AudioListViewModel(library: library)
        let observer = AudioDatabaseObserver(list: list, root: nil, db: nil, library: library)
        defer { observer.cancel() }

        let deleted = tempURL("deleted.wav")
        list.applyDownloadProgress(url: deleted, progress: 0.5)
        #expect(list.downloadStore.hasActiveDownloads)

        library.emit(.deleted(urls: [deleted]))

        #expect(list.downloadStore.progress(for: deleted) { 0 } == 0)
        #expect(!list.downloadStore.hasActiveDownloads)
    }

    /// 存储位置切换会让文件身份失效，此时全量清空仍是正确的。
    @Test
    func repositoryAvailabilityChangeResetsProgress() async throws {
        let library = AudioLibraryProbe()
        let list = AudioListViewModel(library: library)
        let observer = AudioDatabaseObserver(list: list, root: nil, db: nil, library: library)
        defer { observer.cancel() }

        let url = tempURL("rehomed.wav")
        list.applyDownloadProgress(url: url, progress: 0.6)

        library.emit(.repositoryAvailabilityChanged)
        try await Task.sleep(for: .milliseconds(50))

        // 旧路径下的记录已指向不存在的对象，刷新时清空是预期行为。
        #expect(list.downloadStore.progress(for: url) { 0 } == 0)
    }
}
