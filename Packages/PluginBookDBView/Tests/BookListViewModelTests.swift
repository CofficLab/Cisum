import Foundation
import MagicKit
import ProviderBook
import Testing

@testable import PluginBookDBView

// MARK: - Mock BookLibraryCapability

@MainActor
private final class MockBookLibrary: BookLibraryCapability {
    var bookDisk: URL? = URL(fileURLWithPath: "/tmp/books", isDirectory: true)
    var databaseRoot: URL = URL(fileURLWithPath: "/tmp/db", isDirectory: true)
    var booksValue: [BookDTO] = []
    private(set) var booksCallCount = 0
    private(set) var lastBooksReason: String?

    func books(reason: String) async -> [BookDTO] {
        booksCallCount += 1
        lastBooksReason = reason
        return booksValue
    }

    func syncImportedItems(_ items: [URL]) async throws {}
    func coverData(for bookURL: URL) async -> Data? { nil }
    func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO? { nil }
    func currentBookURL() -> URL? { nil }
    func currentBookTime() -> TimeInterval? { nil }

    @discardableResult
    func addObserver(_ callback: @escaping (BookLibraryEvent) -> Void) -> any BookLibraryObserverHandle {
        MockHandle {}
    }
}

@MainActor
private final class MockHandle: BookLibraryObserverHandle {
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

// MARK: - BookListViewModel Tests

@MainActor
struct BookListViewModelTests {
    // MARK: - Initialization

    @Test
    func initWithNilLibraryHasEmptyState() {
        let viewModel = BookListViewModel(bookLibrary: nil)

        #expect(viewModel.books.isEmpty)
        #expect(viewModel.totalCount == 0)
        #expect(!viewModel.isLoading)
    }

    @Test
    func initWithLibraryHasEmptyStateBeforeAppear() {
        let library = MockBookLibrary()
        let viewModel = BookListViewModel(bookLibrary: library)

        #expect(viewModel.books.isEmpty)
        #expect(viewModel.totalCount == 0)
        #expect(!viewModel.isLoading)
    }

    // MARK: - Loading

    @Test
    func handleOnAppearWithNilLibrarySetsIsLoadingFalse() async throws {
        let viewModel = BookListViewModel(bookLibrary: nil)

        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false",
            timeout: 2.0
        ) { !viewModel.isLoading }

        #expect(!viewModel.isLoading)
        #expect(viewModel.books.isEmpty)
        #expect(viewModel.totalCount == 0)
    }

    @Test
    func handleOnAppearLoadsBooksFromLibrary() async throws {
        let library = MockBookLibrary()
        let book = BookDTO(
            url: URL(fileURLWithPath: "/tmp/Book1"),
            bookTitle: "Test Book",
            childCount: 3,
            isCollection: true,
            order: 0
        )
        library.booksValue = [book]

        let viewModel = BookListViewModel(bookLibrary: library)

        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false after loading",
            timeout: 2.0
        ) { !viewModel.isLoading }

        #expect(viewModel.books == [book])
        #expect(viewModel.totalCount == 1)
        #expect(!viewModel.isLoading)
        #expect(library.booksCallCount == 1)
    }

    @Test
    func handleOnAppearPassesReasonTag() async throws {
        let library = MockBookLibrary()
        let viewModel = BookListViewModel(bookLibrary: library, reasonTag: "SettingsPage")

        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false",
            timeout: 2.0
        ) { !viewModel.isLoading }

        #expect(library.lastBooksReason == "SettingsPage")
    }

    @Test
    func handleOnAppearWithEmptyLibrarySetsEmptyBooks() async throws {
        let library = MockBookLibrary()
        library.booksValue = []

        let viewModel = BookListViewModel(bookLibrary: library)

        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false",
            timeout: 2.0
        ) { !viewModel.isLoading }

        #expect(viewModel.books.isEmpty)
        #expect(viewModel.totalCount == 0)
    }

    @Test
    func handleOnAppearLoadsMultipleBooks() async throws {
        let library = MockBookLibrary()
        let books = (0..<5).map { i in
            BookDTO(
                url: URL(fileURLWithPath: "/tmp/Book\(i)"),
                bookTitle: "Book \(i)",
                childCount: i,
                isCollection: i > 0,
                order: i
            )
        }
        library.booksValue = books

        let viewModel = BookListViewModel(bookLibrary: library)

        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false",
            timeout: 2.0
        ) { !viewModel.isLoading }

        #expect(viewModel.books.count == 5)
        #expect(viewModel.totalCount == 5)
    }

    // MARK: - Staleness protection

    @Test
    func rapidAppearCallsOnlyTriggerLatestLoad() async throws {
        let library = MockBookLibrary()
        library.booksValue = [
            BookDTO(url: URL(fileURLWithPath: "/tmp/Book"), bookTitle: "Book", childCount: 0, isCollection: false, order: 0)
        ]

        let viewModel = BookListViewModel(bookLibrary: library)

        // Multiple rapid calls - generation protection ensures only latest result applies
        viewModel.handleOnAppear()
        viewModel.handleOnAppear()
        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false",
            timeout: 2.0
        ) { !viewModel.isLoading }

        // Should have loaded successfully despite multiple calls
        #expect(!viewModel.isLoading)
        #expect(viewModel.books.count == 1)
    }

    // MARK: - Guard against double loading

    @Test
    func handleOnAppearWhileLoadingDoesNotStartNewLoad() async throws {
        let library = MockBookLibrary()
        let viewModel = BookListViewModel(bookLibrary: library)

        viewModel.handleOnAppear()
        // Immediately call again while first load is in progress
        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false",
            timeout: 2.0
        ) { !viewModel.isLoading }

        // The second call should have been rejected by the guard
        #expect(library.booksCallCount == 1)
    }
}
