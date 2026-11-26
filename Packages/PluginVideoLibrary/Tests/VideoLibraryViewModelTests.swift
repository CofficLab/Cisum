import Foundation
import ProviderVideo
import SwiftUI
import Testing
@testable import PluginVideoLibrary

/// 视频库视图模型与能力收窄的行为测试。
@MainActor
struct VideoLibraryViewModelTests {
    /// 假的仓库能力来源。
    final class FakeRepositoryProvider: VideoRepositoryProviding {
        var state: VideoRepositoryState = .ready(URL(fileURLWithPath: "/tmp/videos"), 0)
        var repositoryURL: URL? = URL(fileURLWithPath: "/tmp/videos")
        var items: [VideoItem] = []
        var isAvailable = true
        var storageLocationTitle = "iCloud"
        var importedURLs: [URL] = []
        var requestedDownloads: [URL] = []
        var tagUpdates: [(url: URL, tags: [String])] = []

        func refresh() {}
        func updateAvailability(_ availability: VideoAvailability, for url: URL) {}
        func setTags(_ tags: [String], for url: URL) { tagUpdates.append((url, tags)) }
        func setRating(_ rating: Int?, for url: URL) {}
        func setFavorite(_ isFavorite: Bool, for url: URL) {}
        func updateProgress(_ progress: VideoPlaybackProgress, for url: URL) {}
        func rename(_ url: URL, to newName: String) throws {}
        func delete(_ url: URL) throws {}
        func importVideos(from urls: [URL]) throws { importedURLs = urls }
        func requestDownload(for url: URL) { requestedDownloads.append(url) }
        @discardableResult
        func addObserver(_ callback: @escaping (VideoRepositoryEvent) -> Void) -> any VideoRepositoryObserverHandle {
            FakeHandle()
        }
    }

    final class FakeHandle: VideoRepositoryObserverHandle, VideoPlaybackObserverHandle {
        func cancel() {}
    }

    /// 假的播放能力来源。
    final class FakePlaybackProvider: VideoPlaybackProviding {
        var state: VideoPlaybackState = .idle
        var currentURL: URL?
        var currentTime: TimeInterval = 0
        var duration: TimeInterval = 0
        var progress: Double = 0
        var rate: Float = 1
        var hasAsset = false
        var playedURLs: [URL] = []
        var playedStartTimes: [TimeInterval?] = []
        var onSeek: ((TimeInterval) -> Void)?

        func play(_ url: URL, startTime: TimeInterval?) {
            playedURLs.append(url)
            playedStartTimes.append(startTime)
        }
        func pause() {}
        func toggle() {}
        func stop() {}
        func seek(toTime time: TimeInterval) { onSeek?(time) }
        func setRate(_ rate: Float) {}
        func makePlayerView() -> AnyView { AnyView(EmptyView()) }
        @discardableResult
        func addObserver(_ callback: @escaping (VideoPlaybackEvent) -> Void) -> any VideoPlaybackObserverHandle {
            FakeHandle()
        }
    }

    private func makeItem(
        name: String,
        tags: [String] = [],
        isFavorite: Bool = false,
        rating: Int? = nil,
        duration: TimeInterval = 60,
        modifiedAt: Date? = nil,
        progress: VideoPlaybackProgress = .empty,
        availability: VideoAvailability = .available
    ) -> VideoItem {
        VideoItem(
            url: URL(fileURLWithPath: "/tmp/videos/\(name).mp4"),
            relativePath: "\(name).mp4",
            title: name,
            size: 1024,
            modifiedAt: modifiedAt,
            duration: duration,
            tags: tags,
            rating: rating.flatMap(VideoRating.init),
            progress: progress,
            isFavorite: isFavorite,
            availability: availability
        )
    }

    private func makeViewModel(
        provider: FakeRepositoryProvider,
        playback: FakePlaybackProvider? = nil
    ) -> VideoLibraryViewModel {
        let viewModel = VideoLibraryViewModel(
            repository: VideoLibraryRepositoryCapability(repository: provider),
            playback: VideoLibraryPlaybackCapability(playback: playback ?? FakePlaybackProvider())
        )
        viewModel.bind()
        return viewModel
    }

