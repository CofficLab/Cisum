import CisumUIComponents
import OSLog
import ProviderBook
import ProviderBook
import SwiftUI

enum BookGridUpdatePolicy {
    static func shouldApplyResult(currentGeneration: Int, resultGeneration: Int) -> Bool {
        currentGeneration == resultGeneration
    }

    static func nextGeneration(after generation: Int) -> Int {
        generation + 1
    }
}

enum BookGridPlaybackRequestPolicy {
    static func shouldApplyResult(
        currentGeneration: Int,
        resultGeneration: Int,
        requestedBookURL: URL,
        selectedBookURL: URL?,
        displayedBooks: [BookDTO]
    ) -> Bool {
        currentGeneration == resultGeneration
            && BookGridSelectionPolicy.representsSelectedBook(requestedBookURL, selectedURL: selectedBookURL)
            && BookGridSelectionPolicy.containsSelectedBook(requestedBookURL, in: displayedBooks)
    }

    static func shouldReportNoPlayableChapters(
        currentGeneration: Int,
        resultGeneration: Int,
        requestedBookURL: URL,
        selectedBookURL: URL?,
        displayedBooks: [BookDTO]
    ) -> Bool {
        shouldApplyResult(
            currentGeneration: currentGeneration,
            resultGeneration: resultGeneration,
            requestedBookURL: requestedBookURL,
            selectedBookURL: selectedBookURL,
            displayedBooks: displayedBooks
        )
    }

    static func generationAfterInvalidatingPendingPlayback(_ generation: Int) -> Int {
        generation + 1
    }
}

enum BookGridSelectionPolicy {
    static func representsSelectedBook(_ bookURL: URL, selectedURL: URL?) -> Bool {
        guard let selectedURL else { return false }
        return BookPlaybackOrdering.representsSameFile(bookURL, selectedURL)
    }

    static func containsSelectedBook(_ selectedURL: URL, in books: [BookDTO]) -> Bool {
        books.contains {
            representsSelectedBook($0.url, selectedURL: selectedURL)
        }
    }

    static func selectionLabel(bookTitle: String) -> String {
        String(localized: "Select \(bookTitle)", bundle: .module)
    }
}

enum BookGridPlayableChildrenLoader {
    /// In-memory cache for scanned playable children to avoid repeated directory I/O.
    /// Key: standardized book URL path, Value: sorted playable child URLs.
    nonisolated(unsafe) private static var cache: [String: [URL]] = [:]

    static func load(for bookURL: URL) async -> [URL] {
        let key = cacheKey(for: bookURL)

        if let cached = cache[key] {
            return cached
        }

        let result = await Task.detached(priority: .userInitiated) {
            BookPlaybackOrdering.playableChildren(for: bookURL)
        }.value

        cache[key] = result
        return result
    }

    /// Invalidates the entire playable children cache.
    /// Called when books are refreshed, deleted, or synced.
    static func invalidateCache() {
        cache.removeAll()
    }

    /// Invalidates cache for a specific book URL.
    static func invalidateCache(for bookURL: URL) {
        cache.removeValue(forKey: cacheKey(for: bookURL))
    }

    private static func cacheKey(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}

struct BookGrid: View, SuperLog, SuperThread, SuperEvent {
    @LumiTheme private var appTheme
    nonisolated static let emoji = "📖"
    nonisolated static let verbose = true

    @Environment(\.bookDBViewDependencies) private var dependencies
    @EnvironmentObject var viewModel: BookGridViewModel

    /// Total book count.
    var total: Int { viewModel.books.count }

    /// Whether tips should be shown.
    var showTips: Bool {
        false
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                BookDBTips(variant: .loading)
            } else if total == 0 {
                BookDBTips(variant: .empty)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Total \(total)", bundle: .module)
                        Spacer()
                        if viewModel.isSyncing {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Reading repository", bundle: .module)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)

                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 150), spacing: 12),
                        ], alignment: .center, spacing: 16, pinnedViews: [.sectionHeaders]) {
                            ForEach(viewModel.books) { item in
                                let isSelected = BookGridSelectionPolicy.representsSelectedBook(
                                    item.url,
                                    selectedURL: viewModel.selectedBookURL
                                )

                                BookTile(url: item.url, title: item.bookTitle, childCount: item.childCount)
                                    .overlay(
                                        Rectangle()
                                            .stroke(
                                                isSelected ? appTheme.primary : Color.clear,
                                                lineWidth: isSelected ? 3 : 0
                                            )
                                            .animation(.easeInOut(duration: 0.2), value: isSelected)
                                    )
                                    .onTapGesture {
                                        viewModel.handleBookTap(book: item)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel(BookGridSelectionPolicy.selectionLabel(bookTitle: item.bookTitle))
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction {
                                        viewModel.handleBookTap(book: item)
                                    }
                                    .help(BookGridSelectionPolicy.selectionLabel(bookTitle: item.bookTitle))
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            if Self.verbose { os_log("\(Self.t)📖 BookGrid onAppear") }
            Task { @MainActor in
                if Self.verbose { os_log("\(Self.t)📖 BookGrid provider: \(dependencies.bookProvider == nil ? "nil" : "available")") }
                viewModel.bind(provider: dependencies.bookProvider)
                viewModel.handleOnAppear()
            }
        }
        .onDisappear {
            viewModel.handleOnDisappear()
        }
    }
}

// MARK: - Preview

#if os(macOS)

#endif
