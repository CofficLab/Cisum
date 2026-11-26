import Foundation
import ProviderVideo

/// 侧栏里的一个文件夹（按相对路径聚合，含子文件夹内的视频）。
struct VideoFolder: Identifiable, Hashable {
    /// 相对仓库根目录的路径；根目录为空字符串。
    let path: String
    let name: String

    var id: String { path }
    var isRoot: Bool { path.isEmpty }
    /// 缩进层级（根目录为 0）。
    var depth: Int { path.split(separator: "/").count }
}

/// 视频库的视图模型。
///
/// 负责：仓库条目的本地副本、导航状态（范围 / 文件夹 / 标签 / 搜索 / 排序）、
/// 选中条目（检查器）、播放队列与条目操作（播放、收藏、评分、标签、重命名、删除、导入）。
@MainActor
final class VideoLibraryViewModel: ObservableObject {
    /// 仓库中的全部条目。
    @Published private(set) var items: [VideoItem] = []
    /// 仓库状态。
    @Published private(set) var repositoryState: VideoRepositoryState = .idle
    /// 搜索关键字。
    @Published var searchText = ""
    /// 当前内容范围。
    @Published var scope: VideoLibraryScope = .all
    /// 选中的文件夹（相对路径）；`nil` 表示不按文件夹筛选。
    @Published var selectedFolder: String?
    /// 选中的标签（`nil` 表示不筛选）。
    @Published var selectedTag: String?
    /// 排序方式。
    @Published var sortOrder: VideoSortOrder = .recentAdded
    /// 展示方式（网格 / 列表）。
    @Published var displayMode: VideoLibraryDisplayMode = .grid
    /// 检查器中展示的条目。
    @Published var selectedItem: VideoItem?
    /// 当前展开的编辑条目。
    @Published var editingItem: VideoItem?
    /// 是否展示沉浸式播放器。
    @Published var isPlayerPresented = false
    /// 是否展示播放队列。
    @Published var isQueuePresented = false
    /// 当前播放状态。
    @Published private(set) var playbackState: VideoPlaybackState = .idle
    /// 当前播放位置。
    @Published private(set) var currentTime: TimeInterval = 0
    /// 当前媒体时长。
    @Published private(set) var duration: TimeInterval = 0
    /// 当前播放进度（0...1）。
    @Published private(set) var progress: Double = 0
    /// 当前倍速。
    @Published private(set) var rate: Float = 1
    /// 最近一次操作失败的原因。
    @Published var errorMessage: String?

    private let repository: VideoLibraryRepositoryCapability
    let playback: VideoLibraryPlaybackCapability
    private var repositoryObserver: (any VideoRepositoryObserverHandle)?
    private var playbackObserver: (any VideoPlaybackObserverHandle)?
    private var lastPersistedAt: Date?

    /// 进度落盘的最小间隔（秒）。
    private static let progressPersistInterval: TimeInterval = 5
    /// 「最近添加」的时间窗口（秒）。
    static let recentlyAddedWindow: TimeInterval = 30 * 24 * 60 * 60

    init(repository: VideoLibraryRepositoryCapability, playback: VideoLibraryPlaybackCapability) {
        self.repository = repository
        self.playback = playback
    }

    /// 绑定仓库与播放事件。
    func bind() {
        repositoryObserver?.cancel()
        repositoryObserver = repository.addObserver { [weak self] _ in
            Task { @MainActor in
                self?.reload()
            }
        }
        playbackObserver?.cancel()
        playbackObserver = playback.addObserver { [weak self] event in
            Task { @MainActor in
                self?.handlePlaybackEvent(event)
            }
        }
        reload()
        syncPlaybackState()
    }

    /// 解除绑定。
    func unbind() {
        repositoryObserver?.cancel()
        repositoryObserver = nil
        playbackObserver?.cancel()
        playbackObserver = nil
    }

    /// 从仓库重新读取条目，并让选中条目跟随最新数据。
    func reload() {
        items = repository.items
        repositoryState = repository.state
        let wasSelected = selectedItem != nil
        if let url = selectedItem?.url, let updated = items.first(where: { $0.url == url }) {
            selectedItem = updated
            renamedURL = nil
        } else if let renamedURL, let renamed = items.first(where: { $0.url == renamedURL }) {
            selectedItem = renamed
            self.renamedURL = nil
        } else if wasSelected {
            // 仓库尚未反映出重命名时先清空选中；`renamedURL` 留待下一次刷新再认领。
            selectedItem = nil
        }
    }

