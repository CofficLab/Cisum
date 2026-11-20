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

        func refresh() {}
        func updateAvailability(_ availability: VideoAvailability, for url: URL) {}
        func setTags(_ tags: [String], for url: URL) {}
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

        func play(_ url: URL, startTime: TimeInterval?) { playedURLs.append(url) }
        func pause() {}
        func toggle() {}
        func stop() {}
        func seek(toTime time: TimeInterval) {}
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

    @Test("播放时从上次位置继续并展开播放器")
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
        #expect(viewModel.isPlayerPresented)
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
