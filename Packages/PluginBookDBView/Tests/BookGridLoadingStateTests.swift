import Foundation
import Testing
import ProviderBook
@testable import PluginBookDBView

/// 场景切换时 `BookGridViewModel` 的 `isLoading` 状态回归。
///
/// 复现问题：从音乐场景切换到有声书场景时，"正在读取有声书仓库"一直显示，
/// 这意味着 `isLoading` 一直为 `true`，`setBooks()` 从未被调用。
@MainActor
struct BookGridLoadingStateTests {
    
    /// 模拟场景：`BookLibraryCapability` 的 `books` 方法返回空数组。
    /// 预期：`isLoading` 应该变为 `false`。
    @Test
    func isLoadingBecomesFalseWhenBooksReturnsEmpty() async throws {
        let probe = EmptyBookProbe()
        let viewModel = BookGridViewModel()
        viewModel.bind(library: probe)
        
        #expect(viewModel.isLoading, "初始状态应为 loading")
        
        viewModel.handleOnAppear()
        
        // 等待 debounce 和异步加载完成
        for _ in 0..<50 where viewModel.isLoading {
            try await Task.sleep(for: .milliseconds(50))
        }
        
        #expect(!viewModel.isLoading, "books() 返回空数组后，isLoading 应变为 false")
        #expect(viewModel.books.isEmpty, "books 应为空")
    }
    
    /// 模拟场景：`BookLibraryCapability` 的 `books` 方法返回书籍列表。
    /// 预期：`isLoading` 应该变为 `false`，books 不为空。
    @Test
    func isLoadingBecomesFalseWhenBooksReturnsItems() async throws {
        let probe = BookProbe()
        let book = BookDTO(
            url: URL(fileURLWithPath: "/tmp/Book1"),
            bookTitle: "Test Book",
            childCount: 0,
            isCollection: false,
            order: 0
        )
        probe.booksValue = [book]
        
        let viewModel = BookGridViewModel()
        viewModel.bind(library: probe)
        
        #expect(viewModel.isLoading, "初始状态应为 loading")
        
        viewModel.handleOnAppear()
        
        // 等待 debounce 和异步加载完成
        for _ in 0..<50 where viewModel.isLoading {
            try await Task.sleep(for: .milliseconds(50))
        }
        
        #expect(!viewModel.isLoading, "books() 返回数据后，isLoading 应变为 false")
        #expect(viewModel.books.count == 1, "books 应包含 1 本书")
    }
    
    /// 模拟场景：`BookLibraryCapability` 的 `books` 方法永远不会返回（挂起）。
    /// 预期：`isLoading` 应保持为 `true`。
    /// 这是问题复现的关键测试。
    @Test
    func isLoadingStaysTrueWhenBooksNeverReturns() async throws {
        let probe = HangingBookProbe()
        let viewModel = BookGridViewModel()
        viewModel.bind(library: probe)
        
        #expect(viewModel.isLoading, "初始状态应为 loading")
        
        viewModel.handleOnAppear()
        
        // 等待一段时间，确认 isLoading 保持为 true
        try await Task.sleep(for: .milliseconds(500))
        
        #expect(viewModel.isLoading, "books() 永不返回时，isLoading 应保持为 true")
        
        // 释放挂起的 probe
        probe.release()
    }
    
    /// 模拟场景：`bind` 时 `library` 为 `nil`。
    /// 预期：`isLoading` 应保持为 `true`（因为没有 provider 可以加载数据）。
    @Test
    func isLoadingStaysTrueWhenNoLibraryBound() async throws {
        let viewModel = BookGridViewModel()
        // 不调用 bind
        
        #expect(viewModel.isLoading, "初始状态应为 loading")
        
        viewModel.handleOnAppear()
        
        // 等待 debounce
        try await Task.sleep(for: .milliseconds(400))
        
        #expect(viewModel.isLoading, "没有 library 时，isLoading 应保持为 true")
    }
    
