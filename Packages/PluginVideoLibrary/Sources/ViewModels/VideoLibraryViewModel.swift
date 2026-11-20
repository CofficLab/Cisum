import Combine
import Foundation
import ProviderVideo

/// 视频库列表的视图模型。
///
/// 负责：仓库条目的本地副本、筛选（搜索 / 标签 / 收藏）、以及条目操作
/// （播放、收藏、评分、标签、重命名、删除）的转发。
@MainActor
final class VideoLibraryViewModel: ObservableObject {
    /// 仓库中的全部条目。
    @Published private(set) var items: [VideoItem] = []
    /// 仓库状态。
    @Published private(set) var repositoryState: VideoRepositoryState = .idle
    /// 搜索关键字。
    @Published var searchText = ""
    /// 选中的标签（`nil` 表示不筛选）。
    @Published var selectedTag: String?
    /// 只看收藏。
    @Published var favoritesOnly = false
    /// 当前选中的条目（用于弹出编辑面板）。
    @Published var editingItem: VideoItem?
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

    private let repository: VideoLibraryRepositoryCapability
    let playback: VideoLibraryPlaybackCapability
    private var repositoryObserver: (any VideoRepositoryObserverHandle)?
    private var playbackObserver: (any VideoPlaybackObserverHandle)?
    private var lastPersistedAt: Date?

    /// 进度落盘的最小间隔（秒）。
    private static let progressPersistInterval: TimeInterval = 5

    init(repository: VideoLibraryRepositoryCapability, playback: VideoLibraryPlaybackCapability) {
        self.repository = repository
        self.playback = playback
    }

    /// 绑定仓库与播放事件。
    func bind() {
        repositoryObserver?.cancel()
        repositoryObserver = repository.addObserver { [weak self] _ in
            self?.reload()
        }
        playbackObserver?.cancel()
        playbackObserver = playback.addObserver { [weak self] event in
            self?.handlePlaybackEvent(event)
        }
        reload()
    }

    /// 解除绑定。
    func unbind() {
        repositoryObserver?.cancel()
        repositoryObserver = nil
        playbackObserver?.cancel()
        playbackObserver = nil
    }

    /// 从仓库重新读取条目。
    func reload() {
        items = repository.items
        repositoryState = repository.state
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

    /// 筛选后的条目。
    var filteredItems: [VideoItem] {
        items.filter { item in
            if favoritesOnly && !item.isFavorite { return false }
            if let selectedTag, !item.tags.contains(selectedTag) { return false }
            let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !keyword.isEmpty else { return true }
            return item.title.localizedCaseInsensitiveContains(keyword)
                || item.relativePath.localizedCaseInsensitiveContains(keyword)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(keyword) }
        }
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

    // MARK: - Playback

    /// 播放某个视频；有进度时从上次位置继续。
    func play(_ item: VideoItem) {
        let startTime = item.progress.position > 5 ? item.progress.position : nil
        playback.play(item.url, startTime: startTime)
    }

    /// 切换播放 / 暂停。
    func togglePlayback() {
        playback.toggle()
    }

    /// 播放列表中的下一个 / 上一个。
    func playNeighbor(offset: Int) {
        let list = filteredItems
        guard !list.isEmpty else { return }
        guard let current = playback.currentURL,
              let index = list.firstIndex(where: { $0.url == current }) else {
            play(list[0])
            return
        }
        let next = (index + offset + list.count) % list.count
        play(list[next])
    }

    /// 跳转到指定位置。
    func seek(to time: TimeInterval) {
        playback.seek(to: time)
    }

    /// 切换倍速。
    func cycleRate() {
        let rates: [Float] = [1, 1.25, 1.5, 2, 0.5]
        let current = playback.rate
        let next = rates.first { $0 > current } ?? rates[0]
        playback.setRate(next)
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

    func rename(_ item: VideoItem, to newName: String) throws {
        try repository.rename(item.url, to: newName)
    }

    func delete(_ item: VideoItem) throws {
        try repository.delete(item.url)
    }

    // MARK: - Repository actions

    func refresh() { repository.refresh() }

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
