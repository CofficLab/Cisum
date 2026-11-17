import Combine
import Foundation
import KernelCore
import ProviderControlView
import ProviderPlayback
import ProviderPlugin
import ProviderScene
import Testing
@testable import PluginBookLoading

@MainActor
private final class PlaybackStub: PlaybackProviding {
    var state: PlaybackStatus = .idle
    var currentURL: URL?
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0
    var playMode: PlaybackMode = .sequence
    var likedAssets: Set<URL> = []
    var isPlaying: Bool { state.isPlaying }
    var hasAsset: Bool { currentURL != nil }

    private(set) var cancelCount = 0
    private(set) var retryCount = 0
    var observerCount: Int { observers.count }
    private var observers: [UUID: (PlaybackProvidingEvent) -> Void] = [:]

    func play(_ url: URL) async {}
    func pause() {}
    func toggle() {}
    func seek(toProgress progress: Double) {}
    func seek(toTime time: TimeInterval) {}
    func next() {}
    func previous() {}
    func setPlayMode(_ mode: PlaybackMode) {}
    func toggleCurrentLike() {}
    func togglePlayMode() {}
    func cancelPendingLoad() { cancelCount += 1 }
    func retryLastFailedLoad() async { retryCount += 1 }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackProvidingEvent) -> Void
    ) -> any PlaybackProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return PlaybackHandleBox { [weak self] in self?.observers.removeValue(forKey: id) }
    }

    func send(_ event: PlaybackProvidingEvent) {
        for callback in Array(observers.values) { callback(event) }
    }
}

@MainActor
private final class PlaybackHandleBox: PlaybackProvidingObserverHandle {
    private var onCancel: (() -> Void)?
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() {
        onCancel?()
        onCancel = nil
    }
}

@MainActor
private final class SceneStub: SceneProviding {
    let objectWillChange = ObservableObjectPublisher()
    let scenes = AppScene.allCases
    private(set) var currentScene: AppScene?
    private var observers: [UUID: (SceneProvidingEvent) -> Void] = [:]

    init(currentScene: AppScene?) {
        self.currentScene = currentScene
    }

    func setCurrentScene(_ scene: AppScene) {
        select(scene)
    }

    func restoreCurrentScene() {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return SceneHandleBox { [weak self] in self?.observers.removeValue(forKey: id) }
    }

    func select(_ scene: AppScene?) {
        currentScene = scene
        for callback in Array(observers.values) {
            callback(.selectionChanged(scene: scene))
        }
    }
}

@MainActor
private final class SceneHandleBox: SceneProvidingObserverHandle {
    private var onCancel: (() -> Void)?
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() {
        onCancel?()
        onCancel = nil
    }
}

@MainActor
struct BookLoadingTests {
    private let chapterURL = URL(fileURLWithPath: "/tmp/Chapter One.m4b")

    // MARK: - Mode derivation

    @Test
    func downloadingModeCarriesClampedProgress() {
        #expect(BookLoadingViewModel.mode(for: .loading(.downloading(0.42))) == .downloading(progress: 0.42))
        #expect(BookLoadingViewModel.mode(for: .loading(.downloading(1.5))) == .downloading(progress: 1))
        #expect(BookLoadingViewModel.mode(for: .loading(.downloading(0))) == .downloading(progress: nil))
        #expect(BookLoadingViewModel.mode(for: .loading(.downloading(-0.2))) == .downloading(progress: nil))
    }

    @Test
    func onlyICloudFailureBecomesVisible() {
        #expect(BookLoadingViewModel.mode(for: .failed(.iCloudDownloadFailed("timed out"))) == .failed(detail: "timed out"))
        #expect(BookLoadingViewModel.mode(for: .failed(.networkError("offline"))) == .hidden)
        #expect(BookLoadingViewModel.mode(for: .failed(.playbackError("decoder"))) == .hidden)
        #expect(BookLoadingViewModel.mode(for: .loading(.connecting)) == .hidden)
        #expect(BookLoadingViewModel.mode(for: .playing) == .hidden)
    }

    @Test
    func sceneGatesBannerToAudiobooks() {
        let downloading = PlaybackStatus.loading(.downloading(0.3))
        #expect(BookLoadingViewModel.resolvedMode(state: downloading, scene: .audiobooks) == .downloading(progress: 0.3))
        #expect(BookLoadingViewModel.resolvedMode(state: downloading, scene: .music) == .hidden)
        #expect(BookLoadingViewModel.resolvedMode(state: downloading, scene: nil) == .hidden)
    }

    @Test
    func subjectUsesFileStem() {
        #expect(BookLoadingViewModel.subject(for: chapterURL) == "Chapter One")
        #expect(BookLoadingViewModel.subject(for: nil) == "")
    }

    // MARK: - ViewModel

