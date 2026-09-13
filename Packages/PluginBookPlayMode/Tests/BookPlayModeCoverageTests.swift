import Foundation
import MagicPlayMan
import ProviderPlayback
import ProviderScene
import Testing
@testable import PluginBookPlayMode

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

    var setModes: [PlaybackMode] = []
    private var observers: [UUID: (PlaybackProvidingEvent) -> Void] = [:]

    func emitPlayModeChanged(_ mode: PlaybackMode) {
        let event = PlaybackProvidingEvent.playModeChanged(mode)
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
    func setPlayMode(_ mode: PlaybackMode) { setModes.append(mode); playMode = mode }
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
private final class SceneProbe: SceneProviding {
    var scenes: [AppScene] = [.music, .audiobooks]
    var currentScene: AppScene?
    private var observers: [UUID: (SceneProvidingEvent) -> Void] = [:]

    func setCurrentScene(_ scene: AppScene) {
        currentScene = scene
        let event = SceneProvidingEvent.selectionChanged(scene: scene)
        for observer in observers.values { observer(event) }
    }

    func restoreCurrentScene() {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProbeSceneHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class ProbeSceneHandle: SceneProvidingObserverHandle {
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
private final class CapabilityProbe: BookPlayModePlaybackCapability {
    var playMode: MagicPlayMode = .sequence
    var setModes: [MagicPlayMode] = []

    func setPlayMode(_ mode: MagicPlayMode) {
        setModes.append(mode)
        playMode = mode
    }
}

// MARK: - BookPlayModeStore

@Suite(.serialized)
struct BookPlayModeStoreTests {
    @Test
    func resolvedPlayModePrefersLocalValue() {
        #expect(BookPlayModeStore.resolvedPlayMode(
            localRawValue: MagicPlayMode.loop.rawValue,
            cloudRawValue: MagicPlayMode.shuffle.rawValue
        ) == .loop)
    }

    @Test
    func resolvedPlayModeFallsBackToCloud() {
        #expect(BookPlayModeStore.resolvedPlayMode(
            localRawValue: nil,
            cloudRawValue: MagicPlayMode.shuffle.rawValue
        ) == .shuffle)
    }

    @Test
    func resolvedPlayModeDefaultsToSequence() {
        #expect(BookPlayModeStore.resolvedPlayMode(localRawValue: nil, cloudRawValue: nil) == .sequence)
        #expect(BookPlayModeStore.resolvedPlayMode(
            localRawValue: "bogus",
            cloudRawValue: "also-bogus"
        ) == .sequence)
    }

    @Test
    func storeAndGetRoundTrip() async {
        let store = BookPlayModeStore.shared
        await store.storePlayMode(.repeatAll)
        #expect(await store.getPlayMode() == .repeatAll)
    }
}

// MARK: - BookPlayModeViewModel

@MainActor
struct BookPlayModeViewModelTests {
    private func makeViewModel(
        targetScene: AppScene = .audiobooks,
        capability: CapabilityProbe? = CapabilityProbe(),
        load: @escaping BookPlayModeLoadAction = { .sequence },
        store: @escaping BookPlayModeStoreAction = { _ in }
    ) -> BookPlayModeViewModel {
        BookPlayModeViewModel(
            targetScene: targetScene,
            playbackCapability: capability,
            loadPlayMode: load,
            storePlayMode: store
        )
    }

    @Test
    func sceneChangeToTargetActivatesAndRestoresMode() async throws {
        let capability = CapabilityProbe()
        capability.playMode = .sequence
        let viewModel = makeViewModel(capability: capability, load: { .loop })

        viewModel.handleSceneChange(.audiobooks)
        try await Task.sleep(for: .milliseconds(100))

        #expect(capability.setModes == [.loop])
    }

    @Test
    func sceneChangeToOtherSceneDeactivates() async throws {
        let capability = CapabilityProbe()
        let viewModel = makeViewModel(capability: capability, load: { .loop })

        viewModel.handleSceneChange(.music)
        try await Task.sleep(for: .milliseconds(100))
        #expect(capability.setModes.isEmpty)

        viewModel.handleSceneChange(.audiobooks)
        try await Task.sleep(for: .milliseconds(100))
        #expect(capability.setModes == [.loop])
    }

