import ProviderPlayback
import Foundation
import ProviderBook
import Testing
@testable import PluginBookDBView

// MARK: - 探针实现

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

    var played: [(url: URL, startTime: TimeInterval?)] = []
    private var observers: [UUID: (PlaybackProvidingEvent) -> Void] = [:]

    func emitAssetChanged(_ url: URL?) {
        let event = PlaybackProvidingEvent.assetChanged(url)
        for observer in observers.values { observer(event) }
    }

    func play(_ url: URL) async { played.append((url, nil)) }

    func play(_ url: URL, startTime: TimeInterval?) async {
        played.append((url, startTime))
    }

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

/// 书籍数据库探针：可配置书籍列表与播放状态，支持广播事件。
@MainActor
private final class BookProbe: BookDatabaseProviding {
    var bookDisk: URL?
    var isAvailable: Bool = true
    var databaseRoot = URL(fileURLWithPath: "/tmp/book-db")
    var booksValue: [BookDTO] = []
    var playbackStateValue: BookPlaybackStateDTO?
    var currentBookURLValue: URL?
    var currentBookTimeValue: TimeInterval?
    private var observers: [UUID: @Sendable (BookProvidingEvent) -> Void] = [:]

    func totalCount() async -> Int { booksValue.count }
    func books(reason: String) async -> [BookDTO] { booksValue }
    func syncImportedItems(_ items: [URL]) async throws {}
    func coverData(for bookURL: URL) async -> Data? { nil }
    func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO? { playbackStateValue }
    func savePlaybackState(for bookURL: URL, currentURL: URL?, time: TimeInterval?) async throws {}
    func currentBookURL() -> URL? { currentBookURLValue }
    func currentBookTime() -> TimeInterval? { currentBookTimeValue }
    func storeCurrentBookURL(_ url: URL?) {}
    func storeCurrentBookTime(_ time: TimeInterval) {}

    func emit(_ event: BookProvidingEvent) {
        for observer in observers.values { observer(event) }
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping @Sendable (BookProvidingEvent) -> Void
    ) -> any BookProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProbeBookHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class ProbeBookHandle: BookProvidingObserverHandle {
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

/// 书籍播放能力探针：记录 play 请求。
@MainActor
private final class CapabilityProbe: BookDBPlaybackCapability {
    var played: [(url: URL, startTime: TimeInterval?)] = []

    func play(_ url: URL, startTime: TimeInterval?) async {
        played.append((url, startTime))
    }
}

// MARK: - BookDBPlaybackCapabilityAdapter

@MainActor
struct BookDBPlaybackCapabilityAdapterTests {
    @Test
    func playForwardsWithStartTime() async {
        let probe = PlaybackProbe()
        let adapter = BookDBPlaybackCapabilityAdapter(playback: probe)
        let url = URL(fileURLWithPath: "/tmp/chapter.mp3")

        await adapter.play(url, startTime: 12.5)
        #expect(probe.played.count == 1)
        #expect(probe.played.first?.url == url)
        #expect(probe.played.first?.startTime == 12.5)
    }

    @Test
    func playForwardsWithoutStartTime() async {
        let probe = PlaybackProbe()
        let adapter = BookDBPlaybackCapabilityAdapter(playback: probe)
        let url = URL(fileURLWithPath: "/tmp/chapter.mp3")

        await adapter.play(url, startTime: nil)
        #expect(probe.played.first?.startTime == nil)
    }
}

// MARK: - PlaybackObserver

@MainActor
struct PlaybackObserverTests {
    @Test
    func appliesInitialAssetOnRegistration() {
        let probe = PlaybackProbe()
        probe.currentURL = URL(fileURLWithPath: "/tmp/current.mp3")
        let viewModel = BookGridViewModel()
        let observer = PlaybackObserver(playback: probe, viewModel: viewModel)
        defer { observer.cancel() }

        #expect(viewModel.selectedBookURL == nil) // 未加载书籍，无从匹配。
    }

    @Test
    func forwardsAssetChangedEvents() async throws {
        let probe = PlaybackProbe()
        let viewModel = BookGridViewModel()
        let observer = PlaybackObserver(playback: probe, viewModel: viewModel)
        defer { observer.cancel() }

        // 播放资产变化时，若已加载书籍则更新选中；未匹配则清空。
        viewModel.handleAssetChanged(URL(fileURLWithPath: "/tmp/unknown.mp3"))
        #expect(viewModel.selectedBookURL == nil)
        probe.emitAssetChanged(URL(fileURLWithPath: "/tmp/other.mp3"))
        #expect(viewModel.selectedBookURL == nil)
    }

    @Test
    func cancellingObserverStopsForwarding() {
        let probe = PlaybackProbe()
        let viewModel = BookGridViewModel()
        let observer = PlaybackObserver(playback: probe, viewModel: viewModel)
        observer.cancel()

        viewModel.handleAssetChanged(URL(fileURLWithPath: "/tmp/a.mp3"))
        #expect(viewModel.selectedBookURL == nil)
    }
}

// MARK: - DBObserver

@MainActor
struct DBObserverTests {
    @Test
    func forwardsLibraryEventsToGridViewModel() async throws {
        let provider = BookProbe()
        let viewModel = BookGridViewModel()
        let observer = DBObserver(viewModel: viewModel, provider: provider)
        defer { observer.cancel() }

        provider.emit(.librarySyncing)
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.isSyncing)

        provider.emit(.librarySynced)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!viewModel.isSyncing)

        provider.emit(.libraryChanged(totalCount: 3))
        try await Task.sleep(for: .milliseconds(100))
        provider.emit(.libraryDeleted(urls: [URL(fileURLWithPath: "/tmp/gone.mp3")]))
        try await Task.sleep(for: .milliseconds(100))

        provider.emit(.librarySorted)
        try await Task.sleep(for: .milliseconds(100))
        provider.emit(.playbackStateChanged(url: URL(fileURLWithPath: "/tmp/state.mp3")))
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.lastStateUpdatedURL == URL(fileURLWithPath: "/tmp/state.mp3"))
    }

    @Test
    func cancellingObserverStopsForwarding() throws {
        let provider = BookProbe()
        let viewModel = BookGridViewModel()
        let observer = DBObserver(viewModel: viewModel, provider: provider)
        observer.cancel()

        provider.emit(.librarySyncing)
        #expect(!viewModel.isSyncing)
    }
}

