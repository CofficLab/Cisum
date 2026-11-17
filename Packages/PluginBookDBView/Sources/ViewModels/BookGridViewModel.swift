import Combine
import Foundation
import MagicKit
import OSLog
import ProviderBook
import ProviderPlayback
import ProviderToast
import SwiftUI

/// 网格载入标注策略：把「正在下载的章节」映射回它所属的书。
enum BookGridLoadingPolicy {
    /// 下载进度 -> 标注进度。0 视作未知（使用不确定指示器），并夹到 0…1。
    static func badgeProgress(_ progress: Double) -> Double? {
        let clamped = min(max(progress, 0), 1)
        return clamped > 0 ? clamped : nil
    }

    /// 章节 -> 所属书籍：单文件书籍是精确匹配，其余取父目录。
    static func bookURL(forChapter chapterURL: URL, in books: [BookDTO]) -> URL? {
        if let exact = books.first(where: {
            BookPlaybackOrdering.representsSameFile($0.url, chapterURL)
        }) {
            return exact.url
        }
        let parent = chapterURL.deletingLastPathComponent()
        return books.first(where: {
            BookPlaybackOrdering.representsSameFile($0.url, parent)
        })?.url
    }

    static func progressLabel(_ progress: Double) -> String {
        "\(Int((progress * 100).rounded()))%"
    }

    static func accessibilityValue(bookTitle: String, progress: Double?) -> String {
        guard let progress else {
            return String(
                localized: String.LocalizationValue("Loading \(bookTitle)"),
                bundle: .module
            )
        }
        return String(
            localized: String.LocalizationValue("Loading \(bookTitle), \(progressLabel(progress))"),
            bundle: .module
        )
    }
}

/// 书籍网格视图的集中状态容器（迁移 Phase 3）。
///
/// 持有书籍列表、加载/同步状态、选中高亮、播放代际与防抖任务，
/// 统一处理数据库事件与播放资产变化；取代原 `BookGrid` 内的全部
/// `@State` 与事件 handler。由 `BookDBViewPlugin` 入口持有并注入
/// `BookDatabaseObserver`；View 只展示与转发意图。
@MainActor
final class BookGridViewModel: ObservableObject, SuperLog {
    @Published private(set) var books: [BookDTO] = []
    @Published private(set) var bookURLIndex: [URL: BookDTO] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var isSyncing = false
    @Published var selectedBookURL: URL?
    @Published var syncingTotal = 0
    @Published var syncingCurrent = 0
    /// 最近一次播放状态更新的书籍 URL，供 `BookTile` 观察并重载封面。
    @Published var lastStateUpdatedURL: URL?
    /// 正在从 iCloud 载入的书籍 URL；`nil` 表示没有载入标注。
    @Published private(set) var loadingBookURL: URL?
    /// 载入进度；`nil` 表示进度未知（0% 或非下载阶段）。
    @Published private(set) var downloadProgress: Double?

    private var currentAsset: URL?
    private var lastPlaybackState: PlaybackStatus = .idle
    /// 播放与提示能力（Capabilities 目录收窄），`weak` 持有。
    private weak var playback: (any BookLibraryPlaybackCapability)?
    private weak var toast: (any BookLibraryToastCapability)?
    private var bookLibrary: (any BookLibraryCapability)?
    private var updateBooksGeneration = 0
    private var playBookGeneration = 0
    private var updateBooksDebounceTask: Task<Void, Never>?

    private static let verbose = false

    init(
        playback: (any BookLibraryPlaybackCapability)? = nil,
        toast: (any BookLibraryToastCapability)? = nil
    ) {
        self.playback = playback
        self.toast = toast
    }

    func bind(library: (any BookLibraryCapability)?) {
        self.bookLibrary = library
    }

    // MARK: - View lifecycle

    func handleOnAppear() {
        if Self.verbose { os_log("\(Self.t)📋 handleOnAppear, provider: \(self.bookLibrary == nil ? "nil" : "available")") }
        isLoading = true
        scheduleUpdateBooksDebounced()
        if let currentAsset {
            updateSelectedBook(for: currentAsset)
        }
    }

