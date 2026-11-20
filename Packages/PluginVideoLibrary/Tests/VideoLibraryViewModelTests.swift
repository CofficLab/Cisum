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

        func refresh() {}
        func updateAvailability(_ availability: VideoAvailability, for url: URL) {}
        func setTags(_ tags: [String], for url: URL) {}
        func setRating(_ rating: Int?, for url: URL) {}
        func setFavorite(_ isFavorite: Bool, for url: URL) {}
        func updateProgress(_ progress: VideoPlaybackProgress, for url: URL) {}
        func rename(_ url: URL, to newName: String) throws {}
        func delete(_ url: URL) throws {}
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

        func play(_ url: URL, startTime: TimeInterval?) {}
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
        isFavorite: Bool = false
    ) -> VideoItem {
        VideoItem(
            url: URL(fileURLWithPath: "/tmp/videos/\(name).mp4"),
            relativePath: "\(name).mp4",
            title: name,
            size: 1024,
            modifiedAt: nil,
            duration: 60,
            tags: tags,
            isFavorite: isFavorite
        )
    }

    @Test("标签与收藏筛选生效")
    func filtering() {
        let provider = FakeRepositoryProvider()
        provider.items = [
            makeItem(name: "alpha", tags: ["news"], isFavorite: true),
            makeItem(name: "beta", tags: ["travel"]),
            makeItem(name: "gamma"),
        ]

        let viewModel = VideoLibraryViewModel(
            repository: VideoLibraryRepositoryCapability(repository: provider),
            playback: VideoLibraryPlaybackCapability(playback: FakePlaybackProvider())
        )
        viewModel.bind()

        #expect(viewModel.items.count == 3)
        #expect(viewModel.allTags == ["news", "travel"])

        viewModel.selectedTag = "news"
        #expect(viewModel.filteredItems.map(\.title) == ["alpha"])

        viewModel.selectedTag = nil
        viewModel.favoritesOnly = true
        #expect(viewModel.filteredItems.map(\.title) == ["alpha"])

        viewModel.favoritesOnly = false
        viewModel.searchText = "amm"
        #expect(viewModel.filteredItems.map(\.title) == ["gamma"])
    }

    @Test("标签规范化去重")
    func tagNormalization() {
        let tags = VideoTagSupport.normalizedTags(from: "news, travel；news\nsports")
        #expect(tags == ["news", "travel", "sports"])
    }
}
