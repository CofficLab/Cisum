import KernelCore
import ProviderDocsView
import ProviderPlayback
import SwiftUI
import Testing
@testable import PluginPlaybackHero

@MainActor
private final class PlaybackStub: PlaybackProviding {
    var state: PlaybackStatus = .paused
    var currentURL: URL? = URL(fileURLWithPath: "/library/track.mp3")
    var currentTime: TimeInterval = 3
    var duration: TimeInterval = 30
    var progress: Double = 0.1
    var playMode: PlaybackMode = .sequence
    var likedAssets: Set<URL> = []
    var isPlaying: Bool { state.isPlaying }
    var hasAsset: Bool { currentURL != nil }
    private let observers = PlaybackObserverStore<PlaybackProvidingEvent>()

    func play(_ url: URL) async { currentURL = url }
    func pause() {}
    func toggle() {}
    func seek(toProgress progress: Double) {}
    func seek(toTime time: TimeInterval) {}
    func next() {}
    func previous() {}
    func setPlayMode(_ mode: PlaybackMode) { playMode = mode }
    func toggleCurrentLike() {}
    func togglePlayMode() {}

    func addObserver(
        _ callback: @escaping (PlaybackProvidingEvent) -> Void
    ) -> any PlaybackProvidingObserverHandle {
        observers.add(callback)
    }

    func send(_ event: PlaybackProvidingEvent) {
        observers.send(event)
    }
}

@MainActor
private final class MediaStub: PlaybackMediaProviding {
    private(set) var makeMediaViewCallCount = 0

    func makeMediaView() -> AnyView {
        makeMediaViewCallCount += 1
        return AnyView(Text("Artwork"))
    }

    func localizedStateText(for state: PlaybackStatus) -> String {
        "state:\(String(describing: state))"
    }
}

@MainActor
private final class HeroCapabilityStub: PlaybackHeroPlaybackCapability {
    var currentURL: URL? = URL(fileURLWithPath: "/library/current.flac")
    var state: PlaybackStatus = .loading(.downloading(0.4))
    private(set) var makeHeroViewCallCount = 0

    func makeHeroView() -> AnyView {
        makeHeroViewCallCount += 1
        return AnyView(Text("Hero Artwork"))
    }

    func localizedStateText(for state: PlaybackStatus) -> String {
        "localized:\(String(describing: state))"
    }
}

@MainActor
struct PlaybackHeroTests {
    @Test
    func capabilityAdapterMapsPlaybackAndProvidesSafeMediaFallbacks() {
        let playback = PlaybackStub()
        let media = MediaStub()
        let adapter = PlaybackHeroPlaybackCapabilityAdapter(playback: playback, media: media)

        #expect(adapter.currentURL == playback.currentURL)
        #expect(adapter.state == .paused)
        #expect(adapter.localizedStateText(for: .playing) == "state:playing")
        _ = adapter.makeHeroView()
        #expect(media.makeMediaViewCallCount == 1)

        let fallback = PlaybackHeroPlaybackCapabilityAdapter(playback: playback, media: nil)
        let failedState = PlaybackStatus.failed(.noAsset)
        #expect(fallback.localizedStateText(for: failedState) == String(describing: failedState))
        _ = fallback.makeHeroView()
    }

    @Test
    func viewModelInitializesFromCapabilityAndTracksPlaybackChanges() {
        let capability = HeroCapabilityStub()
        let viewModel = PlaybackHeroViewModel(playbackCapability: capability)

        #expect(viewModel.currentURL == capability.currentURL)
        #expect(viewModel.state == capability.state)
        #expect(viewModel.localizedStateText() == "localized:\(String(describing: capability.state))")

        let nextURL = URL(fileURLWithPath: "/library/next.mp3")
        viewModel.applyAssetChanged(nextURL)
        viewModel.applyStateChanged(.playing)
        _ = viewModel.makeMediaView()

        #expect(viewModel.currentURL == nextURL)
        #expect(viewModel.state == .playing)
        #expect(capability.makeHeroViewCallCount == 1)

        let emptyViewModel = PlaybackHeroViewModel(playbackCapability: nil)
        #expect(emptyViewModel.currentURL == nil)
        #expect(emptyViewModel.state == .idle)
        #expect(emptyViewModel.localizedStateText() == String(describing: PlaybackStatus.idle))
        _ = emptyViewModel.makeMediaView()
    }

    @Test
    func observerForwardsAssetAndStateButStopsAfterCancellation() {
        let playback = PlaybackStub()
        let viewModel = PlaybackHeroViewModel(playbackCapability: nil)
        let observer = PlaybackHeroObserver(playback: playback, viewModel: viewModel)
        let nextURL = URL(fileURLWithPath: "/library/observer.mp3")

        playback.send(.assetChanged(nextURL))
        playback.send(.stateChanged(.playing))
        playback.send(.timeChanged(currentTime: 12, progress: 0.4))
        #expect(viewModel.currentURL == nextURL)
        #expect(viewModel.state == .playing)

        observer.cancel()
        observer.cancel()
        playback.send(.assetChanged(nil))
        playback.send(.stateChanged(.paused))
        #expect(viewModel.currentURL == nextURL)
        #expect(viewModel.state == .playing)
    }

    @Test
    func pluginAssemblesDocsAndPlaybackViewsThenReleasesObserver() async throws {
        let kernel = CisumKernelContainer()
        let docs = DefaultDocsViewProvider()
        try kernel.registerDocsService(docs)
        let playback = PlaybackStub()
        let media = MediaStub()
        try kernel.registerPlayback(playback)
        try kernel.registerProvider((any PlaybackMediaProviding).self, media)
        let plugin = PlaybackHeroPlugin()

        try await plugin.onRegister(kernel: kernel)
        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)

        #expect(docs.aboutEntries.contains { $0.id == plugin.id })
        #expect(docs.manualEntries.contains { $0.id == plugin.id })
        #expect(plugin.addHeroView() != nil)
        #expect(plugin.addRightAlbumView() != nil)

        try await plugin.onShutdown(kernel: kernel)
        #expect(plugin.addHeroView() == nil)
        #expect(plugin.addRightAlbumView() == nil)
    }
}
