import Combine
import Foundation
import MagicKit
import OSLog
import ProviderBook
import SwiftUI

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

    private var currentAsset: URL?
    /// 书籍/章节点击所需的最小播放能力。
    private let playbackCapability: (any BookDBPlaybackCapability)?
    private var bookProvider: (any BookDatabaseProviding)?
    private var updateBooksGeneration = 0
    private var playBookGeneration = 0
    private var updateBooksDebounceTask: Task<Void, Never>?

    private static let verbose = true

    init(playbackCapability: (any BookDBPlaybackCapability)? = nil) {
        self.playbackCapability = playbackCapability
    }

    func bind(provider: (any BookDatabaseProviding)?) {
        self.bookProvider = provider
    }

    // MARK: - View lifecycle

    func handleOnAppear() {
        if Self.verbose { os_log("\(Self.t)📋 handleOnAppear, provider: \(self.bookProvider == nil ? "nil" : "available")") }
        isLoading = true
        scheduleUpdateBooksDebounced()
        if let currentAsset {
            updateSelectedBook(for: currentAsset)
        }
    }

    func handleOnDisappear() {
        updateBooksDebounceTask?.cancel()
        updateBooksDebounceTask = nil
        updateBooksGeneration += 1
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

    func handleBookDBSortDone() {
        playBookGeneration = BookGridPlaybackRequestPolicy.generationAfterInvalidatingPendingPlayback(playBookGeneration)
        scheduleUpdateBooksDebounced()
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
        guard let bookProvider else {
            if Self.verbose { os_log("\(Self.t)⚠️ updateBooks: provider is nil") }
            return
        }
        if Self.verbose { os_log("\(Self.t)🔄 updateBooks gen=\(generation)") }
        Task { @MainActor [weak self] in
            let books = await bookProvider.books(reason: "BookGridViewModel")
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
        await playbackCapability?.play(url, startTime: time)
    }

    private func playBook(_ book: BookDTO, generation: Int) async {
        let playableChildren = await BookGridPlayableChildrenLoader.load(for: book.url)
        let reason = "BookGridViewModel"

        if let bookState = await bookProvider?.playbackState(for: book.url),
           let savedURL = bookState.currentURL,
           let savedTime = bookState.time,
           isPlayableSavedURL(savedURL, in: book, playableChildren: playableChildren) {
            await play(savedURL, in: book, at: savedTime, generation: generation, reason: reason)
            return
        }

        if let savedURL = bookProvider?.currentBookURL(),
           let savedTime = bookProvider?.currentBookTime(),
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
            await playbackCapability?.play(first, startTime: nil)
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
                alert_error(String(localized: "No playable chapters found", bundle: .module))
                return
            }

            await playbackCapability?.play(book.url, startTime: nil)
        }
    }

}
