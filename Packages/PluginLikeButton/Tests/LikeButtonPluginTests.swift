import Foundation
import KernelCore
import ProviderPlayback
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

@MainActor
private final class CapabilityProbe: LikeButtonPlaybackCapability {
    var hasAsset: Bool = false
    var currentURL: URL?
    var likedAssets: [URL] = []
    var toggleCount = 0

    func toggleCurrentLike() { toggleCount += 1 }
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
        let capability = CapabilityProbe()
        capability.hasAsset = true
        capability.currentURL = URL(fileURLWithPath: "/tmp/song.mp3")
        capability.likedAssets = [URL(fileURLWithPath: "/tmp/song.mp3")]

        let viewModel = LikeButtonViewModel(playbackCapability: capability)
        #expect(viewModel.hasAsset)
        #expect(viewModel.isLiked)
    }

    @Test
    func initFallsBackWhenNoCapability() {
        let viewModel = LikeButtonViewModel(playbackCapability: nil)
        #expect(!viewModel.hasAsset)
        #expect(!viewModel.isLiked)
    }

    @Test
    func handleAssetChangedUpdatesLikedState() {
        let capability = CapabilityProbe()
        let url = URL(fileURLWithPath: "/tmp/song.mp3")
        capability.likedAssets = [url]
        let viewModel = LikeButtonViewModel(playbackCapability: capability)

        viewModel.handleAssetChanged(url)
        #expect(viewModel.hasAsset)
        #expect(viewModel.isLiked)

        viewModel.handleAssetChanged(nil)
        #expect(!viewModel.hasAsset)
        #expect(!viewModel.isLiked)
    }

    @Test
    func handleLikeStatusChangedUpdatesFlag() {
        let viewModel = LikeButtonViewModel(playbackCapability: nil)
        viewModel.handleLikeStatusChanged(true)
        #expect(viewModel.isLiked)
        viewModel.handleLikeStatusChanged(false)
        #expect(!viewModel.isLiked)
    }

    @Test
    func handleLikedAssetsChangedReflectsCurrentURL() {
        let capability = CapabilityProbe()
        let url = URL(fileURLWithPath: "/tmp/song.mp3")
        capability.currentURL = url
        let viewModel = LikeButtonViewModel(playbackCapability: capability)

        viewModel.handleLikedAssetsChanged([url])
        #expect(viewModel.isLiked)

        viewModel.handleLikedAssetsChanged([])
        #expect(!viewModel.isLiked)
    }

    @Test
    func toggleLikeForwardsToCapability() {
        let capability = CapabilityProbe()
        let viewModel = LikeButtonViewModel(playbackCapability: capability)
        viewModel.toggleLike()
        #expect(capability.toggleCount == 1)
    }
}

@MainActor
struct LikeButtonPlaybackCapabilityAdapterTests {
    @Test
    func adapterMapsPlaybackState() {
        let probe = PlaybackProbe()
        probe.currentURL = URL(fileURLWithPath: "/tmp/a.mp3")
        probe.likedAssets = [URL(fileURLWithPath: "/tmp/a.mp3")]

        let adapter = LikeButtonPlaybackCapabilityAdapter(playback: probe)
        #expect(adapter.hasAsset)
        #expect(adapter.currentURL == probe.currentURL)
        #expect(adapter.likedAssets == [URL(fileURLWithPath: "/tmp/a.mp3")])

        adapter.toggleCurrentLike()
        #expect(probe.toggleCount == 1)
    }
}

@MainActor
struct LikeButtonObserverTests {
    @Test
    func forwardsPlaybackEvents() {
        let probe = PlaybackProbe()
        let viewModel = LikeButtonViewModel(playbackCapability: nil)
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
        let viewModel = LikeButtonViewModel(playbackCapability: nil)
        let observer = LikeButtonObserver(playback: probe, viewModel: viewModel)

        observer.cancel()
        probe.emitAssetChanged(URL(fileURLWithPath: "/tmp/b.mp3"))
        #expect(!viewModel.hasAsset)
    }
}
