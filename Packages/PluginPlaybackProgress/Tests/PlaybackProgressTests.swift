import ProviderDocsView
import ProviderPlayback
import Foundation
import KernelCore
import ProviderPlugin
import KitAppEvents
import Testing
@testable import PluginPlaybackProgress

/// 最小进度能力探针：记录 seek 调用并可广播进度事件。
@MainActor
private final class PlaybackStub: ProgressBarCapability {
    var currentTime: TimeInterval
    var duration: TimeInterval
    var state: PlaybackStatus = .paused
    private(set) var seekTimes: [TimeInterval] = []
    private var observers: [UUID: (ProgressBarEvent) -> Void] = [:]

    var observerCount: Int { observers.count }

    init(currentTime: TimeInterval = 0, duration: TimeInterval = 0) {
        self.currentTime = currentTime
        self.duration = duration
    }

    func seek(toTime time: TimeInterval) { seekTimes.append(time) }

    @discardableResult
    func addObserver(
        _ callback: @escaping (ProgressBarEvent) -> Void
    ) -> any ProgressBarObserverHandle {
        let id = UUID()
        observers[id] = callback
        return PlaybackObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func send(_ event: ProgressBarEvent) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}

@MainActor
private final class PlaybackObserverHandle: ProgressBarObserverHandle {
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
struct PlaybackProgressTests {
    @Test
    func viewModelUsesPlaybackProviderForSnapshotAndSeek() {
        let playback = PlaybackStub(currentTime: 12, duration: 60)
        let viewModel = PlaybackProgressViewModel(playback: playback)

        #expect(viewModel.currentTime == 12)
        #expect(viewModel.duration == 60)

        viewModel.seek(to: 25)
        #expect(playback.seekTimes == [25])
    }

    @Test
    func viewModelUsesSafeSnapshotAfterPlaybackIsReleased() {
        var playback: PlaybackStub? = PlaybackStub(currentTime: 12, duration: 60)
        let viewModel = PlaybackProgressViewModel(playback: playback)
        #expect(viewModel.currentTime == 12)
        #expect(viewModel.duration == 60)
        playback = nil

        viewModel.handleAssetChanged()
        #expect(viewModel.currentTime == 0)
        #expect(viewModel.duration == 0)
        viewModel.seek(to: 20)
    }

    @Test
    func viewModelSyncsInitialAndAssetStateAndNormalizesSeekInput() {
        let playback = PlaybackStub(currentTime: 3, duration: 10)
        let viewModel = PlaybackProgressViewModel(playback: playback)

        #expect(viewModel.currentTime == 3)
        #expect(viewModel.duration == 10)

        viewModel.handleTimeChanged(6)
        viewModel.handleDurationChanged(15)
        #expect(viewModel.currentTime == 6)
        #expect(viewModel.duration == 15)

        playback.currentTime = 8
        playback.duration = 20
        viewModel.handleAssetChanged()
        #expect(viewModel.currentTime == 8)
        #expect(viewModel.duration == 20)

        viewModel.seek(to: -1)
        viewModel.seek(to: .nan)
        viewModel.seek(to: 4.5)
        #expect(viewModel.currentTime == 4.5)
        #expect(playback.seekTimes == [0, 0, 4.5])
    }

    @Test
    func progressBindingUpdatesDisplayWithoutDuplicatingPlaybackSeek() {
        let playback = PlaybackStub(currentTime: 1, duration: 10)
        let viewModel = PlaybackProgressViewModel(playback: playback)
        let view = PlaybackProgressView(viewModel: viewModel)
        let binding = view.makeCurrentTimeBinding()

        binding.wrappedValue = 3
        #expect(viewModel.currentTime == 3)
        #expect(playback.seekTimes.isEmpty)

        view.handleSeek(4)
        #expect(viewModel.currentTime == 4)
        #expect(playback.seekTimes == [4])
    }

    @Test
    func observerRoutesProgressEventsAndStopsAfterCancellation() {
        let playback = PlaybackStub(currentTime: 1, duration: 10)
        let viewModel = PlaybackProgressViewModel(playback: playback)
        let observer = PlaybackProgressObserver(playback: playback, viewModel: viewModel)

        playback.send(.timeChanged(4))
        playback.send(.durationChanged(20))
        #expect(viewModel.currentTime == 4)
        #expect(viewModel.duration == 20)

        playback.currentTime = 7
        playback.duration = 30
        playback.send(.assetChanged)
        #expect(viewModel.currentTime == 7)
        #expect(viewModel.duration == 30)

        observer.cancel()
        observer.cancel()
        playback.send(.timeChanged(9))
        #expect(viewModel.currentTime == 7)
    }

    @Test
    func observerWithoutPlaybackCanBeCancelled() {
        let viewModel = PlaybackProgressViewModel(playback: nil)
        // Provider 缺席时能力退化为「时长归零」，Observer 安装与取消均应安全。
        let observer = PlaybackProgressObserver(
            playback: ProgressBarCapabilityAdapter(playback: nil),
            viewModel: viewModel
        )

        observer.cancel()
        #expect(viewModel.currentTime == 0)
        #expect(viewModel.duration == 0)
    }

