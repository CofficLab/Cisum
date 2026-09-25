import ProviderScene
import ProviderPlayback
import Foundation
import MagicPlayMan
import Testing
@testable import PluginAudioPlayMode

// MARK: - 探针实现

/// 最小播放探针：支持广播 playModeChanged 事件。
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

/// 最小场景探针：触发 selectionChanged 事件。
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

/// 播放能力探针：可配置 currentURL/playMode，记录 setPlayMode 调用。
@MainActor
private final class CapabilityProbe: AudioPlayModePlaybackCapability {
    var currentURL: URL?
    var playMode: MagicPlayMode = .sequence
    var setModes: [MagicPlayMode] = []

    func setPlayMode(_ mode: MagicPlayMode) {
        setModes.append(mode)
        playMode = mode
    }
}

// MARK: - AudioPlayModeStore

@Suite(.serialized)
struct AudioPlayModeStoreTests {
    @Test
    func resolvedPlayModePrefersLocalValue() {
        #expect(AudioPlayModeStore.resolvedPlayMode(
            localRawValue: MagicPlayMode.loop.rawValue,
            cloudRawValue: MagicPlayMode.shuffle.rawValue
        ) == .loop)
    }

    @Test
    func resolvedPlayModeFallsBackToCloud() {
        #expect(AudioPlayModeStore.resolvedPlayMode(
            localRawValue: nil,
            cloudRawValue: MagicPlayMode.shuffle.rawValue
        ) == .shuffle)
    }

    @Test
    func resolvedPlayModeDefaultsToSequence() {
        #expect(AudioPlayModeStore.resolvedPlayMode(localRawValue: nil, cloudRawValue: nil) == .sequence)
        #expect(AudioPlayModeStore.resolvedPlayMode(
            localRawValue: "bogus",
            cloudRawValue: "also-bogus"
        ) == .sequence)
    }

    @Test
    func storeAndGetRoundTrip() async {
        let store = AudioPlayModeStore.shared
        await store.storePlayMode(.shuffle)
        #expect(await store.getPlayMode() == .shuffle)
    }

    @Test
    func storeRawInvalidValueFallsBack() async {
        let store = AudioPlayModeStore.shared
        await store.storePlayModeRawValue("bogus", shortName: "Bogus")
        #expect(await store.getPlayMode() == .sequence)
    }

    @Test
    func resetRestoresDefault() async {
        let store = AudioPlayModeStore.shared
        await store.storePlayMode(.loop)
        await store.resetToDefault()
        #expect(await store.getPlayMode() == .sequence)
    }

    @Test
    func availableModesExposeSupportedSet() async {
        let store = AudioPlayModeStore.shared
        #expect(await store.getAvailableModes() == [.sequence, .repeatAll, .loop, .shuffle])
        #expect(await store.isModeAvailable(.shuffle))
        #expect(await store.isModeAvailable(.repeatAll))
    }
}

// MARK: - AudioPlayModeViewModel

@MainActor
struct AudioPlayModeViewModelTests {
    private func makeViewModel(
        targetScene: AppScene = .music,
        capability: CapabilityProbe? = CapabilityProbe(),
        onSort: @escaping AudioPlayModeSortAction = { _ in },
        onShuffle: @escaping AudioPlayModeShuffleAction = { _ in },
        load: @escaping AudioPlayModeLoadAction = { .sequence },
        store: @escaping AudioPlayModeStoreAction = { _, _ in }
    ) -> AudioPlayModeViewModel {
        AudioPlayModeViewModel(
            targetScene: targetScene,
            playbackCapability: capability,
            sort: onSort,
            shuffle: onShuffle,
            loadPlayMode: load,
            storePlayMode: store
        )
    }

    @Test
    func sceneChangeToTargetActivatesAndRestoresMode() async throws {
        let capability = CapabilityProbe()
        capability.playMode = .sequence
        let viewModel = makeViewModel(capability: capability, load: { .loop })

        viewModel.handleSceneChange(.music)
        try await Task.sleep(for: .milliseconds(100))

        #expect(capability.setModes == [.loop])
    }