    /// 场景离开时作废在途的**播放**请求。
    ///
    /// 这里**不能**取消尚未执行的加载请求（`updateBooksDebounceTask`），
    /// 也**不能**递增 `updateBooksGeneration`：
    ///
    /// - 取消防抖任务会让 `setBooks()` 永远得不到执行，`isLoading` 停在
    ///   `true`，UI 永远显示「正在读取有声书仓库」；
    /// - 递增 generation 会把「尚未返回」的那次加载结果一并作废，效果同上。
    ///
    /// SwiftUI 在场景切换时给出的 `onAppear` / `onDisappear` 顺序并不固定，
    /// 「先 appear 后 disappear」是真实存在的顺序之一。
    ///
    /// 作废过期结果的职责本来就属于 `scheduleUpdateBooksDebounced()`：
    /// 每次调度都会递增 generation 并取消上一个任务，因此这里无需重复。
    /// 本 ViewModel 由插件入口长期持有、跨场景复用，视图离开并不会让
    /// 已经取到的数据失效。
    func handleOnDisappear() {
        playBookGeneration = BookGridPlaybackRequestPolicy.generationAfterInvalidatingPendingPlayback(playBookGeneration)
    }

    // MARK: - User intents

    func handleBookTap(book: BookDTO) {
        if Self.verbose { os_log("\(Self.t)👆 点击书籍: \(book.bookTitle)") }
        selectedBookURL = book.url
        playBookGeneration += 1
        let generation = playBookGeneration
        Task {
            await playBook(book, generation: generation)
        }
    }

    func handleAssetChanged(_ url: URL?) {
        currentAsset = url
        if let url = url {
            updateSelectedBook(for: url)
        } else {
            selectedBookURL = nil
            playBookGeneration = BookGridPlaybackRequestPolicy.generationAfterInvalidatingPendingPlayback(playBookGeneration)
        }
        refreshLoadingBadge()
    }

    /// 播放状态变化：只有「下载中」才在对应书块上标注进度，
    /// 失败与取消都由控制区横幅承载，网格只负责清除标注。
    func handlePlaybackStateChanged(_ state: PlaybackStatus) {
        lastPlaybackState = state
        refreshLoadingBadge()
    }

    /// 是否为正在载入的书。
    func isLoadingBook(_ bookURL: URL) -> Bool {
        guard let loadingBookURL else { return false }
        return BookPlaybackOrdering.representsSameFile(loadingBookURL, bookURL)
    }

    // MARK: - Database events

    func handleBookDBDeleted() {
        BookGridPlayableChildrenLoader.invalidateCache()
        playBookGeneration = BookGridPlaybackRequestPolicy.generationAfterInvalidatingPendingPlayback(playBookGeneration)
        scheduleUpdateBooksDebounced()
    }

    func handleBookDBSynced() {
        BookGridPlayableChildrenLoader.invalidateCache()
        playBookGeneration = BookGridPlaybackRequestPolicy.generationAfterInvalidatingPendingPlayback(playBookGeneration)
        scheduleUpdateBooksDebounced()
        isSyncing = false
    }

    func handleBookDBUpdated() {
        playBookGeneration = BookGridPlaybackRequestPolicy.generationAfterInvalidatingPendingPlayback(playBookGeneration)
        scheduleUpdateBooksDebounced()
    }

    func handleBookDBSyncing() {
        isSyncing = true
    }

    func handleBookStateUpdated(_ url: URL?) {
        lastStateUpdatedURL = url
    }

    // MARK: - Data loading

    private func updateBooks(generation: Int) {
        guard let bookLibrary else {
            if Self.verbose { os_log("\(Self.t)⚠️ updateBooks: provider is nil") }
            return
        }
        if Self.verbose { os_log("\(Self.t)🔄 updateBooks gen=\(generation)") }
        Task { @MainActor [weak self] in
            let books = await bookLibrary.books(reason: "BookGridViewModel")
            self?.setBooks(books, generation: generation)
        }
    }