    /// 重命名后的新文件地址：仓库刷新时让检查器跟随过去。
    private var renamedURL: URL?

    // MARK: - Navigation

    /// 选中某个范围，并退出文件夹导航。
    func select(_ scope: VideoLibraryScope) {
        self.scope = scope
        selectedFolder = nil
    }

    /// 选中某个文件夹；再次点击同一个则回到当前范围。
    func select(folder: VideoFolder?) {
        guard let folder, selectedFolder != folder.path else {
            selectedFolder = nil
            return
        }
        selectedFolder = folder.path
    }

    /// 选中条目（检查器）；传入 `nil` 取消选中。
    func select(_ item: VideoItem?) {
        selectedItem = item
    }

    func clearSelection() {
        selectedItem = nil
    }

    // MARK: - Filtering

    /// 全部标签（去重、按字典序）。
    var allTags: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in items {
            for tag in item.tags where !seen.contains(tag) {
                seen.insert(tag)
                result.append(tag)
            }
        }
        return result.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// 侧栏可导航的文件夹（根目录与各级祖先，含层级），按路径排序。
    var folders: [VideoFolder] {
        var paths = Set<String>()
        for item in items {
            let parts = item.folderPath.split(separator: "/").map(String.init)
            guard !parts.isEmpty else {
                paths.insert("")
                continue
            }
            for depth in 1...parts.count {
                paths.insert(parts.prefix(depth).joined(separator: "/"))
            }
        }
        return paths
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { VideoFolder(path: $0, name: $0.split(separator: "/").last.map(String.init) ?? "") }
    }

    /// 文件夹内的视频数量（含子文件夹）。
    func count(in folder: VideoFolder) -> Int {
        items.count { folderMatches($0, folder: folder) }
    }

    /// 条目是否属于文件夹（含子文件夹）。
    func folderMatches(_ item: VideoItem, folder: VideoFolder) -> Bool {
        if folder.isRoot { return item.folderPath.isEmpty }
        return item.folderPath == folder.path || item.folderPath.hasPrefix(folder.path + "/")
    }

    /// 处于「未看完」状态的条目（按最后播放时间倒序）。
    var continueWatchingItems: [VideoItem] {
        items
            .filter(\.isInProgress)
            .sorted {
                ($0.progress.lastPlayedAt ?? .distantPast) > ($1.progress.lastPlayedAt ?? .distantPast)
            }
    }

