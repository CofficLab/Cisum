import ProviderDocsView
import ProviderPlayback
import KernelCore
import ProviderPlugin
import KitAppEvents
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
struct PlaybackHeroTests {
    @Test
    func viewModelUsesPlaybackAndMediaProvidersDirectly() {
        let playback = PlaybackStub()
        let media = MediaStub()
        let viewModel = PlaybackHeroViewModel(playbackProvider: playback, mediaProvider: media)
        #expect(viewModel.currentURL == playback.currentURL)
        #expect(viewModel.state == .paused)
        #expect(viewModel.localizedStateText() == "state:paused")
        _ = viewModel.makeMediaView()
        #expect(media.makeMediaViewCallCount == 1)

        let fallback = PlaybackHeroViewModel(playbackProvider: playback)
        let failedState = PlaybackStatus.failed(.noAsset)
        fallback.applyStateChanged(failedState)
        #expect(fallback.localizedStateText() == String(describing: failedState))
        _ = fallback.makeMediaView()
    }

    @Test
    func viewModelInitializesFromProvidersAndTracksPlaybackChanges() {
        let playback = PlaybackStub()
        playback.currentURL = URL(fileURLWithPath: "/library/current.flac")
        playback.state = .loading(.downloading(0.4))
        let media = MediaStub()
        let viewModel = PlaybackHeroViewModel(playbackProvider: playback, mediaProvider: media)

        #expect(viewModel.currentURL == playback.currentURL)
        #expect(viewModel.state == playback.state)
        #expect(viewModel.localizedStateText() == "state:\(String(describing: playback.state))")

        let nextURL = URL(fileURLWithPath: "/library/next.mp3")
        viewModel.applyAssetChanged(nextURL)
        viewModel.applyStateChanged(.playing)
        _ = viewModel.makeMediaView()

        #expect(viewModel.currentURL == nextURL)
        #expect(viewModel.state == .playing)
        #expect(media.makeMediaViewCallCount == 1)

        let emptyViewModel = PlaybackHeroViewModel(playbackProvider: nil)
        #expect(emptyViewModel.currentURL == nil)
        #expect(emptyViewModel.state == .idle)
        #expect(emptyViewModel.localizedStateText() == String(describing: PlaybackStatus.idle))
        _ = emptyViewModel.makeMediaView()
    }

    @Test
    func observerForwardsAssetAndStateButStopsAfterCancellation() {
        let playback = PlaybackStub()
        let viewModel = PlaybackHeroViewModel(playbackProvider: nil)
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
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProvider()
        try kernel.registerProvider((any DocsViewProviding).self, docs)
        let playback = PlaybackStub()
        let media = MediaStub()
        try kernel.registerProvider((any PlaybackProviding).self, playback)
        try kernel.registerProvider((any PlaybackMediaProviding).self, media)
        let plugin = PlaybackHeroPlugin()

        try await plugin.onRegister(kernel: kernel)
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        #expect(docs.aboutEntries.contains { $0.id == plugin.id })
        #expect(docs.manualEntries.contains { $0.id == plugin.id })
        #expect(plugin.addHeroView() != nil)
        #expect(plugin.addRightAlbumView() != nil)

        try await plugin.onShutdownAsync(kernel: kernel)
        #expect(plugin.addHeroView() == nil)
        #expect(plugin.addRightAlbumView() == nil)
    }

    @Test
    func pluginContributesHeroViewsAfterPlaybackProvidersAreReady() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProvider()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any DocsViewProviding).self, docs)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)
        try kernel.registerProvider((any PluginProviding).self, contributions)
        try kernel.registerProvider((any PlaybackProviding).self, PlaybackStub())
        try kernel.registerProvider((any PlaybackMediaProviding).self, MediaStub())

        let plugin = PlaybackHeroPlugin()
        try await kernel.startAsync(plugins: [plugin])

        #expect(contributions.getHeroView() != nil)
        #expect(contributions.getRightAlbumView() != nil)
        try await kernel.stopAsync()
    }
}