    private func scheduleUpdateBooksDebounced(delay seconds: Double = 0.25) {
        if Self.verbose { os_log("\(Self.t)📅 scheduleUpdateBooksDebounced") }
        updateBooksDebounceTask?.cancel()
        updateBooksGeneration = BookGridUpdatePolicy.nextGeneration(after: updateBooksGeneration)
        let generation = updateBooksGeneration
        updateBooksDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1000000000))
            guard !Task.isCancelled else { return }
            self.updateBooks(generation: generation)
        }
    }

    private func setBooks(_ newValue: [BookDTO], generation: Int) {
        guard BookGridUpdatePolicy.shouldApplyResult(
            currentGeneration: updateBooksGeneration,
            resultGeneration: generation
        ) else {
            if Self.verbose { os_log("\(Self.t)⚠️ setBooks: generation mismatch, skipped") }
            return
        }

        if Self.verbose { os_log("\(Self.t)✅ setBooks: \(newValue.count) books loaded") }
        books = newValue

        var index: [URL: BookDTO] = [:]
        for book in newValue {
            index[book.url] = book
        }
        bookURLIndex = index

        isLoading = false

        if let currentAsset {
            updateSelectedBook(for: currentAsset)
        } else if let currentSelection = selectedBookURL,
                  !BookGridSelectionPolicy.containsSelectedBook(currentSelection, in: newValue) {
            selectedBookURL = nil
        }

        refreshLoadingBadge()
    }

    private func refreshLoadingBadge() {
        guard case .loading(.downloading(let progress)) = lastPlaybackState,
              let currentAsset,
              let bookURL = BookGridLoadingPolicy.bookURL(forChapter: currentAsset, in: books) else {
            if loadingBookURL != nil { loadingBookURL = nil }
            if downloadProgress != nil { downloadProgress = nil }
            return
        }

        if loadingBookURL != bookURL { loadingBookURL = bookURL }
        let badgeProgress = BookGridLoadingPolicy.badgeProgress(progress)
        if downloadProgress != badgeProgress { downloadProgress = badgeProgress }
    }

    private func updateSelectedBook(for url: URL) {
        if let book = bookURLIndex[url],
           BookPlaybackOrdering.representsSameFile(book.url, url) {
            selectedBookURL = book.url
            return
        }

        for book in books {
            if BookPlaybackOrdering.representsSameFile(book.url, url)
                || BookPlaybackOrdering.containsPlayableChild(url, in: book.url) {
                selectedBookURL = book.url
                return
            }
        }

        selectedBookURL = nil
    }

    // MARK: - Playback

    private func isPlayableSavedURL(_ savedURL: URL, in book: BookDTO, playableChildren: [URL]) -> Bool {
        if BookPlaybackOrdering.representsSameFile(book.url, savedURL) {
            return FileManager.default.fileExists(atPath: savedURL.path)
                && BookPluginInfo.supportedExtensions.contains(savedURL.pathExtension.lowercased())
        }
        return BookPlaybackOrdering.contains(savedURL, in: playableChildren)
    }

    private func play(_ url: URL, in book: BookDTO, at time: TimeInterval?, generation: Int, reason: String) async {
        guard BookGridPlaybackRequestPolicy.shouldApplyResult(
            currentGeneration: playBookGeneration,
            resultGeneration: generation,
            requestedBookURL: book.url,
            selectedBookURL: selectedBookURL,
            displayedBooks: books
        ) else {
            return
        }

        if Self.verbose { os_log("\(Self.t)▶️ 播放(\(reason)): \(url.lastPathComponent) @ \(time.map { "\($0)s" } ?? "开头")") }
        await playback?.play(url, startTime: time)
    }

    private func playBook(_ book: BookDTO, generation: Int) async {
        let playableChildren = await BookGridPlayableChildrenLoader.load(for: book.url)
        let reason = "BookGridViewModel"

        if let bookState = await bookLibrary?.playbackState(for: book.url),
           let savedURL = bookState.currentURL,
           let savedTime = bookState.time,
           isPlayableSavedURL(savedURL, in: book, playableChildren: playableChildren) {
            await play(savedURL, in: book, at: savedTime, generation: generation, reason: reason)
            return
        }

        if let savedURL = bookLibrary?.currentBookURL(),
           let savedTime = bookLibrary?.currentBookTime(),
           isPlayableSavedURL(savedURL, in: book, playableChildren: playableChildren) {
            await play(savedURL, in: book, at: savedTime, generation: generation, reason: reason)
            return
        }

        if let first = playableChildren.first {
            guard BookGridPlaybackRequestPolicy.shouldApplyResult(
                currentGeneration: playBookGeneration,
                resultGeneration: generation,
                requestedBookURL: book.url,
                selectedBookURL: selectedBookURL,
                displayedBooks: books
            ) else {
                return
            }
            await playback?.play(first, startTime: nil)
        } else {
            guard BookGridPlaybackRequestPolicy.shouldReportNoPlayableChapters(
                currentGeneration: playBookGeneration,
                resultGeneration: generation,
                requestedBookURL: book.url,
                selectedBookURL: selectedBookURL,
                displayedBooks: books
            ) else {
                return
            }

            guard FileManager.default.fileExists(atPath: book.url.path),
                  BookPluginInfo.supportedExtensions.contains(book.url.pathExtension.lowercased()) else {
                toast?.error(String(localized: "No playable chapters found", bundle: .module))
                return
            }

            await playback?.play(book.url, startTime: nil)
        }
    }

}
