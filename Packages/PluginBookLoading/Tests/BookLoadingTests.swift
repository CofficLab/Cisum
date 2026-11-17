import Combine
import Foundation
import KernelCore
import ProviderControlView
import ProviderDocsView
import ProviderPlayback
import ProviderPlugin
import ProviderScene
import Testing
@testable import PluginBookLoading

@MainActor
private final class PlaybackStub: PlaybackProviding {
    var state: PlaybackStatus = .idle
    var currentURL: URL?
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0
    var playMode: PlaybackMode = .sequence
    var likedAssets: Set<URL> = []
    var isPlaying: Bool { state.isPlaying }
    var hasAsset: Bool { currentURL != nil }

    private(set) var cancelCount = 0
    private(set) var retryCount = 0
    var observerCount: Int { observers.count }
    private var observers: [UUID: (PlaybackProvidingEvent) -> Void] = [:]

    func play(_ url: URL) async {}
    func pause() {}
    func toggle() {}
    func seek(toProgress progress: Double) {}
    func seek(toTime time: TimeInterval) {}
    func next() {}
    func previous() {}
    func setPlayMode(_ mode: PlaybackMode) {}
    func toggleCurrentLike() {}
    func togglePlayMode() {}
    func cancelPendingLoad() { cancelCount += 1 }
    func retryLastFailedLoad() async { retryCount += 1 }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackProvidingEvent) -> Void
    ) -> any PlaybackProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return PlaybackHandleBox { [weak self] in self?.observers.removeValue(forKey: id) }
    }

    func send(_ event: PlaybackProvidingEvent) {
        for callback in Array(observers.values) { callback(event) }
    }
}

@MainActor
private final class PlaybackHandleBox: PlaybackProvidingObserverHandle {
    private var onCancel: (() -> Void)?
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() {
        onCancel?()
        onCancel = nil
    }
}

@MainActor
private final class SceneStub: SceneProviding {
    let objectWillChange = ObservableObjectPublisher()
    let scenes = AppScene.allCases
    private(set) var currentScene: AppScene?
    private var observers: [UUID: (SceneProvidingEvent) -> Void] = [:]

    init(currentScene: AppScene?) {
        self.currentScene = currentScene
    }

    func setCurrentScene(_ scene: AppScene) {
        select(scene)
    }

    func restoreCurrentScene() {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return SceneHandleBox { [weak self] in self?.observers.removeValue(forKey: id) }
    }

    func select(_ scene: AppScene?) {
        currentScene = scene
        for callback in Array(observers.values) {
            callback(.selectionChanged(scene: scene))
        }
    }
}

@MainActor
private final class SceneHandleBox: SceneProvidingObserverHandle {
    private var onCancel: (() -> Void)?
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() {
        onCancel?()
        onCancel = nil
    }
}

@MainActor
private final class LibraryStub: BookLoadingLibraryCapability {
    var libraryDisk: URL?
    var playableExtensions: Set<String>
    var booksToReturn: [BookLoadingBookRef]

    init(
        libraryDisk: URL? = nil,
        playableExtensions: Set<String> = [],
        books: [BookLoadingBookRef] = []
    ) {
        self.libraryDisk = libraryDisk
        self.playableExtensions = playableExtensions
        booksToReturn = books
    }

    func books() async -> [BookLoadingBookRef] { booksToReturn }
}

@MainActor
struct BookLoadingTests {
    private let chapterURL = URL(fileURLWithPath: "/tmp/Chapter One.m4b")

    // MARK: - Mode derivation

    @Test
    func downloadingModeCarriesClampedProgress() {
        #expect(BookLoadingViewModel.mode(for: .loading(.downloading(0.42))) == .downloading(progress: 0.42))
        #expect(BookLoadingViewModel.mode(for: .loading(.downloading(1.5))) == .downloading(progress: 1))
        #expect(BookLoadingViewModel.mode(for: .loading(.downloading(0))) == .downloading(progress: nil))
        #expect(BookLoadingViewModel.mode(for: .loading(.downloading(-0.2))) == .downloading(progress: nil))
    }

    @Test
    func onlyICloudFailureBecomesVisible() {
        #expect(BookLoadingViewModel.mode(for: .failed(.iCloudDownloadFailed("timed out"))) == .failed(detail: "timed out"))
        #expect(BookLoadingViewModel.mode(for: .failed(.networkError("offline"))) == .hidden)
        #expect(BookLoadingViewModel.mode(for: .failed(.playbackError("decoder"))) == .hidden)
        #expect(BookLoadingViewModel.mode(for: .loading(.connecting)) == .hidden)
        #expect(BookLoadingViewModel.mode(for: .playing) == .hidden)
    }

    @Test
    func sceneGatesBannerToAudiobooks() {
        let downloading = PlaybackStatus.loading(.downloading(0.3))
        #expect(BookLoadingViewModel.resolvedMode(state: downloading, scene: .audiobooks) == .downloading(progress: 0.3))
        #expect(BookLoadingViewModel.resolvedMode(state: downloading, scene: .music) == .hidden)
        #expect(BookLoadingViewModel.resolvedMode(state: downloading, scene: nil) == .hidden)
    }

