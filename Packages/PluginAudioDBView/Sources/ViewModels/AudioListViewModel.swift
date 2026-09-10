import Combine
import Foundation
import OSLog
import ProviderAudioLibrary
import SwiftUI
import MagicKit

/// 音频库列表的加载状态容器（迁移 Phase 2）。
///
/// 集中管理 `AudioList` 的加载、分页、选中项刷新、删除回读与数据库事件处理；
/// 由插件入口持有并注入 `AudioDatabaseObserver`，View 只展示与发意图，
/// 不再直接订阅数据库通知或读取 Repository。
///
/// 数据加载策略/删除策略/选择策略等纯函数保留在 View 文件
/// （`AudioListLoadPolicy` / `AudioListDeletionPolicy` / `AudioListSelectionPolicy`），
/// 本 ViewModel 仅调用它们，保证行为不变。
@MainActor
final class AudioListViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = true

    /// 当前选中项；由外部播放事件和用户选择共同驱动，但只有用户选择会发出播放命令。
    @Published private(set) var selection: URL?
    @Published private(set) var urls: [URL] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = true
    @Published private(set) var currentPage = 0
    @Published private(set) var pageSize = 50
    @Published private(set) var isSyncing = false
    @Published private(set) var totalCount = 0

    private var loadGeneration = 0
    private var selectionGeneration = 0

    private let audioRepoProvider: @MainActor () async -> AudioRepo?
    /// AudioDB 所需的最小播放能力；不让 ViewModel 反向访问 Kernel。
    private let playbackCapability: (any AudioPlaybackCapability)?
    private var currentAsset: URL?
    private let reasonTag: String
    private let isDesktop: Bool

    init(
        audioRepo: @escaping @MainActor () async -> AudioRepo?,
        playbackCapability: (any AudioPlaybackCapability)? = nil,
        reasonTag: String = "AudioListViewModel",
        isDesktop: Bool? = nil
    ) {
        self.audioRepoProvider = audioRepo
        self.playbackCapability = playbackCapability
        self.reasonTag = reasonTag
        self.isDesktop = isDesktop ?? Self.defaultIsDesktop
    }

    /// 非桌面平台（用于显示「添加」按钮等布局差异）。
    var isNotDesktop: Bool { !isDesktop }

    private static var defaultIsDesktop: Bool {
        #if os(macOS)
            true
        #else
            false
        #endif
    }

    // MARK: - User intent

    /// 视图出现：加载首页并恢复当前播放选中项。
    func handleOnAppear() {
        loadInitial()

        if let asset = currentAsset {
            setSelection(asset)
        }
    }

    /// 将列表选中写操作转换为用户意图；外部播放同步不会经过这里。
    var selectionBinding: Binding<URL?> {
        Binding(
            get: { [weak self] in self?.selection },
            set: { [weak self] url in
                if Self.verbose {
                    os_log("\(Self.t)🖱️ List.selection setter: \(url?.lastPathComponent ?? "nil")")
                }
                // List may invoke the binding setter while SwiftUI is updating
                // the view hierarchy. Defer the published-state mutation until
                // that update has completed.
                DispatchQueue.main.async {
                    self?.userSelected(url)
                }
            }
        )
    }

    /// 用户选中某一项：更新选中状态并请求内核播放。
    func userSelected(_ url: URL?) {
        if Self.verbose {
            os_log(
                "\(Self.t)1/5 userSelected url=\(url?.lastPathComponent ?? "nil") loading=\(self.isLoading) displayed=\(self.urls.count)"
            )
        }

        guard let url, !isLoading else {
            os_log(.error, "\(Self.t)2/5 Selection rejected: URL is nil or list is loading")
            selectionGeneration += 1
            return
        }

        guard urls.contains(where: { AudioListSelectionPolicy.representsSameAudio($0, url) }) else {
            os_log(.error, "\(Self.t)2/5 Selection rejected: URL is not in displayed list: \(url.path)")
            return
        }

        selection = url
        if Self.verbose {
            os_log("\(Self.t)2/5 Selection accepted: \(url.lastPathComponent)")
        }
        guard !AudioListSelectionPolicy.representsSameAudio(url, currentAsset) else {
            if Self.verbose {
                os_log("\(Self.t)3/5 Same asset already loaded; playback command skipped: \(url.lastPathComponent)")
            }
            return
        }

        selectionGeneration += 1
        let generation = selectionGeneration
        if Self.verbose {
            os_log("\(Self.t)3/5 Scheduling playback request generation=\(generation): \(url.lastPathComponent)")
        }

        Task { @MainActor in
            guard AudioListSelectionPolicy.shouldApplySelection(
                currentGeneration: selectionGeneration,
                requestGeneration: generation,
                requestedURL: url,
                selection: selection,
                displayedURLs: urls
            ) else {
                os_log(
                    .error,
                    "\(Self.t)4/5 Playback request discarded generation=\(generation) currentGeneration=\(self.selectionGeneration) selected=\(self.selection?.lastPathComponent ?? "nil") displayed=\(self.urls.contains(where: { AudioListSelectionPolicy.representsSameAudio($0, url) }))"
                )
                return
            }

            guard let playbackCapability = self.playbackCapability else {
                os_log(.error, "\(Self.t)4/5 Playback capability is missing; cannot play: \(url.path)")
                return
            }

            if Self.verbose {
                os_log("\(Self.t)4/5 Calling AudioPlaybackCapability.play: \(url.path)")
            }
            await playbackCapability.play(url)
            if Self.verbose {
                os_log("\(Self.t)5/5 AudioPlaybackCapability.play returned: \(url.lastPathComponent)")
            }
        }
    }

    /// 播放器资产变化：只同步选中项，不再次发出播放命令。
    func applyExternalPlayback(url: URL?) {
        if Self.verbose {
            os_log("\(Self.t)🔄 External playback asset changed: \(url?.path ?? "nil")")
        }
        currentAsset = url
        if let asset = url {
            if !AudioListSelectionPolicy.representsSameAudio(asset, selection) {
                setSelection(asset)
            }
        } else {
            setSelection(nil)
        }
    }

    /// 滚动接近底部时加载更多。
    func checkLoadMore(at index: Int) {
        guard AudioListLoadPolicy.shouldLoadMore(
            currentIndex: index,
            loadedCount: urls.count,
            hasMore: hasMore,
            isLoadingMore: isLoadingMore
        ) else { return }
        loadMore()
    }

    /// 用户从列表删除条目（滑动删除）。
    func deleteItems(at offsets: IndexSet) {
        guard let urlsToDelete = Self.urlsToDelete(from: offsets, in: urls) else {
            alert_error(String(localized: "Delete failed: the audio list changed. Please try again.", bundle: .module))
            return
        }

        Task { @MainActor in
            guard let repo = await audioRepoProvider() else {
                alert_error(String(localized: "Delete failed: audio repository is unavailable", bundle: .module))
                return
            }
            await deleteFiles(urlsToDelete, in: repo)
        }
    }

    /// 删除单个文件（列表项上下文菜单）。
    func deleteFile(_ url: URL) {
        Task { @MainActor in
            guard let repo = await audioRepoProvider() else {
                alert_error(String(localized: "Delete failed: audio repository is unavailable", bundle: .module))
                return
            }
            await deleteFiles([url], in: repo)
        }
    }

    // MARK: - Database events (Observer → ViewModel)

    /// 数据库同步完成。
    func handleDBSynced() {
        refreshCurrentPage(reason: "handleDBSynced")
        isSyncing = false
    }

    /// 数据库同步开始。
    func handleDBSyncing() {
        isSyncing = true
    }

    /// 数据库更新（文件新增等）。
    func handleDBUpdated() {
        refreshCurrentPage(reason: "handleDBUpdated")
        isSyncing = false
    }

    /// 数据库删除。
    func handleDBDeleted(urlsToDelete: [URL]) {
        guard !urlsToDelete.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            loadGeneration = AudioListLoadPolicy.generationAfterDeletingDisplayedItems(loadGeneration)
            isLoading = false
            isLoadingMore = false
            AudioItemFileSizeCache.remove(urlsToDelete)

            urls.removeAll { url in
                AudioListDeletionPolicy.shouldRemove(url, deletedURLs: urlsToDelete)
            }

            totalCount = AudioListDeletionPolicy.totalCountAfterDeletion(
                currentTotal: totalCount,
                deletedURLs: urlsToDelete
            )
            currentPage = AudioListLoadPolicy.currentPageAfterDeletingDisplayedItems(
                remainingDisplayedCount: urls.count,
                pageSize: pageSize
            )
            hasMore = totalCount > urls.count

            if let selected = selection,
               AudioListDeletionPolicy.shouldRemove(selected, deletedURLs: urlsToDelete) {
                selection = nil
            }
        }
    }

    /// 数据库排序完成：全量刷新。
    func handleDBSortDone() {
        refresh(reason: "handleDBSortDone")
    }

    // MARK: - Loading

    /// 加载首页。
    private func loadInitial() {
        guard !isLoading else { return }

        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true

        Task { @MainActor in
            guard let repo = await audioRepoProvider() else {
                isLoading = false
                alert_error(String(localized: "Load failed: audio repository is unavailable", bundle: .module))
                return
            }

            let pageSize = self.pageSize
            Task.detached(priority: .background) {
                let count = await repo.getTotalCount()
                let urls = await repo.get(
                    offset: 0,
                    limit: pageSize,
                    reason: self.reasonTag
                )

                await MainActor.run {
                    guard !AudioListLoadPolicy.shouldKeepLoadingStateWhenDiscardingStaleResult(
                        currentGeneration: self.loadGeneration,
                        resultGeneration: generation
                    ) else {
                        return
                    }
                    self.urls = urls
                    self.totalCount = count
                    self.currentPage = 1
                    self.hasMore = urls.count == pageSize
                    self.isLoading = false
                }
            }
        }
    }

    /// 加载更多。
    private func loadMore() {
        guard !isLoadingMore, hasMore else { return }

        isLoadingMore = true
        let generation = loadGeneration

        Task { @MainActor in
            guard let repo = await audioRepoProvider() else {
                isLoadingMore = false
                alert_error(String(localized: "Load failed: audio repository is unavailable", bundle: .module))
                return
            }

            let pageSize = self.pageSize
            let currentPage = self.currentPage
            let existingUrls = self.urls
            let offset = AudioListLoadPolicy.nextLoadOffset(
                loadedCount: existingUrls.count,
                currentPage: currentPage,
                pageSize: pageSize
            )

            Task.detached(priority: .background) {
                let newUrls = await repo.get(
                    offset: offset,
                    limit: pageSize,
                    reason: self.reasonTag
                )

                let uniqueNewUrls = AudioListLoadPolicy.uniqueAdditionalURLs(
                    existingURLs: existingUrls,
                    newURLs: newUrls
                )

                await MainActor.run {
                    guard !AudioListLoadPolicy.shouldKeepLoadingStateWhenDiscardingStaleResult(
                        currentGeneration: self.loadGeneration,
                        resultGeneration: generation
                    ) else {
                        return
                    }
                    if !uniqueNewUrls.isEmpty {
                        self.urls.append(contentsOf: uniqueNewUrls)
                    }
                    self.hasMore = AudioListLoadPolicy.hasMoreAfterLoading(
                        fetchedCount: newUrls.count,
                        pageSize: self.pageSize
                    )
                    self.currentPage = AudioListLoadPolicy.pageAfterLoading(
                        currentPage: self.currentPage,
                        fetchedCount: newUrls.count
                    )
                    self.isLoadingMore = false
                }
            }
        }
    }

    /// 刷新当前页，保留分页状态。
    private func refreshCurrentPage(reason: String) {
        loadCurrentPageData(reason: reason)
    }

    /// 全量重置并刷新。
    private func refresh(reason: String) {
        AudioItemFileSizeCache.removeAll()

        loadGeneration += 1
        currentPage = 0
        hasMore = true
        urls = []
        isLoading = false
        isLoadingMore = false

        loadInitial()
    }

    /// 重载当前页数据以刷新已加载内容。
    private func loadCurrentPageData(reason: String) {
        AudioItemFileSizeCache.removeAll()

        loadGeneration += 1
        let generation = loadGeneration
        let loadingState = AudioListLoadPolicy.loadingStateWhenStartingCurrentPageRefresh(displayedCount: urls.count)
        isLoading = loadingState.isLoading
        isLoadingMore = loadingState.isLoadingMore

        Task { @MainActor in
            guard let repo = await audioRepoProvider() else {
                alert_error(String(localized: "Refresh failed: audio repository is unavailable", bundle: .module))
                return
            }

            Task.detached(priority: .background) {
                let currentCount = await self.urls.count
                let currentTotalCount = await self.totalCount
                let newTotalCount = await repo.getTotalCount()

                await MainActor.run {
                    guard AudioListLoadPolicy.shouldApplyResult(
                        currentGeneration: self.loadGeneration,
                        resultGeneration: generation
                    ) else { return }

                    if newTotalCount > currentTotalCount {
                        self.refresh(reason: "New files - \(reason)")
                        return
                    }

                    if newTotalCount < currentTotalCount {
                        self.refresh(reason: "Deleted files - \(reason)")
                        return
                    }

                    if currentCount > 0 {
                        let currentCount = currentCount
                        let newTotalCount = newTotalCount
                        Task.detached(priority: .background) {
                            let refreshedUrls = await repo.get(
                                offset: 0,
                                limit: currentCount,
                                reason: self.reasonTag
                            )

                            await MainActor.run {
                                guard AudioListLoadPolicy.shouldApplyResult(
                                    currentGeneration: self.loadGeneration,
                                    resultGeneration: generation
                                ) else { return }
                                self.urls = refreshedUrls
                                self.totalCount = newTotalCount
                                self.isLoading = false
                                self.isLoadingMore = false
                            }
                        }
                    } else {
                        self.totalCount = newTotalCount
                        self.isLoading = false
                        self.isLoadingMore = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func setSelection(_ newValue: URL?) {
        selection = newValue
    }

    private func deleteFiles(_ urlsToDelete: [URL], in repo: AudioRepo) async {
        do {
            try await repo.deleteAudios(urlsToDelete)
            if AudioDeletePlaybackPolicy.shouldResetDirectlyAfterDelete(
                currentURL: currentAsset,
                deletedURLs: urlsToDelete,
                isPlaybackControllerHandlingDeletion: true
            ) {
                await playbackCapability?.reset()
            }
            for url in urlsToDelete {
                alert_info(String(localized: "Deleted \(url.title)", bundle: .module))
            }
        } catch {
            alert_error(String(localized: "Delete failed: \(error.localizedDescription)", bundle: .module))
        }
    }

    nonisolated static func urlsToDelete(from offsets: IndexSet, in urls: [URL]) -> [URL]? {
        var urlsToDelete: [URL] = []
        urlsToDelete.reserveCapacity(offsets.count)

        for offset in offsets {
            guard urls.indices.contains(offset) else {
                return nil
            }
            urlsToDelete.append(urls[offset])
        }

        return urlsToDelete
    }
}