    @Test("标签与收藏筛选生效")
    func filtering() {
        let provider = FakeRepositoryProvider()
        provider.items = [
            makeItem(name: "alpha", tags: ["news"], isFavorite: true),
            makeItem(name: "beta", tags: ["travel"]),
            makeItem(name: "gamma"),
        ]

        let viewModel = makeViewModel(provider: provider)

        #expect(viewModel.items.count == 3)
        #expect(viewModel.allTags == ["news", "travel"])

        viewModel.selectedTag = "news"
        #expect(viewModel.filteredItems.map(\.title) == ["alpha"])

        viewModel.selectedTag = nil
        viewModel.scope = .favorites
        #expect(viewModel.filteredItems.map(\.title) == ["alpha"])

        viewModel.scope = .all
        viewModel.searchText = "amm"
        #expect(viewModel.filteredItems.map(\.title) == ["gamma"])
    }

    @Test("标签规范化去重")
    func tagNormalization() {
        let tags = VideoTagSupport.normalizedTags(from: "news, travel；news\nsports")
        #expect(tags == ["news", "travel", "sports"])
    }

    @Test("范围筛选区分收藏、未下载与继续观看")
    func scopeFiltering() {
        let provider = FakeRepositoryProvider()
        provider.items = [
            makeItem(name: "favorite", isFavorite: true),
            makeItem(name: "cloud", availability: .cloudNotDownloaded),
            makeItem(
                name: "wip",
                progress: VideoPlaybackProgress(position: 120, duration: 600, playCount: 1, lastPlayedAt: Date())
            ),
            makeItem(
                name: "done",
                progress: VideoPlaybackProgress(position: 590, duration: 600, playCount: 1, completedAt: Date())
            ),
        ]

        let viewModel = makeViewModel(provider: provider)

        #expect(viewModel.count(for: .all) == 4)
        #expect(viewModel.count(for: .favorites) == 1)
        #expect(viewModel.count(for: .undownloaded) == 1)
        #expect(viewModel.count(for: .continueWatching) == 1)

        viewModel.scope = .continueWatching
        #expect(viewModel.filteredItems.map(\.title) == ["wip"])
        #expect(viewModel.continueWatchingItems.map(\.title) == ["wip"])
    }

    @Test("排序按当前排序方式生效")
    func sorting() {
        let provider = FakeRepositoryProvider()
        provider.items = [
            makeItem(name: "b", rating: 3, modifiedAt: Date(timeIntervalSince1970: 100)),
            makeItem(name: "a", rating: 5, modifiedAt: Date(timeIntervalSince1970: 300)),
            makeItem(name: "c", rating: 1, modifiedAt: Date(timeIntervalSince1970: 200)),
        ]

        let viewModel = makeViewModel(provider: provider)

        viewModel.sortOrder = .recentAdded
        #expect(viewModel.filteredItems.map(\.title) == ["a", "c", "b"])

        viewModel.sortOrder = .name
        #expect(viewModel.filteredItems.map(\.title) == ["a", "b", "c"])

        viewModel.sortOrder = .rating
        #expect(viewModel.filteredItems.map(\.title) == ["a", "b", "c"])
    }

    @Test("清除筛选恢复全部条目")
    func clearFilters() {
        let provider = FakeRepositoryProvider()
        provider.items = [
            makeItem(name: "alpha", tags: ["news"]),
            makeItem(name: "beta"),
        ]

        let viewModel = makeViewModel(provider: provider)
        viewModel.scope = .favorites
        viewModel.selectedTag = "news"
        viewModel.searchText = "alpha"
        #expect(viewModel.hasActiveFilters)

        viewModel.clearFilters()
        #expect(!viewModel.hasActiveFilters)
        #expect(viewModel.filteredItems.count == 2)
    }

    @Test("绑定时同步已有播放快照")
    func bindSynchronizesPlaybackSnapshot() {
        let provider = FakeRepositoryProvider()
        let playback = FakePlaybackProvider()
        playback.state = .failed("Decoder unavailable")
        playback.currentTime = 12
        playback.duration = 120
        playback.progress = 0.1
        playback.rate = 1.5
        playback.hasAsset = true

        let viewModel = makeViewModel(provider: provider, playback: playback)

        #expect(viewModel.playbackState == .failed("Decoder unavailable"))
        #expect(viewModel.currentTime == 12)
        #expect(viewModel.duration == 120)
        #expect(viewModel.progress == 0.1)
        #expect(viewModel.rate == 1.5)
    }

