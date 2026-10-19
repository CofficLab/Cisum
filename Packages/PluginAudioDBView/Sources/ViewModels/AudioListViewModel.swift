import ProviderAudioLibrary
import Combine
import Foundation
import OSLog
import SwiftUI
import MagicKit
import ProviderToast
import ProviderPlayback

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
    nonisolated static let verbose = false

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
    @Published private(set) var hasSuccessfullyLoadedRepository = false

    /// 下载进度状态源。
    ///
    /// 独立于本 ViewModel 发布：进度环子视图只观察这个容器，下载进度变化
    /// 因此不会让列表本体重算，也不受 `AudioList` 上 `.equatable()` 的短路影响。
    let downloadStore = CloudDownloadProgressStore()

    /// 下载能力（Capabilities 目录收窄），`weak` 持有：Provider 可能尚未注册。
    private weak var download: (any CloudDownloadCapability)?

    /// 读取某条目的下载进度。
    ///
    /// 无事件记录时回落到能力快照，使「订阅建立前就已在下载」的条目也能正确显示。
    func downloadProgress(for url: URL) -> Double {
        downloadStore.progress(for: url) { [weak self] in
            guard let self, let download = self.download else { return 1 }
            return download.progress(for: url)
        }
    }

    /// 接收 Observer 转发的下载进度。
    func applyDownloadProgress(url: URL, progress: Double) {
        downloadStore.apply(url, progress: progress)
    }

    var isConfirmedRepositoryEmpty: Bool {
        hasSuccessfullyLoadedRepository && !isLoading && totalCount == 0 && urls.isEmpty
    }

    private var loadGeneration = 0
    private var selectionGeneration = 0

    /// 音频库能力（Capabilities 目录收窄），内部惰性解析 Provider。
    private let library: any AudioLibraryCapability
    /// 播放与提示能力（Capabilities 目录收窄），`weak` 持有。
    private weak var playback: (any AudioLibraryPlaybackCapability)?
    private var currentAsset: URL?
    private let reasonTag: String
    private let isDesktop: Bool
    private weak var toast: (any AudioLibraryToastCapability)?

    /// 存储配置状态（Capabilities 目录收窄）。仅用于区分「首启尚未配置存储」
    /// 与「仓库真的打不开」：前者必须静默，否则模态错误弹窗会盖住首启引导。
    private let storage: (any AudioLibraryStorageCapability)?

    init(
        library: any AudioLibraryCapability,
        playback: (any AudioLibraryPlaybackCapability)? = nil,
        download: (any CloudDownloadCapability)? = nil,
        reasonTag: String = "AudioListViewModel",
        isDesktop: Bool? = nil,
        toast: (any AudioLibraryToastCapability)? = nil,
        storage: (any AudioLibraryStorageCapability)? = nil
    ) {
        self.library = library
        self.playback = playback
        self.download = download
        self.reasonTag = reasonTag
        self.isDesktop = isDesktop ?? Self.defaultIsDesktop
        self.toast = toast
        self.storage = storage
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

            guard let playback else {
                os_log(.error, "\(Self.t)4/5 播放能力缺失，无法播放：\(url.path)")
                return
            }

            if Self.verbose {
                os_log("\(Self.t)4/5 调用播放能力 play：\(url.path)")
            }
            await playback.play(url)
            if Self.verbose {
                os_log("\(Self.t)5/5 播放能力 play 已返回：\(url.lastPathComponent)")
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
            toast?.error(String(localized: "Delete failed: the audio list changed. Please try again.", bundle: .module))
            return
        }

        Task { @MainActor in
            guard library.isAvailable else {
                toast?.error(String(localized: "Delete failed: audio repository is unavailable", bundle: .module))
                return
            }
            await deleteFiles(urlsToDelete, in: library)
        }
    }

    /// 删除单个文件（列表项上下文菜单）。
    func deleteFile(_ url: URL) {
        Task { @MainActor in
            guard library.isAvailable else {
                toast?.error(String(localized: "Delete failed: audio repository is unavailable", bundle: .module))
                return
            }
            await deleteFiles([url], in: library)
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
            downloadStore.remove(urlsToDelete)

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

    /// Storage configuration changed; re-open the repository instead of leaving
    /// the first-run unavailable state cached in the list.
    ///
    /// 换存储根意味着旧路径下的文件身份全部失效，因此走
    /// `refreshWithInvalidatedFiles`，而不是普通的列表刷新。
    func handleRepositoryAvailabilityChanged() {
        refreshWithInvalidatedFiles(reason: "Repository availability changed")
    }

    // MARK: - Loading

    /// 加载首页。
    private func loadInitial() {
        guard !isLoading else { return }

        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        hasSuccessfullyLoadedRepository = false

        Task { @MainActor in
            guard library.isAvailable else {
                // During first-run onboarding there is intentionally no storage
                // root yet. The welcome gate explains the required action; a
                // generic repository error toast is a modal notice that would
                // cover the guide and swallow its taps, so stay silent until a
                // storage location actually exists.
                isLoading = false
                hasSuccessfullyLoadedRepository = false
                presentLoadFailureIfNeeded()
                return
            }

            let pageSize = self.pageSize
            Task.detached(priority: .background) {
                // 仅 UI 测试注入：把首屏结果延后返回，让骨架屏有稳定观测窗口。
                if let delay = AudioLibraryLoadDelayControl.firstPageDelay() {
                    try? await Task.sleep(for: .seconds(delay))
                }

                let count = await self.library.totalCount()
                let urls = await self.library.urls(
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
                    self.hasSuccessfullyLoadedRepository = true
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
            guard library.isAvailable else {
                isLoadingMore = false
                presentLoadFailureIfNeeded()
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
                let newUrls = await self.library.urls(
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

    /// 全量重置并刷新，且**文件身份已失效**（存储位置切换）。
    ///
    /// 这是唯一会连带清空文件级旁路状态的场景：换了存储根之后，旧路径下的进度
    /// 与文件大小记录指向的是别处的、甚至不存在的对象，继续保留才是错的。
    private func refreshWithInvalidatedFiles(reason: String) {
        AudioItemFileSizeCache.removeAll()
        downloadStore.removeAll()

        resetListState(reason: reason)
    }

    /// 全量重置并刷新，**文件级状态继续有效**（排序完成、库内文件数量变化）。
    ///
    /// 刻意**不**清空 `downloadStore`：下载进度是文件的事实，与列表排布无关。
    /// 在此清空会让每次数据库刷新都丢掉已知进度，迫使上游重新播报，
    /// 表现为进度环闪一下又退回未下载图标。
    private func refresh(reason: String) {
        AudioItemFileSizeCache.removeAll()

        resetListState(reason: reason)
    }

    /// 只重置列表自身的分页与加载状态。
    private func resetListState(reason: String) {
        loadGeneration += 1
        currentPage = 0
        hasMore = true
        urls = []
        isLoading = false
        isLoadingMore = false

        loadInitial()
    }

    /// 重载当前页数据以刷新已加载内容。
    ///
    /// 同 `refresh(reason:)`：数据库 `synced` / `updated` 在 iCloud 下载期间会随
    /// 百分比变化高频触发（`NSMetadataQuery` 把每次进度更新都算作目录变更），
    /// 在此清空进度即等于让进度环以刷新频率反复闪烁。
    private func loadCurrentPageData(reason: String) {
        AudioItemFileSizeCache.removeAll()

        loadGeneration += 1
        let generation = loadGeneration
        let loadingState = AudioListLoadPolicy.loadingStateWhenStartingCurrentPageRefresh(displayedCount: urls.count)
        isLoading = loadingState.isLoading
        isLoadingMore = loadingState.isLoadingMore
        if urls.isEmpty {
            hasSuccessfullyLoadedRepository = false
        }

        Task { @MainActor in
            guard library.isAvailable else {
                isLoading = false
                isLoadingMore = false
                hasSuccessfullyLoadedRepository = false
                presentRefreshFailureIfNeeded()
                return
            }

            Task.detached(priority: .background) {
                let currentCount = await self.urls.count
                let currentTotalCount = await self.totalCount
                let newTotalCount = await self.library.totalCount()

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
                            let refreshedUrls = await self.library.urls(
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
                                self.hasSuccessfullyLoadedRepository = true
                                self.isLoading = false
                                self.isLoadingMore = false
                            }
                        }
                    } else {
                        self.totalCount = newTotalCount
                        self.hasSuccessfullyLoadedRepository = true
                        self.isLoading = false
                        self.isLoadingMore = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// 首次加载失败时按需提示。
    ///
    /// 首启引导尚未配置存储位置时静默处理：欢迎层已经在解释原因，而错误弹窗
    /// 是模态遮罩，会盖住引导并吞掉「继续」按钮的点击。
    private func presentLoadFailureIfNeeded() {
        guard AudioRepositoryUnavailablePolicy.shouldPresentErrorNotice(
            hasUsableStorageLocation: storage?.hasUsableStorageLocation ?? false,
            isRepositoryAvailable: false
        ) else { return }
        toast?.error(String(localized: "Load failed: audio repository is unavailable", bundle: .module))
    }

    /// 刷新失败时按需提示，规则同 `presentLoadFailureIfNeeded`。
    private func presentRefreshFailureIfNeeded() {
        guard AudioRepositoryUnavailablePolicy.shouldPresentErrorNotice(
            hasUsableStorageLocation: storage?.hasUsableStorageLocation ?? false,
            isRepositoryAvailable: false
        ) else { return }
        toast?.error(String(localized: "Refresh failed: audio repository is unavailable", bundle: .module))
    }

    private func setSelection(_ newValue: URL?) {
        selection = newValue
    }

    private func deleteFiles(
        _ urlsToDelete: [URL],
        in library: any AudioLibraryCapability
    ) async {
        do {
            try await library.delete(urls: urlsToDelete, verbose: false)
            if AudioDeletePlaybackPolicy.shouldResetDirectlyAfterDelete(
                currentURL: currentAsset,
                deletedURLs: urlsToDelete,
                isPlaybackControllerHandlingDeletion: true
            ) {
                await playback?.reset()
            }
            for url in urlsToDelete {
                toast?.info(String(localized: "Deleted \(url.title)", bundle: .module))
            }
        } catch {
            toast?.error(String(localized: "Delete failed: \(error.localizedDescription)", bundle: .module))
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
