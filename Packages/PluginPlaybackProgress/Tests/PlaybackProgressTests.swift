import Foundation
import KernelCore
import ProviderPlayback
import ProviderDocsView
import Testing
@testable import PluginPlaybackProgress

@MainActor
private final class PlaybackStub: PlaybackProviding {
    var state: PlaybackStatus = .paused
    var currentURL: URL? = URL(fileURLWithPath: "/library/current.mp3")
    var currentTime: TimeInterval
    var duration: TimeInterval
    var progress: Double = 0
    var playMode: PlaybackMode = .sequence
    var likedAssets: Set<URL> = []
    private(set) var seekTimes: [TimeInterval] = []
    private var observers: [UUID: (PlaybackProvidingEvent) -> Void] = [:]

    var observerCount: Int { observers.count }

    var isPlaying: Bool { state.isPlaying }
    var hasAsset: Bool { currentURL != nil }

    init(currentTime: TimeInterval = 0, duration: TimeInterval = 0) {
        self.currentTime = currentTime
        self.duration = duration
    }

    func play(_ url: URL) async { currentURL = url }
    func pause() {}
    func toggle() {}
    func seek(toProgress progress: Double) {}
    func seek(toTime time: TimeInterval) { seekTimes.append(time) }
    func next() {}
    func previous() {}
    func setPlayMode(_ mode: PlaybackMode) { playMode = mode }
    func toggleCurrentLike() {}
    func togglePlayMode() {}

    func addObserver(
        _ callback: @escaping (PlaybackProvidingEvent) -> Void
    ) -> any PlaybackProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return PlaybackObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func send(_ event: PlaybackProvidingEvent) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}

@MainActor
private final class PlaybackObserverHandle: PlaybackProvidingObserverHandle {
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
private final class PlaybackCapabilityStub: PlaybackProgressCapability {
    var currentTime: TimeInterval
    var duration: TimeInterval
    private(set) var seekTimes: [TimeInterval] = []

    init(currentTime: TimeInterval, duration: TimeInterval) {
        self.currentTime = currentTime
        self.duration = duration
    }

    func seek(toTime: TimeInterval) {
        seekTimes.append(toTime)
    }
}

@MainActor
struct PlaybackProgressTests {
    @Test
    func capabilityAdapterForwardsPlaybackAndSeek() {
        let playback = PlaybackStub(currentTime: 12, duration: 60)
        let adapter = PlaybackProgressCapabilityAdapter(playback: playback)

        #expect(adapter.currentTime == 12)
        #expect(adapter.duration == 60)

        adapter.seek(toTime: 25)
        #expect(playback.seekTimes == [25])
    }

    @Test
    func capabilityAdapterFallsBackAfterPlaybackIsReleased() {
        var playback: PlaybackStub? = PlaybackStub(currentTime: 12, duration: 60)
        let adapter = PlaybackProgressCapabilityAdapter(playback: playback!)
        playback = nil

        #expect(adapter.currentTime == 0)
        #expect(adapter.duration == 0)
        adapter.seek(toTime: 20)
    }

    @Test
    func viewModelSyncsInitialAndAssetStateAndNormalizesSeekInput() {
        let capability = PlaybackCapabilityStub(currentTime: 3, duration: 10)
        let viewModel = PlaybackProgressViewModel(playbackCapability: capability)

        #expect(viewModel.currentTime == 3)
        #expect(viewModel.duration == 10)

        viewModel.handleTimeChanged(6)
        viewModel.handleDurationChanged(15)
        #expect(viewModel.currentTime == 6)
        #expect(viewModel.duration == 15)

        capability.currentTime = 8
        capability.duration = 20
        viewModel.handleAssetChanged()
        #expect(viewModel.currentTime == 8)
        #expect(viewModel.duration == 20)

        viewModel.seek(to: -1)
        viewModel.seek(to: .nan)
        viewModel.seek(to: 4.5)
        #expect(viewModel.currentTime == 4.5)
        #expect(capability.seekTimes == [0, 0, 4.5])
    }