    @Test("播放时进入沉浸播放器，并从上次位置继续")
    func playbackResumes() {
        let provider = FakeRepositoryProvider()
        let item = makeItem(
            name: "wip",
            progress: VideoPlaybackProgress(position: 90, duration: 600)
        )
        provider.items = [item]

        let playback = FakePlaybackProvider()
        let viewModel = makeViewModel(provider: provider, playback: playback)

        viewModel.play(item)
        #expect(playback.playedURLs == [item.url])
        #expect(playback.playedStartTimes.count == 1)
        #expect(playback.playedStartTimes[0] == 90)
        #expect(viewModel.isPlayerPresented)
        #expect(viewModel.selectedItem?.url == item.url)

        viewModel.dismissPlayer()
        #expect(!viewModel.isPlayerPresented)

        playback.hasAsset = true
        viewModel.presentPlayer()
        #expect(viewModel.isPlayerPresented)
    }

    @Test("从头播放不带上次进度")
    func playFromBeginningIgnoresProgress() {
        let provider = FakeRepositoryProvider()
        let item = makeItem(
            name: "wip",
            progress: VideoPlaybackProgress(position: 90, duration: 600)
        )
        provider.items = [item]

        let playback = FakePlaybackProvider()
        let viewModel = makeViewModel(provider: provider, playback: playback)

        viewModel.playFromBeginning(item)
        #expect(playback.playedStartTimes == [nil])
        #expect(viewModel.isPlayerPresented)
    }

    @Test("相对快进快退被限制在时长范围内")
    func relativeSeekClampsToDuration() {
        let playback = FakePlaybackProvider()
        playback.currentTime = 30
        playback.duration = 100
        let viewModel = makeViewModel(provider: FakeRepositoryProvider(), playback: playback)

        var sought: [TimeInterval] = []
        playback.onSeek = { sought.append($0) }
        viewModel.seekRelative(10)
        viewModel.seekRelative(-100)
        viewModel.seekRelative(500)

        #expect(sought == [40, 0, 100])
    }

    @Test("侧栏列出根目录与各级文件夹，文件夹筛选包含子文件夹")
    func folderNavigation() {
        let provider = FakeRepositoryProvider()
        let root = makeItem(name: "root")
        let nested = VideoItem(
            url: URL(fileURLWithPath: "/tmp/videos/trips/2024/beach.mp4"),
            relativePath: "trips/2024/beach.mp4",
            title: "beach",
            size: 1024,
            modifiedAt: nil,
            duration: 60
        )
        let direct = VideoItem(
            url: URL(fileURLWithPath: "/tmp/videos/trips/city.mp4"),
            relativePath: "trips/city.mp4",
            title: "city",
            size: 1024,
            modifiedAt: nil,
            duration: 60
        )
        provider.items = [nested, root, direct]
        let viewModel = makeViewModel(provider: provider)

        #expect(viewModel.folders.map(\.path) == ["", "trips", "trips/2024"])
        #expect(viewModel.folders.map(\.depth) == [0, 1, 2])
        #expect(viewModel.folders[0].isRoot)

        let trips = viewModel.folders[1]
        viewModel.select(folder: trips)
        #expect(viewModel.filteredItems.map(\.title) == ["beach", "city"])
        #expect(viewModel.navigationTitle == "trips")
        #expect(viewModel.hasActiveFilters)

        viewModel.select(folder: trips)
        #expect(viewModel.selectedFolder == nil)
        #expect(viewModel.filteredItems.count == 3)

        viewModel.select(folder: trips)
        viewModel.select(.favorites)
        #expect(viewModel.selectedFolder == nil)
    }