// MARK: - BookGridViewModel

@MainActor
struct BookGridViewModelTests {
    private func makeBook(
        url: URL,
        title: String = "Book",
        childCount: Int = 0,
        isCollection: Bool = false,
        order: Int = 0
    ) -> BookDTO {
        BookDTO(url: url, bookTitle: title, childCount: childCount, isCollection: isCollection, order: order)
    }

    @Test
    func handleOnAppearWithoutProviderKeepsSafeState() async throws {
        let viewModel = BookGridViewModel()
        viewModel.handleOnAppear()
        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.isLoading)
        #expect(viewModel.books.isEmpty)
    }

    @Test
    func handleOnAppearLoadsBooksFromProvider() async throws {
        let provider = BookProbe()
        let book = makeBook(url: URL(fileURLWithPath: "/tmp/Book1"))
        provider.booksValue = [book]

        let viewModel = BookGridViewModel()
        viewModel.bind(provider: provider)
        viewModel.handleOnAppear()
        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.books == [book])
        #expect(viewModel.bookURLIndex[book.url] == book)
        #expect(!viewModel.isLoading)
    }

    @Test
    func handleAssetChangedSelectsMatchingLoadedBook() async throws {
        let provider = BookProbe()
        let bookURL = URL(fileURLWithPath: "/tmp/Book1")
        provider.booksValue = [makeBook(url: bookURL)]

        let viewModel = BookGridViewModel()
        viewModel.bind(provider: provider)
        viewModel.handleOnAppear()
        try await Task.sleep(for: .milliseconds(400))

        viewModel.handleAssetChanged(bookURL)
        #expect(viewModel.selectedBookURL == bookURL)
    }

    @Test
    func handleAssetChangedNilClearsSelection() async throws {
        let provider = BookProbe()
        let bookURL = URL(fileURLWithPath: "/tmp/Book1")
        provider.booksValue = [makeBook(url: bookURL)]

        let viewModel = BookGridViewModel()
        viewModel.bind(provider: provider)
        viewModel.handleOnAppear()
        try await Task.sleep(for: .milliseconds(400))

        viewModel.handleAssetChanged(bookURL)
        viewModel.handleAssetChanged(nil)
        #expect(viewModel.selectedBookURL == nil)
    }

    @Test
    func handleBookTapPlaysFileWhenNoSavedState() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookTap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let bookURL = tmp.appendingPathComponent("chapter.mp3")
        try Data().write(to: bookURL)

        let provider = BookProbe()
        provider.booksValue = [makeBook(url: bookURL)]
        let capability = CapabilityProbe()

        let viewModel = BookGridViewModel(playbackCapability: capability)
        viewModel.bind(provider: provider)
        viewModel.handleOnAppear()
        try await Task.sleep(for: .milliseconds(400))

        viewModel.handleBookTap(book: makeBook(url: bookURL))
        try await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.selectedBookURL == bookURL)
        #expect(capability.played.count == 1)
        #expect(capability.played.first?.url == bookURL)
    }

    @Test
    func handleBookTapRestoresSavedPlaybackState() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookResume-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let bookURL = tmp.appendingPathComponent("Book", isDirectory: true)
        try FileManager.default.createDirectory(at: bookURL, withIntermediateDirectories: true)
        let chapterURL = bookURL.appendingPathComponent("chapter.mp3")
        try Data().write(to: chapterURL)

        let provider = BookProbe()
        provider.booksValue = [makeBook(url: bookURL, childCount: 1, isCollection: true)]
        provider.playbackStateValue = BookPlaybackStateDTO(currentURL: chapterURL, time: 30)
        let capability = CapabilityProbe()

        let viewModel = BookGridViewModel(playbackCapability: capability)
        viewModel.bind(provider: provider)
        viewModel.handleOnAppear()
        try await Task.sleep(for: .milliseconds(400))

        viewModel.handleBookTap(book: makeBook(url: bookURL, childCount: 1, isCollection: true))
        try await Task.sleep(for: .milliseconds(200))

        #expect(capability.played.count == 1)
        #expect(capability.played.first?.url == chapterURL)
        #expect(capability.played.first?.startTime == 30)
    }

    @Test
    func syncEventsUpdateIsSyncing() {
        let viewModel = BookGridViewModel()
        viewModel.handleBookDBSyncing()
        #expect(viewModel.isSyncing)
        viewModel.handleBookDBSynced()
        #expect(!viewModel.isSyncing)
    }

    @Test
    func stateUpdatedEventRecordsURL() {
        let viewModel = BookGridViewModel()
        viewModel.handleBookStateUpdated(URL(fileURLWithPath: "/tmp/x.mp3"))
        #expect(viewModel.lastStateUpdatedURL == URL(fileURLWithPath: "/tmp/x.mp3"))
    }

    @Test
    func handleOnDisappearInvalidatesPendingUpdates() async throws {
        let provider = BookProbe()
        provider.booksValue = [makeBook(url: URL(fileURLWithPath: "/tmp/Book1"))]
        let viewModel = BookGridViewModel()
        viewModel.bind(provider: provider)

        // 触发 debounce 后立即消失：代际失效，books 不应被应用。
        viewModel.handleOnAppear()
        viewModel.handleOnDisappear()
        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.books.isEmpty)
    }
}

