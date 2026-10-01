import ProviderScene
import ProviderPlayback
import Combine
import Foundation
import KernelCore
import ProviderPlugin
import KitAppEvents
import Testing
@testable import PluginPlayBack

@MainActor
private final class PlaybackStub: PlaybackProviding {
    var state: PlaybackStatus = .paused
    var currentURL: URL? = URL(fileURLWithPath: "/library/current.mp3")
    var currentTime: TimeInterval = 12
    var duration: TimeInterval = 48
    var progress: Double = 0.25
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
private final class SceneProviderStub: @preconcurrency SceneProviding {
    let objectWillChange = ObservableObjectPublisher()
    let scenes = AppScene.allCases
    private(set) var currentScene: AppScene?
    private var observers: [UUID: (SceneProvidingEvent) -> Void] = [:]

    init(currentScene: AppScene?) {
        self.currentScene = currentScene
    }

    func setCurrentScene(_ scene: AppScene) {
        currentScene = scene
        send(.selectionChanged(scene: scene))
    }

    func restoreCurrentScene() {
        currentScene = scenes.first
        send(.selectionChanged(scene: currentScene))
    }

    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return SceneObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func send(_ event: SceneProvidingEvent) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}

@MainActor
private final class SceneObserverHandle: SceneProvidingObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}

@MainActor
struct PlaybackSettingsTests {
    @Test
    func viewModelWeaklyHoldsPlaybackProvider() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var playback: PlaybackStub? = PlaybackStub()
        weak var weakPlayback = playback
        playback?.state = .playing
        let store = PlaybackStateStore(rootDirectory: root)
        let viewModel = PluginPlayBackSettingsViewModel(store: store, playbackProvider: playback)

        #expect(viewModel.currentURL == playback?.currentURL)
        #expect(viewModel.isPlaying)
        #expect(viewModel.state == .playing)
        #expect(viewModel.currentTime == 12)
        #expect(viewModel.duration == 48)

        playback = nil
        #expect(weakPlayback == nil)
        #expect(viewModel.currentURL == URL(fileURLWithPath: "/library/current.mp3"))
        // Published state is a snapshot; release of the Provider does not erase it.
    }

    @Test
    func settingsViewModelInitializesFromProviderAndTracksEvents() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlaybackStateStore(rootDirectory: root)
        let savedURL = URL(fileURLWithPath: "/library/saved-book.mp3")
        store.saveCurrentFile(savedURL, for: .audiobooks)
        let playback = PlaybackStub()
        playback.currentURL = URL(fileURLWithPath: "/library/current.mp3")
        playback.state = .playing
        playback.currentTime = 9
        playback.duration = 36
        let viewModel = PluginPlayBackSettingsViewModel(store: store, playbackProvider: playback)

        #expect(viewModel.scenes == AppScene.allCases)
        #expect(viewModel.currentURL == playback.currentURL)
        #expect(viewModel.isPlaying)
        #expect(viewModel.state == .playing)
        #expect(viewModel.currentTime == 9)
        #expect(viewModel.duration == 36)
        #expect(viewModel.lastFile(for: .audiobooks) == savedURL)

        viewModel.handleSceneChanged(.music)
        viewModel.handleAssetChanged(nil)
        viewModel.handleStateChanged(.paused)
        viewModel.handleTimeChanged(20)
        viewModel.handleDurationChanged(100)

        #expect(viewModel.currentScene == .music)
        #expect(viewModel.currentURL == nil)
        #expect(!viewModel.isPlaying)
        #expect(viewModel.state == .paused)
        #expect(viewModel.currentTime == 20)
        #expect(viewModel.duration == 100)

        let emptyViewModel = PluginPlayBackSettingsViewModel(store: store)
        #expect(emptyViewModel.state == .idle)
        #expect(!emptyViewModel.isPlaying)
        #expect(emptyViewModel.currentTime == 0)
        #expect(emptyViewModel.duration == 0)
    }

    @Test
    func playbackObserverForwardsEventsAndStopsAfterCancellation() {
        let playback = PlaybackStub()
        let viewModel = PluginPlayBackSettingsViewModel(store: PlaybackStateStore(rootDirectory: temporaryRootURL()))
        let observer = PlaybackSettingsPlaybackObserver(playback: playback, viewModel: viewModel)
        let nextURL = URL(fileURLWithPath: "/library/next.mp3")

        playback.send(.assetChanged(nextURL))
        playback.send(.stateChanged(.playing))
        playback.send(.timeChanged(currentTime: 15, progress: 0.5))
        playback.send(.durationChanged(30))
        playback.send(.playModeChanged(.shuffle))

        #expect(viewModel.currentURL == nextURL)
        #expect(viewModel.isPlaying)
        #expect(viewModel.currentTime == 15)
        #expect(viewModel.duration == 30)

        observer.cancel()
        observer.cancel()
        playback.send(.assetChanged(nil))
        #expect(viewModel.currentURL == nextURL)
    }

    @Test
    func sceneObserverSynchronizesInitialStateAndCancelsUpdates() {
        let provider = SceneProviderStub(currentScene: .audiobooks)
        let viewModel = PluginPlayBackSettingsViewModel(
            store: PlaybackStateStore(rootDirectory: temporaryRootURL())
        )
        let observer = PlaybackSettingsSceneObserver(provider: provider, viewModel: viewModel)

        #expect(viewModel.currentScene == .audiobooks)
        provider.setCurrentScene(.music)
        #expect(viewModel.currentScene == .music)

        observer.cancel()
        observer.cancel()
        provider.setCurrentScene(.audiobooks)
        #expect(viewModel.currentScene == .music)
    }

    @Test
    func pluginShutdownUnregistersBothPlaybackProviderContracts() async throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginPlayBack()
        try await kernel.startAsync(plugins: [plugin])

        #expect(kernel.isPluginRegistered(id: plugin.id))
        #expect(kernel.isPluginEnabled(id: plugin.id))
        #expect(plugin.magicPlayMan != nil)
        #expect(kernel.resolveProvider(PlaybackProviding.self) != nil)
        #expect(kernel.resolveProvider((any PlaybackMediaProviding).self) != nil)

        try await kernel.stopAsync()

        #expect(kernel.resolveProvider(PlaybackProviding.self) == nil)
        #expect(kernel.resolveProvider((any PlaybackMediaProviding).self) == nil)
    }
}

private func temporaryRoot() throws -> URL {
    let root = temporaryRootURL()
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func temporaryRootURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginPlayBackSettingsTests-\(UUID().uuidString)", isDirectory: true)
}