    @Test("最近添加只统计窗口内的条目")
    func recentlyAddedScope() {
        let provider = FakeRepositoryProvider()
        let now = Date()
        let fresh = makeItem(name: "fresh", modifiedAt: now.addingTimeInterval(-VideoLibraryViewModel.recentlyAddedWindow + 60))
        let stale = makeItem(name: "stale", modifiedAt: now.addingTimeInterval(-VideoLibraryViewModel.recentlyAddedWindow - 60))
        let undated = makeItem(name: "undated")
        provider.items = [fresh, stale, undated]

        #expect(VideoLibraryViewModel.isRecentlyAdded(fresh, now: now))
        #expect(!VideoLibraryViewModel.isRecentlyAdded(stale, now: now))
        #expect(!VideoLibraryViewModel.isRecentlyAdded(undated, now: now))

        let viewModel = makeViewModel(provider: provider)
        viewModel.select(.recentlyAdded)
        #expect(viewModel.filteredItems.map(\.title) == ["fresh"])
        #expect(viewModel.count(for: .recentlyAdded) == 1)
    }

    @Test("检查器选中条目后随仓库刷新同步，删除后清空")
    func selectionFollowsRepository() {
        let provider = FakeRepositoryProvider()
        var item = makeItem(name: "clip", tags: ["a"])
        provider.items = [item]
        let viewModel = makeViewModel(provider: provider)

        viewModel.select(item)
        #expect(viewModel.selectedItem == item)

        item = makeItem(name: "clip", tags: ["a", "b"])
        provider.items = [item]
        viewModel.reload()
        #expect(viewModel.selectedItem?.tags == ["a", "b"])

        viewModel.addTag("b", to: item)
        viewModel.removeTag("a", to: item)
        #expect(provider.tagUpdates.count == 1)
        #expect(provider.tagUpdates.first?.tags == ["b"])

        try? viewModel.rename(item, to: "clip-2")
        provider.items = []
        viewModel.reload()
        #expect(viewModel.selectedItem == nil, "仓库尚未反映出重命名时不保留过期条目")

        provider.items = [VideoItem(
            url: URL(fileURLWithPath: "/tmp/videos/clip-2.mp4"),
            relativePath: "clip-2.mp4",
            title: "clip-2",
            size: 1024,
            modifiedAt: nil,
            duration: 60
        )]
        viewModel.reload()
        #expect(viewModel.selectedItem?.title == "clip-2", "仓库反映出重命名后检查器跟随新文件")

        viewModel.clearSelection()
        viewModel.reload()
        #expect(viewModel.selectedItem == nil)

        try? viewModel.delete(item)
        #expect(viewModel.selectedItem == nil)
    }

    @Test("未下载或不可用的视频不得直接交给播放引擎")
    func unavailablePlaybackIsGuarded() {
        let provider = FakeRepositoryProvider()
        let cloud = makeItem(name: "cloud", availability: .cloudNotDownloaded)
        let downloading = makeItem(name: "downloading", availability: .cloudDownloading)
        let unavailable = makeItem(name: "unavailable", availability: .unavailable("Missing"))
        provider.items = [cloud, downloading, unavailable]

        let playback = FakePlaybackProvider()
        let viewModel = makeViewModel(provider: provider, playback: playback)

        viewModel.play(cloud)
        viewModel.play(downloading)
        viewModel.play(unavailable)

        #expect(playback.playedURLs.isEmpty)
        #expect(provider.requestedDownloads == [cloud.url])
        #expect(!viewModel.isPlayerPresented)
    }

    @Test("摘要统计与当前筛选结果口径一致")
    func summaryMatchesFilteredItems() {
        let provider = FakeRepositoryProvider()
        provider.items = [
            makeItem(name: "alpha", tags: ["news"]),
            makeItem(name: "beta"),
        ]

        let viewModel = makeViewModel(provider: provider)
        #expect(viewModel.totalSizeTitle == ByteCountFormatter.string(fromByteCount: 2048, countStyle: .file))

        viewModel.selectedTag = "news"
        #expect(viewModel.filteredItems.map(\.title) == ["alpha"])
        #expect(viewModel.totalSizeTitle == ByteCountFormatter.string(fromByteCount: 1024, countStyle: .file))
    }

    @Test("导入与 iCloud 下载转发到仓库")
    func importAndDownload() {
        let provider = FakeRepositoryProvider()
        let viewModel = makeViewModel(provider: provider)

        let urls = [URL(fileURLWithPath: "/tmp/a.mp4")]
        viewModel.importVideos(from: urls)
        #expect(provider.importedURLs == urls)

        let item = makeItem(name: "cloud", availability: .cloudNotDownloaded)
        viewModel.requestDownload(item)
        #expect(provider.requestedDownloads == [item.url])
    }
}