    @Test
    func progressBindingUpdatesDisplayWithoutDuplicatingPlaybackSeek() {
        let capability = PlaybackCapabilityStub(currentTime: 1, duration: 10)
        let viewModel = PlaybackProgressViewModel(playbackCapability: capability)
        let view = PlaybackProgressView(viewModel: viewModel)
        let binding = view.makeCurrentTimeBinding()

        binding.wrappedValue = 3
        #expect(viewModel.currentTime == 3)
        #expect(capability.seekTimes.isEmpty)

        view.handleSeek(4)
        #expect(viewModel.currentTime == 4)
        #expect(capability.seekTimes == [4])
    }

    @Test
    func observerRoutesProgressEventsAndStopsAfterCancellation() {
        let playback = PlaybackStub(currentTime: 1, duration: 10)
        let capability = PlaybackProgressCapabilityAdapter(playback: playback)
        let viewModel = PlaybackProgressViewModel(playbackCapability: capability)
        let observer = PlaybackProgressObserver(playback: playback, viewModel: viewModel)

        playback.send(.timeChanged(currentTime: 4, progress: 0.4))
        playback.send(.durationChanged(20))
        playback.send(.stateChanged(.playing))
        #expect(viewModel.currentTime == 4)
        #expect(viewModel.duration == 20)

        playback.currentTime = 7
        playback.duration = 30
        playback.send(.assetChanged(URL(fileURLWithPath: "/library/next.mp3")))
        #expect(viewModel.currentTime == 7)
        #expect(viewModel.duration == 30)

        observer.cancel()
        observer.cancel()
        playback.send(.timeChanged(currentTime: 9, progress: 0.3))
        #expect(viewModel.currentTime == 7)
    }

    @Test
    func observerWithoutPlaybackCanBeCancelled() {
        let viewModel = PlaybackProgressViewModel(playbackCapability: nil)
        let observer = PlaybackProgressObserver(playback: nil, viewModel: viewModel)

        observer.cancel()
        #expect(viewModel.currentTime == 0)
        #expect(viewModel.duration == 0)
    }

    @Test
    func pluginRegistersDocsAndRestoresObserverAcrossLifecycle() async throws {
        let kernel = CisumKernel()
        let playback = PlaybackStub(currentTime: 5, duration: 25)
        let docs = DefaultDocsViewProvider()
        try kernel.registerPlayback(playback)
        try kernel.registerDocsService(docs)

        let plugin = PlaybackProgressPlugin()
        try await plugin.onRegister(kernel: kernel)
        #expect(docs.aboutEntries.map(\.id) == [plugin.id])
        #expect(docs.manualEntries.map(\.id) == [plugin.id])
        _ = docs.aboutEntries.first?.makeView()
        _ = docs.manualEntries.first?.makeView()

        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)
        #expect(plugin.addProgressView() != nil)
        #expect(playback.observerCount == 1)

        try await plugin.onReady(kernel: kernel)
        #expect(playback.observerCount == 1)

        try await plugin.onDisable(kernel: kernel)
        #expect(playback.observerCount == 0)

        try await plugin.onEnable(kernel: kernel)
        #expect(playback.observerCount == 1)

        try await plugin.onShutdown(kernel: kernel)
        #expect(playback.observerCount == 0)
    }

    @Test
    func pluginHandlesMissingOptionalProviders() async throws {
        let kernel = CisumKernel()
        let plugin = PlaybackProgressPlugin()

        try await plugin.onRegister(kernel: kernel)
        try await plugin.onReady(kernel: kernel)
        #expect(plugin.addProgressView() != nil)
        try await plugin.onShutdown(kernel: kernel)
    }

    @Test
    func progressAndDocumentationViewsBuildTheirContent() {
        let viewModel = PlaybackProgressViewModel(playbackCapability: nil)
        _ = PlaybackProgressView(viewModel: viewModel).body
        _ = PlaybackProgressPluginAboutView().body
        _ = PlaybackProgressPluginManualView().body
    }
}
