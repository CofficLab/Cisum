import CisumUIComponents
import OSLog
import SwiftData
import SwiftUI
import ProviderAudioLibrary

enum AudioListFileIdentity {
    static func canonicalIdentity(for url: URL) -> String {
        guard url.isFileURL else {
            return url.standardized.absoluteString
        }

        if isDanglingSymlink(url) {
            return url.standardizedFileURL.path
        }

        return url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private static func isDanglingSymlink(_ url: URL) -> Bool {
        guard (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true else {
            return false
        }

        return !FileManager.default.fileExists(atPath: url.path)
    }
}

enum AudioListLoadPolicy {
    static func shouldApplyResult(currentGeneration: Int, resultGeneration: Int) -> Bool {
        currentGeneration == resultGeneration
    }

    static func uniqueAdditionalURLs(existingURLs: [URL], newURLs: [URL]) -> [URL] {
        var seenIdentities = Set(existingURLs.map(canonicalIdentity(for:)))
        var uniqueURLs: [URL] = []
        uniqueURLs.reserveCapacity(newURLs.count)

        for url in newURLs {
            let identity = canonicalIdentity(for: url)
            guard seenIdentities.insert(identity).inserted else { continue }
            uniqueURLs.append(url)
        }

        return uniqueURLs
    }

    static func hasMoreAfterLoading(fetchedCount: Int, pageSize: Int) -> Bool {
        fetchedCount == pageSize
    }

    static func shouldKeepLoadingStateWhenDiscardingStaleResult(
        currentGeneration: Int,
        resultGeneration: Int
    ) -> Bool {
        currentGeneration != resultGeneration
    }

    static func loadingStateWhenStartingCurrentPageRefresh(displayedCount: Int) -> (isLoading: Bool, isLoadingMore: Bool) {
        (isLoading: displayedCount == 0, isLoadingMore: false)
    }

    static func shouldLoadMore(
        currentIndex: Int,
        loadedCount: Int,
        hasMore: Bool,
        isLoadingMore: Bool
    ) -> Bool {
        guard loadedCount > 0, currentIndex >= 0, hasMore, !isLoadingMore else {
            return false
        }

        let threshold = max(loadedCount - 10, Int(Double(loadedCount) * 0.8))
        return currentIndex >= threshold
    }

    /// Quick pre-check to see if an index is near the load-more threshold.
    /// Used to avoid calling the full `shouldLoadMore` check for every cell.
    static func isNearThreshold(currentIndex: Int, loadedCount: Int) -> Bool {
        guard loadedCount > 0 else { return false }
        let threshold = max(loadedCount - 15, Int(Double(loadedCount) * 0.75))
        return currentIndex >= threshold
    }

    static func generationAfterDeletingDisplayedItems(_ generation: Int) -> Int {
        generation + 1
    }

    static func currentPageAfterDeletingDisplayedItems(remainingDisplayedCount: Int, pageSize: Int) -> Int {
        guard remainingDisplayedCount > 0, pageSize > 0 else {
            return 0
        }

        return remainingDisplayedCount / pageSize
    }

    static func nextLoadOffset(loadedCount: Int, currentPage: Int, pageSize: Int) -> Int {
        max(0, max(loadedCount, currentPage * pageSize))
    }

    static func pageAfterLoading(currentPage: Int, fetchedCount: Int) -> Int {
        fetchedCount > 0 ? currentPage + 1 : currentPage
    }

    private static func canonicalIdentity(for url: URL) -> String {
        AudioListFileIdentity.canonicalIdentity(for: url)
    }
}

enum AudioListDeletionPolicy {
    static func shouldRemove(_ url: URL, deletedURLs: [URL]) -> Bool {
        AudioDeletePlaybackPolicy.deletedURLsContainCurrentAudio(
            currentURL: url,
            deletedURLs: deletedURLs
        )
    }

    static func removedDisplayedCount(from displayedURLs: [URL], deletedURLs: [URL]) -> Int {
        displayedURLs.filter { shouldRemove($0, deletedURLs: deletedURLs) }.count
    }

    static func totalCountAfterDeletion(currentTotal: Int, deletedURLs: [URL]) -> Int {
        max(0, currentTotal - uniqueDeletedCount(deletedURLs))
    }

    private static func uniqueDeletedCount(_ deletedURLs: [URL]) -> Int {
        Set(deletedURLs.map(canonicalIdentity(for:))).count
    }

    private static func canonicalIdentity(for url: URL) -> String {
        AudioListFileIdentity.canonicalIdentity(for: url)
    }
}

enum AudioListSelectionPolicy {
    static func shouldApplySelection(
        currentGeneration: Int,
        requestGeneration: Int,
        requestedURL: URL,
        selection: URL?,
        displayedURLs: [URL]
    ) -> Bool {
        currentGeneration == requestGeneration
            && representsSameAudio(requestedURL, selection)
            && displayedURLs.contains { representsSameAudio($0, requestedURL) }
    }

    static func representsSameAudio(_ lhs: URL?, _ rhs: URL?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.some(lhs), .some(rhs)):
            return resolvedStandardizedPath(for: lhs) == resolvedStandardizedPath(for: rhs)
        default:
            return false
        }
    }