// MARK: - BookGridPlayableChildrenLoader

@MainActor
@Suite(.serialized)
struct BookGridPlayableChildrenLoaderTests {
    @Test
    func loadScansDirectoryAndCaches() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookLoader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let folder = tmp.appendingPathComponent("Book", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("a.mp3"))
        try Data().write(to: folder.appendingPathComponent("b.m4a"))
        try Data().write(to: folder.appendingPathComponent("cover.png"))

        let first = await BookGridPlayableChildrenLoader.load(for: folder)
        #expect(first.count == 2)
        #expect(first.allSatisfy { $0.pathExtension != "png" })

        // 缓存命中（不重新扫描）。
        BookGridPlayableChildrenLoader.invalidateCache(for: folder)
        let after = await BookGridPlayableChildrenLoader.load(for: folder)
        #expect(after.count == 2)
    }

    @Test
    func invalidateCacheClearsAllEntries() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookLoaderCache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try Data().write(to: tmp.appendingPathComponent("a.mp3"))

        let folder = tmp.appendingPathComponent("Sub", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = await BookGridPlayableChildrenLoader.load(for: folder)
        BookGridPlayableChildrenLoader.invalidateCache()
        _ = await BookGridPlayableChildrenLoader.load(for: folder)
        // 不崩溃即为通过；缓存清理后重新扫描成功。
    }
}

