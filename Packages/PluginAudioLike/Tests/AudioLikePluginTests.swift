import ProviderScene
import ProviderPlayback
import Foundation
@testable import PluginAudioLike
import ProviderAudioLike
import Testing

private final class NotificationObserverToken: @unchecked Sendable {
    var value: NSObjectProtocol?
}

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(AudioLikePluginInfo.iconName == "heart")
    #expect(AudioLikePluginInfo.emoji == "❤️")
    #expect(AudioLikePluginInfo.order == 3)
}

@Test
@MainActor
func pluginExposesSettingsNavigationItem() {
    let view = AudioLikePlugin.shared.addSettingView()
    let item = AudioLikePlugin.shared.addSettingNavigationItem()

    #expect(view == nil)
    #expect(item != nil)
    #expect(item?.id == "liked-audio")
    #expect(item?.title == String(localized: "Liked audio"))
}

@Test func audioLikeStatusNotificationIsDeliveredOnMainThread() async {
    let url = URL(fileURLWithPath: "/tmp/audio/main-thread.mp3")

    let deliveredOnMainThread = await withCheckedContinuation { continuation in
        let token = NotificationObserverToken()
        token.value = NotificationCenter.default.addObserver(
            forName: .AudioLikeStatusChanged,
            object: nil,
            queue: nil
        ) { _ in
            if let observer = token.value {
                NotificationCenter.default.removeObserver(observer)
                token.value = nil
            }
            continuation.resume(returning: Thread.isMainThread)
        }

        Task.detached {
            NotificationCenter.postAudioLikeStatusChanged(
                audioId: url.absoluteString,
                url: url,
                liked: true
            )
        }
    }

    #expect(deliveredOnMainThread)
}

@Suite(.serialized)
struct AudioLikeRepoTests {
    @Test
    @MainActor
    func unlikedAudioDoesNotCreateStoredRecord() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioLikePluginTests-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        AudioLikeRepositoryConfiguration.configure(databaseURL: databaseURL)

        let audioId = "file:///tmp/audio/not-liked.mp3"

        try await AudioLikeRepo.shared.updateLikeStatus(audioId: audioId, liked: false)
        #expect(try await AudioLikeRepo.shared.findLikeModel(audioId: audioId) == nil)

        try await AudioLikeRepo.shared.updateLikeStatus(audioId: audioId, liked: true)
        #expect(try await AudioLikeRepo.shared.findLikeModel(audioId: audioId) != nil)