    @Test
    func sceneChangeToOtherSceneDeactivates() async throws {
        let capability = CapabilityProbe()
        let viewModel = makeViewModel(capability: capability, load: { .loop })

        viewModel.handleSceneChange(.audiobooks)
        try await Task.sleep(for: .milliseconds(100))
        #expect(capability.setModes.isEmpty)

        // 回到目标场景重新激活。
        viewModel.handleSceneChange(.music)
        try await Task.sleep(for: .milliseconds(100))
        #expect(capability.setModes == [.loop])
    }

    @Test
    func activateSkipsWhenStoredModeMatchesCurrent() async throws {
        let capability = CapabilityProbe()
        capability.playMode = .loop
        let viewModel = makeViewModel(capability: capability, load: { .loop })

        viewModel.handleSceneChange(.music)
        try await Task.sleep(for: .milliseconds(100))

        #expect(capability.setModes.isEmpty)
    }

    @Test
    func playModeChangedToSequenceSortsQueue() async throws {
        let capability = CapabilityProbe()
        capability.playMode = .sequence
        capability.currentURL = URL(fileURLWithPath: "/tmp/a.mp3")
        var sortedURL: URL?
        var stored: [String] = []
        let viewModel = makeViewModel(
            capability: capability,
            onSort: { sortedURL = $0 },
            store: { raw, _ in stored.append(raw) }
        )

        viewModel.handleSceneChange(.music)
        try await Task.sleep(for: .milliseconds(100))
        viewModel.applyPlayModeChanged(.sequence)
        try await Task.sleep(for: .milliseconds(200))

        #expect(sortedURL == capability.currentURL)
        #expect(stored == [MagicPlayMode.sequence.rawValue])
    }

    @Test
    func playModeChangedToShuffleShufflesQueue() async throws {
        let capability = CapabilityProbe()
        capability.playMode = .sequence
        var shuffledURL: URL?
        let viewModel = makeViewModel(
            capability: capability,
            onShuffle: { shuffledURL = $0 },
            store: { _, _ in }
        )

        viewModel.handleSceneChange(.music)
        try await Task.sleep(for: .milliseconds(100))
        viewModel.applyPlayModeChanged(.shuffle)
        try await Task.sleep(for: .milliseconds(200))

        #expect(shuffledURL == capability.currentURL)
    }

    @Test
    func playModeChangedToLoopOnlyStores() async throws {
        let capability = CapabilityProbe()
        capability.playMode = .sequence
        var sorted = false
        var shuffled = false
        var stored: [String] = []
        let viewModel = makeViewModel(
            capability: capability,
            onSort: { _ in sorted = true },
            onShuffle: { _ in shuffled = true },
            store: { raw, _ in stored.append(raw) }
        )

        viewModel.handleSceneChange(.music)
        try await Task.sleep(for: .milliseconds(100))
        viewModel.applyPlayModeChanged(.loop)
        try await Task.sleep(for: .milliseconds(200))

        #expect(!sorted)
        #expect(!shuffled)
        #expect(stored == [MagicPlayMode.loop.rawValue])
    }

    @Test
    func playModeChangedWhenInactiveIsIgnored() async throws {
        let capability = CapabilityProbe()
        var sorted = false
        let viewModel = makeViewModel(capability: capability, onSort: { _ in sorted = true })

        viewModel.applyPlayModeChanged(.sequence)
        try await Task.sleep(for: .milliseconds(200))
        #expect(!sorted)
    }