    /// 模拟场景：多次快速调用 `handleOnAppear`（模拟场景快速切换）。
    /// 预期：只有最后一次调用应该生效，`isLoading` 最终应变为 `false`。
    @Test
    func rapidSceneSwitchesSettleCorrectly() async throws {
        let probe = BookProbe()
        let book = BookDTO(
            url: URL(fileURLWithPath: "/tmp/Book1"),
            bookTitle: "Test Book",
            childCount: 0,
            isCollection: false,
            order: 0
        )
        probe.booksValue = [book]
        
        let viewModel = BookGridViewModel()
        viewModel.bind(library: probe)
        
        // 模拟快速切换
        viewModel.handleOnAppear()
        viewModel.handleOnAppear()
        viewModel.handleOnAppear()
        
        // 等待 debounce 和异步加载完成
        for _ in 0..<50 where viewModel.isLoading {
            try await Task.sleep(for: .milliseconds(50))
        }
        
        #expect(!viewModel.isLoading, "多次快速切换后，isLoading 最终应变为 false")
    }
}

// MARK: - Test Probes

/// 返回空书籍列表的探针。
@MainActor
private final class EmptyBookProbe: BookLibraryCapability {
    var bookDisk: URL? = URL(fileURLWithPath: "/tmp/books")
    var databaseRoot = URL(fileURLWithPath: "/tmp/book-db")
    
    func books(reason: String) async -> [BookDTO] { [] }
    func syncImportedItems(_ items: [URL]) async throws {}
    func coverData(for bookURL: URL) async -> Data? { nil }
    func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO? { nil }
    func currentBookURL() -> URL? { nil }
    func currentBookTime() -> TimeInterval? { nil }
    
    @discardableResult
    func addObserver(_ callback: @escaping (BookLibraryEvent) -> Void) -> any BookLibraryObserverHandle {
        ProbeHandle {}
    }
}

/// 挂起永不返回的探针，用于模拟 `waitForInitialSync()` 永不完成的情况。
@MainActor
private final class HangingBookProbe: BookLibraryCapability {
    var bookDisk: URL? = URL(fileURLWithPath: "/tmp/books")
    var databaseRoot = URL(fileURLWithPath: "/tmp/book-db")
    
    private var continuation: CheckedContinuation<[BookDTO], Never>?
    
    func books(reason: String) async -> [BookDTO] {
        // 挂起，直到 release() 被调用
        await withCheckedContinuation { cont in
            self.continuation = cont
        }
    }
    
    func release() {
        continuation?.resume(returning: [])
        continuation = nil
    }
    
    func syncImportedItems(_ items: [URL]) async throws {}
    func coverData(for bookURL: URL) async -> Data? { nil }
    func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO? { nil }
    func currentBookURL() -> URL? { nil }
    func currentBookTime() -> TimeInterval? { nil }
    
    @discardableResult
    func addObserver(_ callback: @escaping (BookLibraryEvent) -> Void) -> any BookLibraryObserverHandle {
        ProbeHandle {}
    }
}

/// 可配置书籍列表的探针。
@MainActor
private final class BookProbe: BookLibraryCapability {
    var bookDisk: URL? = URL(fileURLWithPath: "/tmp/books")
    var databaseRoot = URL(fileURLWithPath: "/tmp/book-db")
    var booksValue: [BookDTO] = []
    
    func books(reason: String) async -> [BookDTO] { booksValue }
    func syncImportedItems(_ items: [URL]) async throws {}
    func coverData(for bookURL: URL) async -> Data? { nil }
    func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO? { nil }
    func currentBookURL() -> URL? { nil }
    func currentBookTime() -> TimeInterval? { nil }
    
    @discardableResult
    func addObserver(_ callback: @escaping (BookLibraryEvent) -> Void) -> any BookLibraryObserverHandle {
        ProbeHandle {}
    }
}

@MainActor
private final class ProbeHandle: BookLibraryObserverHandle {
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