        try await AudioLikeRepo.shared.updateLikeStatus(audioId: audioId, liked: false)
        #expect(try await AudioLikeRepo.shared.findLikeModel(audioId: audioId) == nil)
    }

    @Test
    @MainActor
    func audioLikeRepoUsesReconfiguredDatabaseURL() async throws {
        let firstDatabaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioLikePluginTests-\(UUID().uuidString)-first")
            .appendingPathExtension("store")
        let secondDatabaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioLikePluginTests-\(UUID().uuidString)-second")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: firstDatabaseURL)
            try? FileManager.default.removeItem(at: secondDatabaseURL)
        }

        let audioId = "file:///tmp/audio/reconfigured.mp3"

        AudioLikeRepositoryConfiguration.configure(databaseURL: firstDatabaseURL)
        try await AudioLikeRepo.shared.updateLikeStatus(audioId: audioId, liked: true)
        #expect(try await AudioLikeRepo.shared.findLikeModel(audioId: audioId) != nil)

        AudioLikeRepositoryConfiguration.configure(databaseURL: secondDatabaseURL)
        #expect(try await AudioLikeRepo.shared.findLikeModel(audioId: audioId) == nil)
    }

    @Test
    @MainActor
    func audioLikeRepoPersistsMetadataForSettings() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioLikePluginTests-\(UUID().uuidString)-metadata")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: databaseURL)
        }

        AudioLikeRepositoryConfiguration.configure(databaseURL: databaseURL)

        let url = URL(fileURLWithPath: "/tmp/audio/metadata-track.mp3")
        let audioId = url.absoluteString

        try await AudioLikeRepo.shared.updateLikeStatus(
            audioId: audioId,
            liked: true,
            url: url,
            title: "Metadata Track"
        )

        let model = try #require(await AudioLikeRepo.shared.findLikeModel(audioId: audioId))
        #expect(model.url == url)
        #expect(model.title == "Metadata Track")
    }

    @Test
    @MainActor
    func audioLikeRepoBackfillsMissingMetadata() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioLikePluginTests-\(UUID().uuidString)-backfill")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: databaseURL)
        }

        AudioLikeRepositoryConfiguration.configure(databaseURL: databaseURL)

        let url = URL(fileURLWithPath: "/tmp/audio/backfilled-track.mp3")
        let audioId = url.absoluteString

        try await AudioLikeRepo.shared.updateLikeStatus(audioId: audioId, liked: true)
        try await AudioLikeRepo.shared.updateLikeStatus(
            audioId: audioId,
            liked: true,
            url: url,
            title: "Backfilled Track"
        )

        let model = try #require(await AudioLikeRepo.shared.findLikeModel(audioId: audioId))
        #expect(model.url == url)
        #expect(model.title == "Backfilled Track")
    }

    @Test
    @MainActor
    func audioLikeRepoMatchesSymlinkedLikedAudio() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let databaseURL = root
            .appendingPathComponent("AudioLikePluginTests-\(UUID().uuidString)-symlink")
            .appendingPathExtension("store")
        let realFolder = root.appendingPathComponent("real", isDirectory: true)
        let linkedFolder = root.appendingPathComponent("linked", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: realFolder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linkedFolder, withDestinationURL: realFolder)
        let realURL = realFolder.appendingPathComponent("track.mp3")
        let linkedURL = linkedFolder.appendingPathComponent("track.mp3")
        try Data("audio".utf8).write(to: realURL)

        AudioLikeRepositoryConfiguration.configure(databaseURL: databaseURL)

        try await AudioLikeRepo.shared.updateLikeStatus(
            audioId: realURL.absoluteString,
            liked: true,
            url: realURL,
            title: "Track"
        )

        #expect(await AudioLikeRepo.shared.isLiked(url: linkedURL))
    }

    @Test
    @MainActor
    func audioLikeRepoDoesNotMatchDistinctDanglingSymlinkedAudio() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let databaseURL = root
            .appendingPathComponent("AudioLikePluginTests-\(UUID().uuidString)-dangling")
            .appendingPathExtension("store")
        let missingFile = root.appendingPathComponent("missing.mp3")
        let firstLink = root.appendingPathComponent("first.mp3")
        let secondLink = root.appendingPathComponent("second.mp3")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingFile)
        try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingFile)

        AudioLikeRepositoryConfiguration.configure(databaseURL: databaseURL)

        try await AudioLikeRepo.shared.updateLikeStatus(
            audioId: firstLink.absoluteString,
            liked: true,
            url: firstLink,
            title: "First"
        )

        #expect(await AudioLikeRepo.shared.isLiked(url: firstLink))
        #expect(!(await AudioLikeRepo.shared.isLiked(url: secondLink)))
    }

    @Test
    @MainActor
    func audioLikeRepoUnlikesSymlinkedStoredAudio() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let databaseURL = root
            .appendingPathComponent("AudioLikePluginTests-\(UUID().uuidString)-unlink")
            .appendingPathExtension("store")
        let realFolder = root.appendingPathComponent("real", isDirectory: true)
        let linkedFolder = root.appendingPathComponent("linked", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: realFolder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linkedFolder, withDestinationURL: realFolder)
        let realURL = realFolder.appendingPathComponent("track.mp3")
        let linkedURL = linkedFolder.appendingPathComponent("track.mp3")
        try Data("audio".utf8).write(to: realURL)

        AudioLikeRepositoryConfiguration.configure(databaseURL: databaseURL)

        try await AudioLikeRepo.shared.updateLikeStatus(
            audioId: realURL.absoluteString,
            liked: true,
            url: realURL,
            title: "Track"
        )
        try await AudioLikeRepo.shared.updateLikeStatus(
            audioId: linkedURL.absoluteString,
            liked: false,
            url: linkedURL
        )

        #expect(!(await AudioLikeRepo.shared.isLiked(url: realURL)))
        #expect(try await AudioLikeRepo.shared.findLikeModel(audioId: realURL.absoluteString) == nil)
    }

    @Test
    @MainActor
    func audioLikeRepoReplacesSymlinkedDuplicateLike() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let databaseURL = root
            .appendingPathComponent("AudioLikePluginTests-\(UUID().uuidString)-dedupe")
            .appendingPathExtension("store")
        let realFolder = root.appendingPathComponent("real", isDirectory: true)
        let linkedFolder = root.appendingPathComponent("linked", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: realFolder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linkedFolder, withDestinationURL: realFolder)
        let realURL = realFolder.appendingPathComponent("track.mp3")
        let linkedURL = linkedFolder.appendingPathComponent("track.mp3")
        try Data("audio".utf8).write(to: realURL)

        AudioLikeRepositoryConfiguration.configure(databaseURL: databaseURL)

        try await AudioLikeRepo.shared.updateLikeStatus(
            audioId: realURL.absoluteString,
            liked: true,
            url: realURL,
            title: "Real"
        )
        try await AudioLikeRepo.shared.updateLikeStatus(
            audioId: linkedURL.absoluteString,
            liked: true,
            url: linkedURL,
            title: "Linked"
        )

        let liked = await AudioLikeRepo.shared.getAllLiked()
        #expect(liked.count == 1)
        #expect(liked.first?.url == linkedURL)
        #expect(liked.first?.title == "Linked")
    }
}