    @Test
    func activateSkipsWhenStoredModeMatchesCurrent() async throws {
        let capability = CapabilityProbe()
        capability.playMode = .loop
        let viewModel = makeViewModel(capability: capability, load: { .loop })

        viewModel.handleSceneChange(.audiobooks)
        try await Task.sleep(for: .milliseconds(100))

        #expect(capability.setModes.isEmpty)
    }

    @Test
    func playModeChangedStoresMode() async throws {
        let capability = CapabilityProbe()
        var stored: [MagicPlayMode] = []
        let viewModel = makeViewModel(
            capability: capability,
            store: { stored.append($0) }
        )

        viewModel.handleSceneChange(.audiobooks)
        try await Task.sleep(for: .milliseconds(100))
        viewModel.handlePlayModeChanged(.shuffle)
        try await Task.sleep(for: .milliseconds(200))

        #expect(stored == [.shuffle])
    }

    @Test
    func playModeChangedWhenInactiveIsIgnored() async throws {
        var stored: [MagicPlayMode] = []
        let viewModel = makeViewModel(store: { stored.append($0) })

        viewModel.handlePlayModeChanged(.loop)
        try await Task.sleep(for: .milliseconds(200))
        #expect(stored.isEmpty)
    }
}

// MARK: - BookPlayModePlaybackCapabilityAdapter

@MainActor
struct BookPlayModePlaybackCapabilityAdapterTests {
    @Test
    func adapterMapsPlayModeAndForwardsSet() {
        let probe = PlaybackProbe()
        probe.playMode = .loop

        let adapter = BookPlayModePlaybackCapabilityAdapter(playback: probe)
        #expect(adapter.playMode == .loop)

        adapter.setPlayMode(.shuffle)
        #expect(probe.setModes == [.shuffle])
        #expect(adapter.playMode == .shuffle)
    }
}

// MARK: - BookPlayModeObserver

@MainActor
struct BookPlayModeObserverTests {
    @Test
    func sceneEventsDriveViewModelActivation() async throws {
        let scene = SceneProbe()
        scene.currentScene = .audiobooks
        let playback = PlaybackProbe()
        let capability = CapabilityProbe()
        capability.playMode = .sequence

        let viewModel = BookPlayModeViewModel(
            targetScene: .audiobooks,
            playbackCapability: capability,
            loadPlayMode: { .repeatAll },
            storePlayMode: { _ in }
        )
        let observer = BookPlayModeObserver(scene: scene, playback: playback, viewModel: viewModel)
        defer { observer.cancel() }

        scene.setCurrentScene(.music)
        try await Task.sleep(for: .milliseconds(50))
        #expect(capability.setModes.isEmpty)

        scene.setCurrentScene(.audiobooks)
        try await Task.sleep(for: .milliseconds(100))
        #expect(capability.setModes == [.repeatAll])
    }

    @Test
    func playbackModeEventsApplyToViewModel() async throws {
        let scene = SceneProbe()
        let playback = PlaybackProbe()
        let capability = CapabilityProbe()
        var stored: [MagicPlayMode] = []
        let viewModel = BookPlayModeViewModel(
            targetScene: .audiobooks,
            playbackCapability: capability,
            loadPlayMode: { .sequence },
            storePlayMode: { stored.append($0) }
        )
        let observer = BookPlayModeObserver(scene: scene, playback: playback, viewModel: viewModel)
        defer { observer.cancel() }

        scene.setCurrentScene(.audiobooks)
        try await Task.sleep(for: .milliseconds(100))
        playback.emitPlayModeChanged(.loop)
        try await Task.sleep(for: .milliseconds(200))

        #expect(stored == [.loop])
    }

    @Test
    func cancellingObserverStopsUpdates() async throws {
        let scene = SceneProbe()
        let playback = PlaybackProbe()
        let capability = CapabilityProbe()
        let viewModel = BookPlayModeViewModel(
            targetScene: .audiobooks,
            playbackCapability: capability,
            loadPlayMode: { .repeatAll },
            storePlayMode: { _ in }
        )
        let observer = BookPlayModeObserver(scene: scene, playback: playback, viewModel: viewModel)

        observer.cancel()
        scene.setCurrentScene(.audiobooks)
        try await Task.sleep(for: .milliseconds(100))
        #expect(capability.setModes.isEmpty)
    }
}
