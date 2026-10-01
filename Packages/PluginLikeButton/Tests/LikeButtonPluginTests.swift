import ProviderPlayback
import Foundation
import KernelCore
import ProviderPlugin
import KitAppEvents
import Testing
@testable import PluginLikeButton

// MARK: - 探针实现

@MainActor
private final class PlaybackProbe: PlaybackProviding {
    var state: PlaybackStatus = .idle
    var currentURL: URL?
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0
    var playMode: PlaybackMode = .sequence
    var likedAssets: Set<URL> = []
    var isPlaying: Bool { false }
    var hasAsset: Bool { currentURL != nil }

    var toggleCount = 0
    private var observers: [UUID: (PlaybackProvidingEvent) -> Void] = [:]

    func emitAssetChanged(_ url: URL?) {
        let event = PlaybackProvidingEvent.assetChanged(url)
        for observer in observers.values { observer(event) }
    }

    func emitLikeStatusChanged(_ url: URL, liked: Bool) {
        let event = PlaybackProvidingEvent.likeStatusChanged(asset: url, isLiked: liked)
        for observer in observers.values { observer(event) }
    }

    func emitLikedAssetsChanged(_ assets: Set<URL>) {
        let event = PlaybackProvidingEvent.likedAssetsChanged(assets)
        for observer in observers.values { observer(event) }
    }

    func play(_ url: URL) async {}
    func play(_ url: URL, startTime: TimeInterval?) async {}
    func pause() {}
    func toggle() {}
    func seek(toProgress progress: Double) {}
    func seek(toTime time: TimeInterval) {}
    func next() {}
    func previous() {}
    func setPlayMode(_ mode: PlaybackMode) {}
    func toggleCurrentLike() { toggleCount += 1 }
    func togglePlayMode() {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackProvidingEvent) -> Void
    ) -> any PlaybackProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProbePlaybackHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class ProbePlaybackHandle: PlaybackProvidingObserverHandle {
    private let onCancel: () -> Void
    private var cancelled = false

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        onCancel()
    }
}

// MARK: - 测试

@Test
func pluginMetadataIsStable() {
    #expect(LikeButtonPluginInfo.toolbarItemId == "like-toggle")
    #expect(!LikeButtonPluginInfo.description.isEmpty)
    #expect(!LikeButtonPluginInfo.iconName.isEmpty)
}

@MainActor
struct LikeButtonViewModelTests {
    @Test
    func initReflectsCurrentPlaybackState() {
        let playback = PlaybackProbe()
        playback.currentURL = URL(fileURLWithPath: "/tmp/song.mp3")
        playback.likedAssets = [URL(fileURLWithPath: "/tmp/song.mp3")]

        let viewModel = LikeButtonViewModel(playbackProvider: playback)
        #expect(viewModel.hasAsset)
        #expect(viewModel.isLiked)
    }

    @Test
    func initFallsBackWhenPlaybackIsUnavailable() {
        let viewModel = LikeButtonViewModel(playbackProvider: nil)
        #expect(!viewModel.hasAsset)
        #expect(!viewModel.isLiked)
    }

    @Test
    func handleAssetChangedUpdatesLikedState() {
        let playback = PlaybackProbe()
        let url = URL(fileURLWithPath: "/tmp/song.mp3")
        playback.likedAssets = [url]
        let viewModel = LikeButtonViewModel(playbackProvider: playback)

        viewModel.handleAssetChanged(url)
        #expect(viewModel.hasAsset)
        #expect(viewModel.isLiked)

        viewModel.handleAssetChanged(nil)
        #expect(!viewModel.hasAsset)
        #expect(!viewModel.isLiked)
    }

    @Test
    func handleLikeStatusChangedUpdatesFlag() {
        let viewModel = LikeButtonViewModel(playbackProvider: nil)
        viewModel.handleLikeStatusChanged(true)
        #expect(viewModel.isLiked)
        viewModel.handleLikeStatusChanged(false)
        #expect(!viewModel.isLiked)
    }

    @Test
    func handleLikedAssetsChangedReflectsCurrentURL() {
        let playback = PlaybackProbe()
        let url = URL(fileURLWithPath: "/tmp/song.mp3")
        playback.currentURL = url
        let viewModel = LikeButtonViewModel(playbackProvider: playback)

        viewModel.handleLikedAssetsChanged([url])
        #expect(viewModel.isLiked)

        viewModel.handleLikedAssetsChanged([])
        #expect(!viewModel.isLiked)
    }

    @Test
    func toggleLikeForwardsToCapability() {
        let playback = PlaybackProbe()
        let viewModel = LikeButtonViewModel(playbackProvider: playback)
        viewModel.toggleLike()
        #expect(playback.toggleCount == 1)
    }
}

@MainActor
struct LikeButtonObserverTests {
    @Test
    func forwardsPlaybackEvents() {
        let probe = PlaybackProbe()
        let viewModel = LikeButtonViewModel(playbackProvider: nil)
        let observer = LikeButtonObserver(playback: probe, viewModel: viewModel)
        defer { observer.cancel() }

        let url = URL(fileURLWithPath: "/tmp/a.mp3")
        probe.emitAssetChanged(url)
        #expect(viewModel.hasAsset)

        probe.emitLikeStatusChanged(url, liked: true)
        #expect(viewModel.isLiked)

        probe.emitLikedAssetsChanged([])
        #expect(!viewModel.isLiked)
    }

    @Test
    func cancellingObserverStopsForwarding() {
        let probe = PlaybackProbe()
        let viewModel = LikeButtonViewModel(playbackProvider: nil)
        let observer = LikeButtonObserver(playback: probe, viewModel: viewModel)

        observer.cancel()
        probe.emitAssetChanged(URL(fileURLWithPath: "/tmp/b.mp3"))
        #expect(!viewModel.hasAsset)
    }
}