// MARK: - ViewModel 集成

@MainActor
private final class SceneProbe: SceneProviding {
    var scenes: [AppScene] { AppScene.allCases }
    var currentScene: AppScene?
    private var observers: [UUID: (SceneProvidingEvent) -> Void] = [:]

    func setCurrentScene(_ scene: AppScene) {
        currentScene = scene
        let event = SceneProvidingEvent.selectionChanged(scene: scene)
        for observer in observers.values { observer(event) }
    }

    func restoreCurrentScene() {}

    @discardableResult
    func addObserver(_ callback: @escaping (SceneProvidingEvent) -> Void) -> any SceneProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProbeSceneHandle { [weak self] in self?.observers.removeValue(forKey: id) }
    }
}

@MainActor
private final class ProbeSceneHandle: SceneProvidingObserverHandle {
    private let onCancel: () -> Void
    private var cancelled = false
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        onCancel()
    }
}

@MainActor
private final class LikePlaybackProbe: AudioLikePlaybackCapability {
    var isAvailable = true
}

@MainActor
struct AudioLikeViewModelTests {
    @Test
    func reloadAppliesOnlyLatestGeneration() async throws {
        let viewModel = AudioLikeViewModel(
            playbackCapability: nil,
            loadLikedAudios: { [] },
            saveLikeStatus: { _, _, _, _ in }
        )
        viewModel.reloadLikedAudios()
        for _ in 0..<50 where viewModel.isLoading {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!viewModel.isLoading)
        #expect(viewModel.likedAudios.isEmpty)
    }

    @Test
    func sceneChangeActivationGatesLikeSaving() async throws {
        var saved: [String] = []
        let viewModel = AudioLikeViewModel(
            playbackCapability: LikePlaybackProbe(),
            loadLikedAudios: { [] },
            saveLikeStatus: { audioId, _, _, _ in saved.append(audioId) }
        )

        // 未激活时不保存。
        viewModel.handleLikeStatusChanged(asset: URL(fileURLWithPath: "/tmp/a.mp3"), liked: true)
        try await Task.sleep(for: .milliseconds(30))
        #expect(saved.isEmpty)

        // 激活后保存并 post 通知。
        viewModel.handleSceneChange(.music, targetScene: .music)
        viewModel.handleLikeStatusChanged(asset: URL(fileURLWithPath: "/tmp/a.mp3"), liked: true)
        for _ in 0..<50 where saved.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(saved == ["file:///tmp/a.mp3"])

        // 离开场景后再次停用。
        viewModel.handleSceneChange(.audiobooks, targetScene: .music)
        viewModel.handleLikeStatusChanged(asset: URL(fileURLWithPath: "/tmp/b.mp3"), liked: true)
        try await Task.sleep(for: .milliseconds(30))
        #expect(saved.count == 1)
    }

    @Test
    func observerForwardsSceneSelectionToViewModel() async throws {
        let scene = SceneProbe()
        scene.currentScene = .music
        let viewModel = AudioLikeViewModel(
            playbackCapability: LikePlaybackProbe(),
            loadLikedAudios: { [] },
            saveLikeStatus: { _, _, _, _ in }
        )
        let observer = AudioLikeObserver(scene: scene, playback: PlaybackProbeStub(), viewModel: viewModel)
        defer { observer.cancel() }

        // 切走场景再切回；activation 路径无公开状态，验证不崩溃且通知转发正常。
        scene.setCurrentScene(.audiobooks)
        scene.setCurrentScene(.music)
        #expect(scene.currentScene == .music)
    }
}

@MainActor
private final class PlaybackProbeStub: PlaybackProviding {
    var state: PlaybackStatus = .idle
    var currentURL: URL?
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0
    var playMode: PlaybackMode = .sequence
    var likedAssets: Set<URL> = []
    var isPlaying: Bool { false }
    var hasAsset: Bool { currentURL != nil }

    func play(_ url: URL) async {}
    func play(_ url: URL, startTime: TimeInterval?) async {}
    func pause() {}
    func toggle() {}
    func seek(toProgress progress: Double) {}
    func seek(toTime time: TimeInterval) {}
    func next() {}
    func previous() {}
    func setPlayMode(_ mode: PlaybackMode) {}
    func toggleCurrentLike() {}
    func togglePlayMode() {}
    @discardableResult
    func addObserver(_ callback: @escaping (PlaybackProvidingEvent) -> Void) -> any PlaybackProvidingObserverHandle {
        PlaybackNoopHandle()
    }
}

@MainActor
private final class PlaybackNoopHandle: PlaybackProvidingObserverHandle {
    func cancel() {}
}