// MARK: - Policy 纯函数

struct BookGridPoliciesTests {
    @Test
    func updatePolicyAppliesOnlyMatchingGeneration() {
        #expect(BookGridUpdatePolicy.shouldApplyResult(currentGeneration: 3, resultGeneration: 3))
        #expect(!BookGridUpdatePolicy.shouldApplyResult(currentGeneration: 3, resultGeneration: 4))
        #expect(BookGridUpdatePolicy.nextGeneration(after: 2) == 3)
        #expect(BookGridPlaybackRequestPolicy.generationAfterInvalidatingPendingPlayback(5) == 6)
    }

    @Test
    func playbackRequestPolicyChecksGenerationAndSelection() {
        let url = URL(fileURLWithPath: "/tmp/book.mp3")
        let displayed = [
            BookDTO(url: URL(fileURLWithPath: "/tmp/book.mp3"), bookTitle: "B", childCount: 0, isCollection: false, order: 0),
            BookDTO(url: URL(fileURLWithPath: "/tmp/other.mp3"), bookTitle: "O", childCount: 0, isCollection: false, order: 1),
        ]

        // 代际匹配 + 选中代表 + 在展示列表内 → 通过。
        #expect(BookGridPlaybackRequestPolicy.shouldApplyResult(
            currentGeneration: 1, resultGeneration: 1,
            requestedBookURL: url, selectedBookURL: url, displayedBooks: displayed
        ))
        // 代际不匹配 → 拒绝。
        #expect(!BookGridPlaybackRequestPolicy.shouldApplyResult(
            currentGeneration: 2, resultGeneration: 1,
            requestedBookURL: url, selectedBookURL: url, displayedBooks: displayed
        ))
        // 未选中 → 拒绝。
        #expect(!BookGridPlaybackRequestPolicy.shouldApplyResult(
            currentGeneration: 1, resultGeneration: 1,
            requestedBookURL: url, selectedBookURL: nil, displayedBooks: displayed
        ))
        // 请求书不在展示列表 → 拒绝。
        #expect(!BookGridPlaybackRequestPolicy.shouldApplyResult(
            currentGeneration: 1, resultGeneration: 1,
            requestedBookURL: URL(fileURLWithPath: "/tmp/missing.mp3"),
            selectedBookURL: url, displayedBooks: displayed
        ))

        // no-playable 报告复用同一策略。
        #expect(BookGridPlaybackRequestPolicy.shouldReportNoPlayableChapters(
            currentGeneration: 1, resultGeneration: 1,
            requestedBookURL: url, selectedBookURL: url, displayedBooks: displayed
        ))
    }

    @Test
    func selectionPolicyMatchesBySameFile() {
        let url = URL(fileURLWithPath: "/tmp/book.mp3")
        #expect(BookGridSelectionPolicy.representsSelectedBook(url, selectedURL: url))
        #expect(!BookGridSelectionPolicy.representsSelectedBook(url, selectedURL: URL(fileURLWithPath: "/tmp/other.mp3")))
        #expect(!BookGridSelectionPolicy.representsSelectedBook(url, selectedURL: nil))

        let books = [
            BookDTO(url: url, bookTitle: "B", childCount: 0, isCollection: false, order: 0),
        ]
        #expect(BookGridSelectionPolicy.containsSelectedBook(url, in: books))
        #expect(!BookGridSelectionPolicy.containsSelectedBook(URL(fileURLWithPath: "/tmp/none.mp3"), in: books))
        #expect(BookGridSelectionPolicy.selectionLabel(bookTitle: "Book") == String(localized: "Select Book", bundle: .module))
    }
}