    @Test
    func sortErrorIsHandledGracefully() async throws {
        let capability = CapabilityProbe()
        capability.playMode = .sequence
        let viewModel = makeViewModel(
            capability: capability,
            onSort: { _ in throw PlayModeTestError.boom },
            store: { _, _ in }
        )

        viewModel.handleSceneChange(.music)
        try await Task.sleep(for: .milliseconds(100))
        viewModel.applyPlayModeChanged(.sequence)
        try await Task.sleep(for: .milliseconds(200))
        // 不崩溃即为通过；错误路径记录日志并弹出提示。
        #expect(capability.playMode == .sequence)
    }
}

private enum PlayModeTestError: Error {
    case boom
}

// MARK: - AudioPlayModePlaybackCapabilityAdapter

@MainActor
struct AudioPlayModePlaybackCapabilityAdapterTests {
    @Test
    func adapterMapsPlayModeAndForwardsSet() {
        let probe = PlaybackProbe()
        probe.playMode = .shuffle
        probe.currentURL = URL(fileURLWithPath: "/tmp/song.mp3")

        let adapter = AudioPlayModePlaybackCapabilityAdapter(playback: probe)
        #expect(adapter.currentURL == probe.currentURL)
        #expect(adapter.playMode == .shuffle)

        adapter.setPlayMode(.loop)
        #expect(probe.setModes == [.loop])
        #expect(adapter.playMode == .loop)
    }
}

// MARK: - AudioPlayModeObserver

@MainActor
struct AudioPlayModeObserverTests {
    @Test
    func sceneEventsDriveViewModelActivation() async throws {
        let scene = SceneProbe()
        scene.currentScene = .music
        let playback = PlaybackProbe()
        playback.playMode = .sequence
        let capability = CapabilityProbe()

        let viewModel = AudioPlayModeViewModel(
            targetScene: .music,
            playbackCapability: capability,
            sort: { _ in },
            shuffle: { _ in },
            loadPlayMode: { .shuffle },
            storePlayMode: { _, _ in }
        )
        let observer = AudioPlayModeObserver(scene: scene, playback: playback, viewModel: viewModel)
        defer { observer.cancel() }

        scene.setCurrentScene(.audiobooks)
        try await Task.sleep(for: .milliseconds(50))
        #expect(capability.setModes.isEmpty)

        scene.setCurrentScene(.music)
        try await Task.sleep(for: .milliseconds(100))
        #expect(capability.setModes == [.shuffle])
    }

    @Test
    func playbackModeEventsApplyToViewModel() async throws {
        let scene = SceneProbe()
        let playback = PlaybackProbe()
        let capability = CapabilityProbe()
        capability.playMode = .sequence
        var stored: [String] = []
        let viewModel = AudioPlayModeViewModel(
            targetScene: .music,
            playbackCapability: capability,
            sort: { _ in },
            shuffle: { _ in },
            loadPlayMode: { .sequence },
            storePlayMode: { raw, _ in stored.append(raw) }
        )
        let observer = AudioPlayModeObserver(scene: scene, playback: playback, viewModel: viewModel)
        defer { observer.cancel() }

        // 先激活，再触发外部 playMode 变化。
        scene.setCurrentScene(.music)
        try await Task.sleep(for: .milliseconds(100))
        playback.emitPlayModeChanged(.loop)
        try await Task.sleep(for: .milliseconds(200))

        #expect(stored == [MagicPlayMode.loop.rawValue])
    }

    @Test
    func cancellingObserverStopsUpdates() async throws {
        let scene = SceneProbe()
        let playback = PlaybackProbe()
        let capability = CapabilityProbe()
        let viewModel = AudioPlayModeViewModel(
            targetScene: .music,
            playbackCapability: capability,
            sort: { _ in },
            shuffle: { _ in },
            loadPlayMode: { .shuffle },
            storePlayMode: { _, _ in }
        )
        let observer = AudioPlayModeObserver(scene: scene, playback: playback, viewModel: viewModel)

        observer.cancel()
        scene.setCurrentScene(.music)
        try await Task.sleep(for: .milliseconds(100))
        #expect(capability.setModes.isEmpty)
    }
}