    @Test
    func pluginRegistersDocsAndRestoresObserverAcrossLifecycle() async throws {
        let kernel = KernelCoreContainer()
        // 走真实 Provider stub + Adapter：验证 Adapter 在生命周期内正确安装/释放监听。
        let playback = PlaybackProviderStub(currentTime: 5, duration: 25)
        let docs = DefaultDocsViewProvider()
        try kernel.registerProvider((any PlaybackProviding).self, playback)
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = PlaybackProgressPlugin()
        try await plugin.onRegister(kernel: kernel)
        #expect(docs.aboutEntries.map(\.id) == [plugin.id])
        #expect(docs.manualEntries.map(\.id) == [plugin.id])
        _ = docs.aboutEntries.first?.makeView()
        _ = docs.manualEntries.first?.makeView()

        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)
        #expect(plugin.addProgressView() != nil)
        #expect(playback.observerCount == 1)

        try await plugin.onReadyAsync(kernel: kernel)
        #expect(playback.observerCount == 1)

        try await plugin.onDisable(kernel: kernel)
        #expect(playback.observerCount == 0)

        try await plugin.onEnable(kernel: kernel)
        #expect(playback.observerCount == 1)

        try await plugin.onShutdownAsync(kernel: kernel)
        #expect(playback.observerCount == 0)
    }

    @Test
    func pluginHandlesMissingOptionalProviders() async throws {
        let kernel = KernelCoreContainer()
        let plugin = PlaybackProgressPlugin()

        try await plugin.onRegister(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)
        #expect(plugin.addProgressView() != nil)
        try await plugin.onShutdownAsync(kernel: kernel)
    }

    @Test
    func progressAndDocumentationViewsBuildTheirContent() {
        let viewModel = PlaybackProgressViewModel(playback: nil)
        _ = PlaybackProgressView(viewModel: viewModel).body
        _ = PlaybackProgressPluginAboutView().body
        _ = PlaybackProgressPluginManualView().body
    }

    // MARK: - Download progress tests

    @Test
    func downloadProgressIsNilWhenNotDownloading() {
        let playback = PlaybackStub(currentTime: 5, duration: 60)
        playback.state = .playing
        let viewModel = PlaybackProgressViewModel(playback: playback)

        #expect(viewModel.downloadProgress == nil)
    }

    @Test
    func downloadProgressExtractsFromDownloadingState() {
        let playback = PlaybackStub(currentTime: 0, duration: 0)
        playback.state = .loading(.downloading(0.42))
        let viewModel = PlaybackProgressViewModel(playback: playback)

        #expect(viewModel.downloadProgress == 0.42)
    }

    @Test
    func downloadProgressUpdatesOnStateChangedEvent() {
        let playback = PlaybackStub(currentTime: 0, duration: 0)
        playback.state = .idle
        let viewModel = PlaybackProgressViewModel(playback: playback)
        let observer = PlaybackProgressObserver(playback: playback, viewModel: viewModel)

        #expect(viewModel.downloadProgress == nil)

        playback.send(.stateChanged(.loading(.downloading(0.3))))
        #expect(viewModel.downloadProgress == 0.3)

        playback.send(.stateChanged(.loading(.downloading(0.75))))
        #expect(viewModel.downloadProgress == 0.75)

        // 下载完成，切换到播放态
        playback.send(.stateChanged(.playing))
        #expect(viewModel.downloadProgress == nil)

        observer.cancel()
    }

    @Test
    func downloadProgressClampsToValidRange() {
        #expect(PlaybackProgressViewModel.extractDownloadProgress(from: .loading(.downloading(-0.1))) == 0)
        #expect(PlaybackProgressViewModel.extractDownloadProgress(from: .loading(.downloading(1.5))) == 1)
        #expect(PlaybackProgressViewModel.extractDownloadProgress(from: .loading(.downloading(0.5))) == 0.5)
        #expect(PlaybackProgressViewModel.extractDownloadProgress(from: .playing) == nil)
        #expect(PlaybackProgressViewModel.extractDownloadProgress(from: .loading(.connecting)) == nil)
        #expect(PlaybackProgressViewModel.extractDownloadProgress(from: .idle) == nil)
    }

    @Test
    func downloadProgressClearsOnAssetChange() {
        let playback = PlaybackStub(currentTime: 0, duration: 0)
        playback.state = .loading(.downloading(0.5))
        let viewModel = PlaybackProgressViewModel(playback: playback)
        let observer = PlaybackProgressObserver(playback: playback, viewModel: viewModel)
        #expect(viewModel.downloadProgress == 0.5)

        // 切换到新文件（不再下载）
        playback.state = .paused
        playback.send(.assetChanged)
        #expect(viewModel.downloadProgress == nil)

        observer.cancel()
    }
}

/// 内核 `PlaybackProviding` 的最小实现：仅供生命周期测试验证 Adapter 转发。
@MainActor
private final class PlaybackProviderStub: PlaybackProviding {
    var state: PlaybackStatus = .paused
    var currentURL: URL?
    var currentTime: TimeInterval
    var duration: TimeInterval
    var progress: Double = 0
    var playMode: PlaybackMode = .sequence
    var likedAssets: Set<URL> = []
    var isPlaying: Bool { state.isPlaying }
    var hasAsset: Bool { currentURL != nil }

    var observerCount: Int { observers.count }
    private var observers: [UUID: (PlaybackProvidingEvent) -> Void] = [:]

    init(currentTime: TimeInterval = 0, duration: TimeInterval = 0) {
        self.currentTime = currentTime
        self.duration = duration
    }

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
    func reset() async {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackProvidingEvent) -> Void
    ) -> any PlaybackProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProviderHandle { [weak self] in self?.observers.removeValue(forKey: id) }
    }
}

@MainActor
private final class ProviderHandle: PlaybackProvidingObserverHandle {
    private let onCancel: () -> Void
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() { onCancel() }
}

