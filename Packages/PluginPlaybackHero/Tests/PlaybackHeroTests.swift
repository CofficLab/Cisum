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

    /// 引擎侧的下载标签是纯文案（不含百分比），此处与真实实现保持一致。
    func localizedDownloadingLabel() -> String {
        "downloading"
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
        // ViewModel 以 `weak` 持有能力 Adapter，故测试需自行持有，否则能力会被释放。
        let playbackCapability = HeroPlaybackCapabilityAdapter(playback: playback)
        let mediaCapability = HeroMediaCapabilityAdapter(media: media)
        let viewModel = PlaybackHeroViewModel(playback: playbackCapability, media: mediaCapability)
        #expect(viewModel.currentURL == playback.currentURL)
        #expect(viewModel.state == .paused)
        #expect(viewModel.localizedStateText() == "state:paused")
        _ = viewModel.makeMediaView()
        #expect(media.makeMediaViewCallCount == 1)

        let fallback = PlaybackHeroViewModel(playback: playbackCapability)
        let failedState = PlaybackStatus.failed(.noAsset)
        fallback.applyStateChanged(failedState)
        #expect(fallback.localizedStateText() == String(describing: failedState))
        _ = fallback.makeMediaView()
    }

    /// Hero 圆环底部小字只显示「正在下载」，不带百分比。
    ///
    /// 圆环中心已单独显示百分比（如 14%），底部小字若复用带百分比的状态文案
    /// 会变成「正在下载 14%」，同一屏出现两个百分比。
    @Test
    func downloadLabelCarriesNoPercentage() {
        let playback = PlaybackStub()
        playback.state = .loading(.downloading(0.14))
        let media = MediaStub()
        // ViewModel 以 `weak` 持有能力 Adapter，故测试需自行持有，否则能力会被释放。
        let playbackCapability = HeroPlaybackCapabilityAdapter(playback: playback)
        let mediaCapability = HeroMediaCapabilityAdapter(media: media)
        let viewModel = PlaybackHeroViewModel(playback: playbackCapability, media: mediaCapability)

        #expect(viewModel.localizedDownloadingLabel() == "downloading")
        #expect(!viewModel.localizedDownloadingLabel().contains("%"))

        // 引擎缺席时回落到插件自带的本地化文案，同样不带百分比。
        let fallback = PlaybackHeroViewModel(playback: playbackCapability)
        #expect(!fallback.localizedDownloadingLabel().isEmpty)
        #expect(!fallback.localizedDownloadingLabel().contains("%"))
    }

    @Test
    func viewModelInitializesFromProvidersAndTracksPlaybackChanges() {
        let playback = PlaybackStub()
        playback.currentURL = URL(fileURLWithPath: "/library/current.flac")
        playback.state = .loading(.downloading(0.4))
        let media = MediaStub()
        // ViewModel 以 `weak` 持有能力 Adapter，故测试需自行持有，否则能力会被释放。
        let playbackCapability = HeroPlaybackCapabilityAdapter(playback: playback)
        let mediaCapability = HeroMediaCapabilityAdapter(media: media)
        let viewModel = PlaybackHeroViewModel(playback: playbackCapability, media: mediaCapability)

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

        let emptyViewModel = PlaybackHeroViewModel(playback: nil)
        #expect(emptyViewModel.currentURL == nil)
        #expect(emptyViewModel.state == .idle)
        #expect(emptyViewModel.localizedStateText() == String(describing: PlaybackStatus.idle))
        _ = emptyViewModel.makeMediaView()
    }

    @Test
    func observerForwardsAssetAndStateButStopsAfterCancellation() {
        let playback = PlaybackStub()
        let viewModel = PlaybackHeroViewModel(playback: nil)
        let playbackCapability = HeroPlaybackCapabilityAdapter(playback: playback)
        let observer = PlaybackHeroObserver(
            playback: playbackCapability,
            library: HeroLibraryCapabilityAdapter(library: nil),
            scene: HeroSceneCapabilityAdapter(scene: nil),
            viewModel: viewModel
        )
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

    /// 仓库为空时隐藏 Hero，仓库恢复后 Hero 重新显示。
    ///
    /// 测试场景：音乐场景下，仓库从非空变为空时 Hero 隐藏；仓库恢复后 Hero 重新显示。
    /// 非音乐场景下 Hero 始终隐藏（无论仓库状态）。
    @Test
    func emptyRepositoryHidesHeroAndPopulatedLibraryRestoresIt() {
        let library = AudioLibraryStub()
        let scene = SceneStub(currentScene: .music)
        let playbackStub = PlaybackStub()
        // 能力 Adapter 以 `weak` 持有 Provider，故 Provider 与 Adapter 都需
        // 由测试显式持有：临时 `PlaybackStub()` 会立即释放，使 currentURL 变 nil。
        let playbackCapability = HeroPlaybackCapabilityAdapter(playback: playbackStub)
        let libraryCapability = HeroLibraryCapabilityAdapter(library: library)
        let sceneCapability = HeroSceneCapabilityAdapter(scene: scene)
        let viewModel = PlaybackHeroViewModel(
            playback: playbackCapability,
            isMusicSceneActive: true
        )
        let observer = PlaybackHeroObserver(
            playback: playbackCapability,
            library: libraryCapability,
            scene: sceneCapability,
            viewModel: viewModel
        )

        // 音乐场景 + 有曲目 + 仓库非空 → Hero 可见
        #expect(viewModel.isHeroVisible)

        // 仓库变为空 → Hero 隐藏
        library.send(.repositoryEmpty)
        #expect(!viewModel.isHeroVisible, "Empty music repository should hide the hero")

        // 仓库恢复 → Hero 重新显示
        library.send(.synced(totalCount: 2))
        #expect(viewModel.isHeroVisible)

        // 非确认空的更新事件不应隐藏 Hero
        library.send(.updated(totalCount: 0))
        #expect(viewModel.isHeroVisible, "Only the confirmed-empty domain event should hide the hero")

        // 删除事件需要等待确认空事件
        library.send(.deleted(urls: [URL(fileURLWithPath: "/library/track.mp3")], totalCount: 0))
        #expect(viewModel.isHeroVisible, "A zero-count deletion must wait for the confirmed-empty event")
        library.send(.repositoryEmpty)
        #expect(!viewModel.isHeroVisible)

        // 切到有声书场景 → Hero 始终隐藏（即使仓库恢复）
        scene.setCurrentScene(.audiobooks)
        library.send(.synced(totalCount: 2))
        #expect(!viewModel.isHeroVisible, "Hero must be hidden in audiobooks scene regardless of repository state")

        // 切回音乐场景 → Hero 恢复显示
        scene.setCurrentScene(.music)
        #expect(viewModel.isHeroVisible, "Hero should be visible again in music scene")

        observer.cancel()
        library.send(.updated(totalCount: 1))
        #expect(viewModel.isHeroVisible, "Cancelled observers must not change hero visibility")
    }

    /// 场景切换时 Hero 可见性必须跟随场景：切离音乐场景后 Hero 必须隐藏。
    ///
    /// 回归测试：音乐场景播放歌曲 A → 切换到有声书场景 → Hero 仍显示歌曲 A 的信息。
    /// 原因：`SceneObserver.stop()` 保留 `currentURL` 以便切回时恢复，但 Hero 的
    /// `isHeroVisible` 逻辑没有正确检查场景——非音乐场景时不应显示 Hero。
    @Test
    func switchingAwayFromMusicSceneHidesHero() {
        let playback = PlaybackStub()
        playback.currentURL = URL(fileURLWithPath: "/library/song-a.mp3")
        playback.state = .playing
        let scene = SceneStub(currentScene: .music)
        let library = AudioLibraryStub()

        let playbackCapability = HeroPlaybackCapabilityAdapter(playback: playback)
        let libraryCapability = HeroLibraryCapabilityAdapter(library: library)
        let sceneCapability = HeroSceneCapabilityAdapter(scene: scene)
        let viewModel = PlaybackHeroViewModel(
            playback: playbackCapability,
            isMusicSceneActive: true
        )
        let observer = PlaybackHeroObserver(
            playback: playbackCapability,
            library: libraryCapability,
            scene: sceneCapability,
            viewModel: viewModel
        )

        // 音乐场景 + 有曲目 + 仓库非空 → Hero 可见
        #expect(viewModel.isMusicSceneActive == true)
        #expect(viewModel.currentURL != nil)
        #expect(viewModel.isHeroVisible, "音乐场景播放时应显示 Hero")

        // 切换到有声书场景（模拟 SceneObserver.stop() 保留 currentURL 的情况）
        scene.setCurrentScene(.audiobooks)

        // 关键断言：切离音乐场景后 Hero 必须隐藏，即使 currentURL 仍在
        #expect(viewModel.isMusicSceneActive == false)
        #expect(viewModel.currentURL != nil, "stop() 保留 currentURL 以便恢复")
        #expect(!viewModel.isHeroVisible, "切离音乐场景后 Hero 必须隐藏，不应显示上一场景的曲目信息")

        // 切回音乐场景 → Hero 应恢复显示
        scene.setCurrentScene(.music)
        #expect(viewModel.isMusicSceneActive == true)
        #expect(viewModel.isHeroVisible, "切回音乐场景后 Hero 应恢复显示")

        observer.cancel()
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