    /// 最近添加的条目（按文件修改时间倒序）。
    var recentlyAddedItems: [VideoItem] {
        items
            .filter { Self.isRecentlyAdded($0) }
            .sorted {
                ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast)
            }
    }

    /// 条目是否落在「最近添加」窗口内。
    static func isRecentlyAdded(_ item: VideoItem, now: Date = Date()) -> Bool {
        guard let modifiedAt = item.modifiedAt else { return false }
        let age = now.timeIntervalSince(modifiedAt)
        return age >= 0 && age <= recentlyAddedWindow
    }

    /// 各内容范围的条目数量（用于侧栏计数）。
    func count(for scope: VideoLibraryScope) -> Int {
        switch scope {
        case .all: items.count
        case .favorites: items.count { $0.isFavorite }
        case .continueWatching: continueWatchingItems.count
        case .undownloaded: items.count { $0.availability == .cloudNotDownloaded }
        case .recentlyAdded: recentlyAddedItems.count
        }
    }

    private func isInScope(_ item: VideoItem, scope: VideoLibraryScope) -> Bool {
        switch scope {
        case .all: true
        case .favorites: item.isFavorite
        case .continueWatching: item.isInProgress
        case .undownloaded: item.availability == .cloudNotDownloaded
        case .recentlyAdded: Self.isRecentlyAdded(item)
        }
    }

    /// 是否处于无筛选的「全部视频」视图（此时才展示「继续观看」横栏）。
    var showsContinueWatchingRail: Bool {
        scope == .all && selectedFolder == nil && selectedTag == nil
            && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 筛选后的条目（已排序）。
    var filteredItems: [VideoItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = items.filter { item in
            guard isInScope(item, scope: scope) else { return false }
            if let selectedFolder {
                let folder = VideoFolder(path: selectedFolder, name: "")
                guard folderMatches(item, folder: folder) else { return false }
            }
            if let selectedTag, !item.tags.contains(selectedTag) { return false }
            guard !keyword.isEmpty else { return true }
            return item.title.localizedCaseInsensitiveContains(keyword)
                || item.relativePath.localizedCaseInsensitiveContains(keyword)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(keyword) }
        }
        return sorted(matched)
    }

    /// 按当前排序方式排序。
    private func sorted(_ list: [VideoItem]) -> [VideoItem] {
        switch sortOrder {
        case .recentAdded:
            return list.sorted {
                ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast)
            }
        case .name:
            return list.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .duration:
            return list.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
        case .rating:
            return list.sorted {
                ($0.rating?.value ?? 0) > ($1.rating?.value ?? 0)
            }
        case .lastPlayed:
            return list.sorted {
                ($0.progress.lastPlayedAt ?? .distantPast) > ($1.progress.lastPlayedAt ?? .distantPast)
            }
        }
    }

    /// 当前是否有生效的筛选条件。
    var hasActiveFilters: Bool {
        scope != .all || selectedFolder != nil || selectedTag != nil
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 清除全部筛选条件。
    func clearFilters() {
        scope = .all
        selectedFolder = nil
        selectedTag = nil
        searchText = ""
    }

    /// 当前导航位置的标题（范围名或文件夹名）。
    var navigationTitle: String {
        if let selectedFolder, !selectedFolder.isEmpty {
            return selectedFolder.split(separator: "/").last.map(String.init) ?? selectedFolder
        }
        return scope == .all ? "All Videos" : scope.title
    }

    /// 当前正在播放的条目。
    var currentItem: VideoItem? {
        guard let url = playback.currentURL else { return nil }
        return items.first { $0.url == url }
    }

    /// 当前仓库根目录。
    var repositoryURL: URL? {
        repository.repositoryURL
    }

    /// 存储位置标题（`iCloud` / `Local`）；未配置时为空。
    var storageLocationTitle: String {
        repository.storageLocationTitle
    }

    /// 当前筛选结果的总大小文案（标题摘要）。
    var totalSizeTitle: String {
        let total = filteredItems.reduce(Int64(0)) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    /// 全部视频的总大小文案（存储卡片）。
    var librarySizeTitle: String {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    // MARK: - Playback

    /// 播放本地可用的视频并进入沉浸播放；有进度时从上次位置继续。
    func play(_ item: VideoItem) {
        selectedItem = item
        switch item.availability {
        case .available:
            playback.play(item.url, startTime: item.resumePosition)
            isPlayerPresented = true
        case .cloudNotDownloaded:
            requestDownload(item)
        case .cloudDownloading, .unavailable(_):
            break
        }
    }

    /// 从头开始播放。
    func playFromBeginning(_ item: VideoItem) {
        guard item.availability == .available else { return }
        selectedItem = item
        playback.play(item.url, startTime: nil)
        isPlayerPresented = true
    }

    /// 展开沉浸播放器。
    func presentPlayer() {
        guard playback.hasAsset else { return }
        isPlayerPresented = true
    }

    func dismissPlayer() {
        isPlayerPresented = false
        isQueuePresented = false
    }

    /// 停止播放并收起播放器。
    func stopPlayback() {
        dismissPlayer()
        playback.stop()
    }

    /// 切换播放 / 暂停。
    func togglePlayback() {
        playback.toggle()
    }

    /// 相对当前快进 / 快退。
    func seekRelative(_ offset: TimeInterval) {
        let target = min(max(currentTime + offset, 0), max(duration, 0))
        seek(to: target)
    }

    /// 播放队列中的下一个 / 上一个。
    func playNeighbor(offset: Int) {
        let list = playbackQueue
        guard !list.isEmpty else { return }
        guard let current = playback.currentURL,
              let index = list.firstIndex(where: { $0.url == current }) else {
            play(list[0])
            return
        }
        let next = (index + offset + list.count) % list.count
        play(list[next])
    }

    /// 播放队列（当前筛选结果）。
    var playbackQueue: [VideoItem] {
        filteredItems.filter { $0.availability == .available }
    }

    /// 跳转到指定位置。
    func seek(to time: TimeInterval) {
        playback.seek(to: time)
    }

    /// 设置倍速。
    func setRate(_ rate: Float) {
        playback.setRate(rate)
    }

    /// 可选倍速档位。
    static let rateOptions: [Float] = [0.5, 1, 1.25, 1.5, 2, 3]

    /// 按档位循环切换倍速。
    func cycleRate() {
        let rates = Self.rateOptions
        let current = playback.rate
        let next = rates.first { $0 > current + 0.01 } ?? rates[0]
        playback.setRate(next)
    }

    var isPlaying: Bool {
        playbackState == .playing
    }

    // MARK: - Item actions

    func toggleFavorite(_ item: VideoItem) {
        repository.setFavorite(!item.isFavorite, for: item.url)
    }

    func setRating(_ rating: Int?, for item: VideoItem) {
        repository.setRating(rating, for: item.url)
    }

    func setTags(_ tags: [String], for item: VideoItem) {
        repository.setTags(tags, for: item.url)
    }

    /// 给条目追加一个标签；已存在或为空时不写入。
    func addTag(_ tag: String, to item: VideoItem) {
        let normalized = VideoTagSupport.normalizedTags(from: tag)
        guard let newTag = normalized.first, !item.tags.contains(newTag) else { return }
        setTags(item.tags + [newTag], for: item)
    }

    /// 移除条目的一个标签。
    func removeTag(_ tag: String, to item: VideoItem) {
        setTags(item.tags.filter { $0 != tag }, for: item)
    }

    func rename(_ item: VideoItem, to newName: String) throws {
        try repository.rename(item.url, to: newName)
        let renamed = item.url.deletingLastPathComponent()
            .appendingPathComponent(newName)
            .appendingPathExtension(item.url.pathExtension)
        renamedURL = renamed
    }

    func delete(_ item: VideoItem) throws {
        try repository.delete(item.url)
        if selectedItem?.url == item.url {
            selectedItem = nil
        }
    }

    /// 请求从 iCloud 下载尚未下载的文件。
    func requestDownload(_ item: VideoItem) {
        repository.requestDownload(for: item.url)
    }

    // MARK: - Repository actions

    func refresh() { repository.refresh() }

    /// 导入外部视频文件。
    func importVideos(from urls: [URL]) {
        do {
            try repository.importVideos(from: urls)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func handlePlaybackEvent(_ event: VideoPlaybackEvent) {
        syncPlaybackState()
        switch event {
        case .timeChanged:
            persistProgress(force: false)
        case .assetChanged:
            persistProgress(force: true)
        case .stateChanged(let state):
            switch state {
            case .paused, .finished, .failed:
                persistProgress(force: true)
            case .idle, .loading, .playing:
                break
            }
        case .rateChanged, .didFinish:
            persistProgress(force: true)
        }
    }

    /// 把底层播放状态同步到视图模型。
    private func syncPlaybackState() {
        playbackState = playback.state
        currentTime = playback.currentTime
        duration = playback.duration
        progress = playback.progress
        rate = playback.rate
    }

    /// 写入播放进度。
    ///
    /// 进度事件每 0.5 秒一次，直接落盘会频繁重写元数据文件；因此按间隔
    /// 节流，暂停/停止/切源等关键节点则立即落盘。
    private func persistProgress(force: Bool) {
        guard let url = playback.currentURL else { return }
        let now = Date()
        if !force, let last = lastPersistedAt, now.timeIntervalSince(last) < Self.progressPersistInterval {
            return
        }
        lastPersistedAt = now

        let existing = items.first { $0.url == url }?.progress
        let playCount = existing?.playCount ?? 0
        let progress = VideoPlaybackProgress(
            position: playback.currentTime,
            duration: playback.duration,
            playCount: playCount,
            lastPlayedAt: now
        )
        repository.updateProgress(progress, for: url)
    }
}