    @Test
    func subjectFallsBackToFileStemWithoutLibraryData() {
        let playback = PlaybackStub()
        playback.currentURL = chapterURL
        let viewModel = BookLoadingViewModel(
            playback: BookLoadingPlaybackCapabilityAdapter(playback: playback),
            scene: .audiobooks
        )
        #expect(viewModel.subject == BookLoadingSubject(chapterTitle: "Chapter One"))
        viewModel.stop()
    }

    // MARK: - Subject resolution

    private func makeBookFixture() throws -> (root: URL, book: URL, first: URL, second: URL, nested: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookLoadingTests-\(UUID().uuidString)", isDirectory: true)
        let book = root.appendingPathComponent("100部经典世界名著", isDirectory: true)
        let disc = book.appendingPathComponent("Disc 2", isDirectory: true)
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)

        let first = book.appendingPathComponent("01.mp3")
        let second = book.appendingPathComponent("02.mp3")
        let nested = disc.appendingPathComponent("01.mp3")
        for file in [first, second, nested] {
            try Data().write(to: file)
        }

        return (root, book, first, second, nested)
    }

    @Test
    func resolverNamesBookAndChapterPosition() throws {
        let fixture = try makeBookFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let books = [
            BookLoadingBookRef(
                url: fixture.book,
                title: "100部经典世界名著",
                childCount: 3,
                isCollection: true
            ),
        ]

        let subject = BookLoadingSubjectResolver.resolve(
            chapterURL: fixture.nested,
            books: books,
            libraryDisk: fixture.root,
            playableExtensions: ["mp3"]
        )

        #expect(subject.bookTitle == "100部经典世界名著")
        #expect(subject.chapterIndex == 3)
        #expect(subject.chapterCount == 3)
        #expect(subject.chapterTitle == "01")
    }

    @Test
    func resolverFallsBackToParentWhenLibraryHasNoRecord() throws {
        let fixture = try makeBookFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let subject = BookLoadingSubjectResolver.resolve(
            chapterURL: fixture.second,
            books: [],
            libraryDisk: fixture.root,
            playableExtensions: ["mp3"]
        )

        #expect(subject.bookTitle == "100部经典世界名著")
        #expect(subject.chapterIndex == 2)
        #expect(subject.chapterCount == 3)
    }

    @Test
    func resolverTreatsTopLevelFileAsWholeBook() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookLoadingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let single = root.appendingPathComponent("Single Book.m4b")
        try Data().write(to: single)

        let subject = BookLoadingSubjectResolver.resolve(
            chapterURL: single,
            books: [],
            libraryDisk: root,
            playableExtensions: ["m4b"]
        )

        #expect(subject.bookTitle == "Single Book")
        #expect(subject.chapterIndex == nil)
        #expect(subject.chapterCount == nil)
    }

    @Test
    func resolverKeepsChapterTitleWithoutLibraryContext() throws {
        let fixture = try makeBookFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let subject = BookLoadingSubjectResolver.resolve(
            chapterURL: fixture.nested,
            books: [],
            libraryDisk: nil,
            playableExtensions: []
        )

        #expect(subject.bookTitle.isEmpty)
        #expect(subject.chapterTitle == "01")
        #expect(subject.chapterIndex == nil)
    }

    // MARK: - ViewModel

    @Test
    func viewModelFollowsSceneAndPlaybackChanges() {
        let playback = PlaybackStub()
        playback.state = .loading(.downloading(0.5))
        let capability = BookLoadingPlaybackCapabilityAdapter(playback: playback)
        let viewModel = BookLoadingViewModel(playback: capability, scene: .audiobooks)
        #expect(viewModel.mode == .downloading(progress: 0.5))

        viewModel.handleStateChanged(.loading(.downloading(0.5)))
        #expect(viewModel.mode == .downloading(progress: 0.5))

        // 离开有声书场景只收起横幅，不改变播放状态。
        viewModel.handleSceneChanged(.music)
        #expect(viewModel.mode == .hidden)
        #expect(playback.cancelCount == 0)

        viewModel.handleSceneChanged(.audiobooks)
        #expect(viewModel.mode == .downloading(progress: 0.5))

        viewModel.handleStateChanged(.failed(.iCloudDownloadFailed("denied")))
        #expect(viewModel.mode == .failed(detail: "denied"))

        viewModel.handleAssetChanged(chapterURL)
        #expect(viewModel.subject == BookLoadingSubject(chapterTitle: "Chapter One"))
        viewModel.stop()
    }

    @Test
    func viewModelForwardsCancelAndRetry() async {
        let playback = PlaybackStub()
        let capability = BookLoadingPlaybackCapabilityAdapter(playback: playback)
        let viewModel = BookLoadingViewModel(playback: capability, scene: .audiobooks)

        viewModel.cancel()
        #expect(playback.cancelCount == 1)

        viewModel.retry()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(playback.retryCount == 1)
    }

    @Test
    func viewModelResolvesBookContextFromLibrary() async throws {
        let fixture = try makeBookFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let playback = PlaybackStub()
        playback.currentURL = fixture.nested
        let library = LibraryStub(
            libraryDisk: fixture.root,
            playableExtensions: ["mp3"],
            books: [
                BookLoadingBookRef(
                    url: fixture.book,
                    title: "100部经典世界名著",
                    childCount: 3,
                    isCollection: true
                ),
            ]
        )
        let viewModel = BookLoadingViewModel(
            playback: BookLoadingPlaybackCapabilityAdapter(playback: playback),
            scene: .audiobooks,
            library: library
        )

        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, viewModel.subject.bookTitle.isEmpty {
            try? await Task.sleep(for: .milliseconds(20))
        }

        #expect(viewModel.subject.bookTitle == "100部经典世界名著")
        #expect(viewModel.subject.chapterIndex == 3)
        #expect(viewModel.subject.chapterCount == 3)
        viewModel.stop()
    }

    @Test
    func bannerBodyBuildsForEveryMode() {
        let playback = PlaybackStub()
        let viewModel = BookLoadingViewModel(
            playback: BookLoadingPlaybackCapabilityAdapter(playback: playback),
            scene: .audiobooks
        )
        _ = BookLoadingBanner(viewModel: viewModel).body

        viewModel.handleStateChanged(.loading(.downloading(0.4)))
        _ = BookLoadingBanner(viewModel: viewModel).body

        viewModel.handleStateChanged(.loading(.downloading(0)))
        _ = BookLoadingBanner(viewModel: viewModel).body

        viewModel.handleStateChanged(.failed(.iCloudDownloadFailed("denied")))
        _ = BookLoadingBanner(viewModel: viewModel).body
    }

    // MARK: - Plugin lifecycle

    @Test
    func pluginActivatesSlotOnlyForAudiobookLoading() async throws {
        let kernel = KernelCoreContainer()
        let playback = PlaybackStub()
        let scene = SceneStub(currentScene: .audiobooks)
        let control = DefaultControlViewProvider()
        try kernel.registerProvider((any PlaybackProviding).self, playback)
        try kernel.registerProvider((any SceneProviding).self, scene)
        try kernel.registerProvider((any ControlViewProviding).self, control)

        let plugin = BookLoadingPlugin()
        try await plugin.onRegister(kernel: kernel)
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        let slot = try #require(control.loadingSlot)
        #expect(!slot.isActive)
        #expect(playback.observerCount == 1)

        playback.state = .loading(.downloading(0.2))
        playback.send(.stateChanged(.loading(.downloading(0.2))))
        #expect(slot.isActive)

        scene.select(.music)
        #expect(!slot.isActive)

        scene.select(.audiobooks)
        #expect(slot.isActive)

        playback.state = .paused
        playback.send(.stateChanged(.paused))
        #expect(!slot.isActive)

        playback.currentURL = chapterURL
        playback.state = .failed(.iCloudDownloadFailed("offline"))
        playback.send(.assetChanged(chapterURL))
        playback.send(.stateChanged(.failed(.iCloudDownloadFailed("offline"))))
        #expect(slot.isActive)

        try await plugin.onDisable(kernel: kernel)
        #expect(playback.observerCount == 0)
        #expect(control.loadingSlot == nil)
        #expect(!slot.isActive)

        try await plugin.onEnable(kernel: kernel)
        let restored = try #require(control.loadingSlot)
        #expect(restored.isActive)
        #expect(playback.observerCount == 1)

        try await plugin.onShutdownAsync(kernel: kernel)
        #expect(control.loadingSlot == nil)
        #expect(playback.observerCount == 0)
    }

    @Test
    func pluginStaysDormantWithoutControlProvider() async throws {
        let kernel = KernelCoreContainer()
        let playback = PlaybackStub()
        let scene = SceneStub(currentScene: .audiobooks)
        try kernel.registerProvider((any PlaybackProviding).self, playback)
        try kernel.registerProvider((any SceneProviding).self, scene)

        let plugin = BookLoadingPlugin()
        try await plugin.onRegister(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)
        try await plugin.onShutdownAsync(kernel: kernel)
        #expect(playback.observerCount == 0)
    }

    @Test
    func onRegisterPublishesAboutAndManualDocsEntries() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = BookLoadingPlugin()
        try await plugin.onRegister(kernel: kernel)

        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries.first?.id == plugin.id)
        #expect(docs.manualEntries.count == 1)
        #expect(docs.manualEntries.first?.id == plugin.id)
        #expect(
            String(describing: docs.aboutEntries[0].makeView())
                != String(describing: docs.manualEntries[0].makeView())
        )
    }
}