    @Test
    func viewModelFollowsSceneAndPlaybackChanges() {
        let playback = PlaybackStub()
        playback.state = .loading(.downloading(0.5))
        let capability = BookLoadingPlaybackCapabilityAdapter(playback: playback)
        let viewModel = BookLoadingViewModel(playback: capability, scene: .audiobooks)
        #expect(viewModel.mode == .downloading(progress: 0.5))

        viewModel.handleStateChanged(.loading(.downloading(0.5)))
        #expect(viewModel.mode == .downloading(progress: 0.5))

        // 离开有声书场景只收起横幅，不改变播放状态。
        viewModel.handleSceneChanged(.music)
        #expect(viewModel.mode == .hidden)
        #expect(playback.cancelCount == 0)

        viewModel.handleSceneChanged(.audiobooks)
        #expect(viewModel.mode == .downloading(progress: 0.5))

        viewModel.handleStateChanged(.failed(.iCloudDownloadFailed("denied")))
        #expect(viewModel.mode == .failed(detail: "denied"))

        viewModel.handleAssetChanged(chapterURL)
        #expect(viewModel.subject == "Chapter One")
    }

    @Test
    func viewModelForwardsCancelAndRetry() async {
        let playback = PlaybackStub()
        let capability = BookLoadingPlaybackCapabilityAdapter(playback: playback)
        let viewModel = BookLoadingViewModel(playback: capability, scene: .audiobooks)

        viewModel.cancel()
        #expect(playback.cancelCount == 1)

        viewModel.retry()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(playback.retryCount == 1)
    }

    @Test
    func bannerBodyBuildsForEveryMode() {
        let playback = PlaybackStub()
        let viewModel = BookLoadingViewModel(
            playback: BookLoadingPlaybackCapabilityAdapter(playback: playback),
            scene: .audiobooks
        )
        _ = BookLoadingBanner(viewModel: viewModel).body

        viewModel.handleStateChanged(.loading(.downloading(0.4)))
        _ = BookLoadingBanner(viewModel: viewModel).body

        viewModel.handleStateChanged(.loading(.downloading(0)))
        _ = BookLoadingBanner(viewModel: viewModel).body

        viewModel.handleStateChanged(.failed(.iCloudDownloadFailed("denied")))
        _ = BookLoadingBanner(viewModel: viewModel).body
    }

    // MARK: - Plugin lifecycle

    @Test
    func pluginActivatesSlotOnlyForAudiobookLoading() async throws {
        let kernel = KernelCoreContainer()
        let playback = PlaybackStub()
        let scene = SceneStub(currentScene: .audiobooks)
        let control = DefaultControlViewProvider()
        try kernel.registerProvider((any PlaybackProviding).self, playback)
        try kernel.registerProvider((any SceneProviding).self, scene)
        try kernel.registerProvider((any ControlViewProviding).self, control)

        let plugin = BookLoadingPlugin()
        try await plugin.onRegister(kernel: kernel)
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        let slot = try #require(control.loadingSlot)
        #expect(!slot.isActive)
        #expect(playback.observerCount == 1)

        playback.state = .loading(.downloading(0.2))
        playback.send(.stateChanged(.loading(.downloading(0.2))))
        #expect(slot.isActive)

        scene.select(.music)
        #expect(!slot.isActive)

        scene.select(.audiobooks)
        #expect(slot.isActive)

        playback.state = .paused
        playback.send(.stateChanged(.paused))
        #expect(!slot.isActive)

        playback.currentURL = chapterURL
        playback.state = .failed(.iCloudDownloadFailed("offline"))
        playback.send(.assetChanged(chapterURL))
        playback.send(.stateChanged(.failed(.iCloudDownloadFailed("offline"))))
        #expect(slot.isActive)

        try await plugin.onDisable(kernel: kernel)
        #expect(playback.observerCount == 0)
        #expect(control.loadingSlot == nil)
        #expect(!slot.isActive)

        try await plugin.onEnable(kernel: kernel)
        let restored = try #require(control.loadingSlot)
        #expect(restored.isActive)
        #expect(playback.observerCount == 1)

        try await plugin.onShutdownAsync(kernel: kernel)
        #expect(control.loadingSlot == nil)
        #expect(playback.observerCount == 0)
    }

    @Test
    func pluginStaysDormantWithoutControlProvider() async throws {
        let kernel = KernelCoreContainer()
        let playback = PlaybackStub()
        let scene = SceneStub(currentScene: .audiobooks)
        try kernel.registerProvider((any PlaybackProviding).self, playback)
        try kernel.registerProvider((any SceneProviding).self, scene)

        let plugin = BookLoadingPlugin()
        try await plugin.onRegister(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)
        try await plugin.onShutdownAsync(kernel: kernel)
        #expect(playback.observerCount == 0)
    }
}
