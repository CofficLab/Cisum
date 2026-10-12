import ProviderDocsView
import ProviderPlayback
import ProviderAudioLibrary
import ProviderScene
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
private final class AudioLibraryStub: AudioLibraryProviding {
    private var observers: [UUID: (AudioLibraryProvidingEvent) -> Void] = [:]

    var audioDisk: URL? { nil }
    var supportedExtensions: [String] { [] }
    var isAvailable: Bool { true }

    func totalCount() async -> Int { 0 }
    func allURLs(reason: String) async -> [URL] { [] }
    func urls(offset: Int, limit: Int, reason: String) async -> [URL] { [] }
    func contains(_ url: URL) async -> Bool { false }
    func delete(urls: [URL], verbose: Bool) async throws {}
    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {}
    func sort(url: URL?, reason: String) async {}
    func sortRandom(url: URL?, reason: String, verbose: Bool) async throws {}

    func addObserver(
        _ callback: @escaping (AudioLibraryProvidingEvent) -> Void
    ) -> any AudioLibraryProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return AudioLibraryObserverHandle { [weak self] in self?.observers[id] = nil }
    }

    func send(_ event: AudioLibraryProvidingEvent) {
        for observer in observers.values {
            observer(event)
        }
    }
}

@MainActor
private final class AudioLibraryObserverHandle: AudioLibraryProvidingObserverHandle {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel?()
        onCancel = nil
    }
}

@MainActor
private final class SceneStub: SceneProviding {
    @Published private(set) var currentScene: AppScene?
    private var observers: [UUID: (SceneProvidingEvent) -> Void] = [:]

    var scenes: [AppScene] { AppScene.allCases }

    init(currentScene: AppScene?) {
        self.currentScene = currentScene
    }

    func setCurrentScene(_ scene: AppScene) {
        currentScene = scene
        for observer in observers.values {
            observer(.selectionChanged(scene: scene))
        }
    }

    func restoreCurrentScene() {}

    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return SceneObserverHandle { [weak self] in self?.observers[id] = nil }
    }
}

@MainActor
private final class SceneObserverHandle: SceneProvidingObserverHandle {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel?()
        onCancel = nil
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
    func emptyRepositoryHidesHeroAndPopulatedLibraryRestoresIt() {
        let library = AudioLibraryStub()
        let scene = SceneStub(currentScene: .audiobooks)
        let viewModel = PlaybackHeroViewModel(playbackProvider: PlaybackStub(), isMusicSceneActive: false)
        let observer = PlaybackHeroObserver(playback: nil, library: library, scene: scene, viewModel: viewModel)

        #expect(viewModel.isHeroVisible)

        library.send(.repositoryEmpty)
        #expect(viewModel.isHeroVisible, "An empty music repository must not hide a title in the audiobook scene")

        scene.setCurrentScene(.music)
        #expect(!viewModel.isHeroVisible)

        library.send(.synced(totalCount: 2))
        #expect(viewModel.isHeroVisible)

        library.send(.updated(totalCount: 0))
        #expect(viewModel.isHeroVisible, "Only the confirmed-empty domain event should hide the hero")

        library.send(.deleted(urls: [URL(fileURLWithPath: "/library/track.mp3")], totalCount: 0))
        #expect(viewModel.isHeroVisible, "A zero-count deletion must wait for the confirmed-empty event")
        library.send(.repositoryEmpty)
        #expect(!viewModel.isHeroVisible)

        observer.cancel()
        library.send(.updated(totalCount: 1))
        #expect(!viewModel.isHeroVisible, "Cancelled observers must not change hero visibility")
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

        try plugin.onRegister(kernel: kernel)
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