    private static func resolvedStandardizedPath(for url: URL) -> String {
        AudioListFileIdentity.canonicalIdentity(for: url)
    }
}

/*
 Display strategy (flat list + paged loading):
 - Only audio files in the repository are shown; folders are not displayed as groups.
 - Files in every subdirectory are flattened and displayed with one unified sort order.
 - Paged loading is used, and the next page is loaded when scrolling reaches 80%.

 Example:
   Root
   ├─ A/
   │  ├─ A1
   │  └─ A2
   └─ B/
      ├─ B1
      └─ B2

   Flattened display: A1, A2, B1, B2 (the A and B directories are hidden)

 Paged loading:
   - Initial load: 50 rows (or calculated dynamically from screen height)
   - Trigger: scroll to the last 10 rows or the 80% position
   - Automatic deduplication: prevents loading the same data twice
 */
struct AudioList: View, SuperLog {
    nonisolated static let emoji = "📬"
    nonisolated static let verbose = false

    @EnvironmentObject var viewModel: AudioListViewModel
    @LumiTheme private var appTheme

    var body: some View {
        ZStack {
            audioListView

            if viewModel.isLoading && viewModel.urls.isEmpty {
                AudioDBTips(variant: .loading)
            } else if viewModel.urls.isEmpty && !viewModel.isLoading {
                AudioDBTips(variant: .empty)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appTheme.background.ignoresSafeArea())
        .onAppear {
            viewModel.handleOnAppear()
        }
    }

    /// Audio list view.
    private var audioListView: some View {
        List {
            Section(header: HStack {
                Text("Total \(viewModel.totalCount.description)", bundle: .module)
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

                if viewModel.isNotDesktop {
                    BtnAdd()
                        .font(.title2)
                        .labelStyle(.iconOnly)
                }
            }, content: {
                ForEach(Array(viewModel.urls.enumerated()), id: \.element) { index, url in
                    AudioItemView(url)
                        .equatable() // Use Equatable to reduce unnecessary redraws.
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .onAppear {
                            // Only check for more data when approaching the threshold.
                            // This avoids calling checkLoadMore for every cell.
                            if AudioListLoadPolicy.isNearThreshold(
                                currentIndex: index,
                                loadedCount: viewModel.urls.count
                            ) {
                                viewModel.checkLoadMore(at: index)
                            }
                        }
                }
                .onDelete(perform: viewModel.deleteItems(at:))

                // Load-more indicator.
                if viewModel.isLoadingMore && !viewModel.urls.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading more...", bundle: .module)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(height: 44)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            })
        }
        .listStyle(.plain)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(appTheme.background.ignoresSafeArea())
    }
}
