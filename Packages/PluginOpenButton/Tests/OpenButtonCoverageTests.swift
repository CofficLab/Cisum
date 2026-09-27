import ProviderPlayback
import Foundation
import Testing
@testable import PluginOpenButton

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

    private var observers: [UUID: (PlaybackProvidingEvent) -> Void] = [:]

    func emitAssetChanged(_ url: URL?) {
        let event = PlaybackProvidingEvent.assetChanged(url)
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
    func toggleCurrentLike() {}
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
@Test
func pluginInfoIsStable() {
    #expect(!OpenButtonPluginInfo.iconName.isEmpty)
    #expect(!OpenButtonPluginInfo.description.isEmpty)
}

@MainActor
struct OpenButtonViewModelTests {
    @Test
    func initReflectsCurrentURL() {
        let playback = PlaybackProbe()
        playback.currentURL = URL(fileURLWithPath: "/tmp/song.mp3")
        let viewModel = OpenButtonViewModel(playbackProvider: playback)
        #expect(viewModel.url == playback.currentURL)
    }

    @Test
    func initWithoutPlaybackKeepsNil() {
        let viewModel = OpenButtonViewModel(playbackProvider: nil)
        #expect(viewModel.url == nil)
    }

    @Test
    func handleAssetChangedUpdatesURL() {
        let viewModel = OpenButtonViewModel(playbackProvider: nil)
        let url = URL(fileURLWithPath: "/tmp/new.mp3")
        viewModel.handleAssetChanged(url)
        #expect(viewModel.url == url)
        viewModel.handleAssetChanged(nil)
        #expect(viewModel.url == nil)
    }
}

@MainActor
struct OpenButtonObserverTests {
    @Test
    func forwardsAssetChanges() {
        let probe = PlaybackProbe()
        let viewModel = OpenButtonViewModel(playbackProvider: nil)
        let observer = OpenButtonObserver(playback: probe, viewModel: viewModel)
        defer { observer.cancel() }

        probe.emitAssetChanged(URL(fileURLWithPath: "/tmp/a.mp3"))
        #expect(viewModel.url == URL(fileURLWithPath: "/tmp/a.mp3"))
        probe.emitAssetChanged(nil)
        #expect(viewModel.url == nil)
    }

    @Test
    func cancellingObserverStopsForwarding() {
        let probe = PlaybackProbe()
        let viewModel = OpenButtonViewModel(playbackProvider: nil)
        let observer = OpenButtonObserver(playback: probe, viewModel: viewModel)

        observer.cancel()
        probe.emitAssetChanged(URL(fileURLWithPath: "/tmp/b.mp3"))
        #expect(viewModel.url == nil)
    }
}
