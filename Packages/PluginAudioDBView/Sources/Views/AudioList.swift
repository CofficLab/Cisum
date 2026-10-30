import MagicKit
import LumiUI
import KitAudioRepositoryImport
import OSLog
import SwiftData
import SwiftUI
import ProviderAudioLibrary

enum AudioListFileIdentity {
    static func canonicalIdentity(for url: URL) -> String {
        AudioRepositoryFileIdentity.canonicalIdentity(for: url)
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

/// 统计表头（「共 N」所在行）的展示策略。
enum AudioListHeaderPolicy {
    /// 表头最右侧是否展示「添加」按钮（导入入口）。
    ///
    /// - Parameter hasContent: 仓库列表是否已有内容。
    ///
    /// 说明：非空仓库在桌面端过去只能靠拖放入库，表头没有任何可点击的
    /// 导入入口，用户必须把文件拖进窗口才能补充音频。只要列表有内容，
    /// 表头最右侧就常驻「添加」按钮，且与平台无关（iOS / macOS 一致）。
    static func shouldShowAddButton(hasContent: Bool) -> Bool {
        hasContent
    }

    /// 表头是否展示「打开仓库目录」按钮。
    ///
    /// - Parameter hasContent: 仓库列表是否已有内容。
    ///
    /// 说明：与「添加」按钮同节奏——仓库有内容时常驻表头右侧，方便直接跳到
    /// 访达里的仓库目录；空仓库时改由空状态视图自带的入口承担，表头不重复。
    static func shouldShowOpenRepositoryButton(hasContent: Bool) -> Bool {
        hasContent
    }
}

/// 列表选中项的自动兜底策略。
///
/// 仓库有文件、但用户还没有选择任何文件时，自动选中第一项：
/// 否则列表看上去「有内容却没有任何选中态」，用户无从判断当前播放的是哪一首。
enum AudioListAutoSelectionPolicy {
    /// 是否需要自动选中第一项。
    ///
    /// - Parameters:
    ///   - selection: 当前选中项；已选中时不得覆盖用户的既有选择。
    ///   - currentAsset: 当前播放资源；正在播放时选中态由播放事件驱动。
    ///   - displayedURLs: 已加载到列表中的文件。
    static func shouldAutoSelectFirst(
        selection: URL?,
        currentAsset: URL?,
        displayedURLs: [URL]
    ) -> Bool {
        guard selection == nil, currentAsset == nil else { return false }
        return !displayedURLs.isEmpty
    }

    /// 自动选中的目标：列表第一项。
    static func firstAutoSelectableURL(displayedURLs: [URL]) -> URL? {
        displayedURLs.first
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

    @ObservedObject var viewModel: AudioListViewModel
    let dependencies: AudioDBDependencies
    /// 是否正有文件被拖到仓库视图上方：用于高亮拖放目标。
    var isDropping: Bool = false
    @LumiTheme private var appTheme

    init(viewModel: AudioListViewModel, dependencies: AudioDBDependencies, isDropping: Bool = false) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.dependencies = dependencies
        self.isDropping = isDropping
    }

    var body: some View {
        ZStack {
            if viewModel.isConfirmedRepositoryEmpty {
                AudioDBTips(dependencies: dependencies, variant: .empty, isDropping: isDropping)
            } else {
                audioListView

                if viewModel.isLoading && viewModel.urls.isEmpty {
                    AudioLibrarySkeletonView()
                } else if viewModel.urls.isEmpty && !viewModel.isLoading {
                    AudioDBTips(dependencies: dependencies, variant: .empty, isDropping: isDropping)
                }
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
                if viewModel.totalCount > 0 {
                    Text("Total \(viewModel.totalCount.description)", bundle: .module)
                        .accessibilityIdentifier("cisum.audio-library.count")
                }
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

                // 仓库目录入口：与「添加」按钮并排在表头最右侧，
                // 用户可以直接跳到访达里的音频仓库目录。
                if AudioListHeaderPolicy.shouldShowOpenRepositoryButton(
                    hasContent: viewModel.totalCount > 0 || !viewModel.urls.isEmpty
                ) {
                    BtnOpenRepository(dependencies: dependencies)
                        .font(.title2)
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("cisum.audio-library.open-repository")
                        .accessibilityLabel(Text("Open repository folder", bundle: .module))
                        .help(Text("Open repository folder", bundle: .module))
                }

                // 导入入口：仓库已有内容时，表头最右侧常驻「添加」按钮，
                // 用户点开系统文件选择器即可把文件加入仓库。
                // 桌面端过去只提供拖放，非空仓库没有任何可点击的导入入口。
                if AudioListHeaderPolicy.shouldShowAddButton(
                    hasContent: viewModel.totalCount > 0 || !viewModel.urls.isEmpty
                ) {
                    BtnAdd(dependencies: dependencies)
                        .font(.title2)
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("cisum.audio-library.add")
                        .accessibilityLabel(Text("Add", bundle: .module))
                        .help(Text("Add", bundle: .module))
                }
            }, content: {
                ForEach(Array(viewModel.urls.enumerated()), id: \.element) { index, url in
                    AudioItemView(url, listViewModel: viewModel)
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
