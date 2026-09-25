import ProviderToast
import Foundation
import MagicPlayMan
import ProviderPlayback
import Testing
@testable import PluginAudioControlButtons

@Test func navigationOnlyAppliesToTheRequestedCurrentAsset() {
    let requested = URL(fileURLWithPath: "/tmp/requested.mp3")
    let switched = URL(fileURLWithPath: "/tmp/switched.mp3")

    #expect(ControlButtonsPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: requested,
        isSceneActive: true
    ))
    #expect(!ControlButtonsPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: switched,
        isSceneActive: true
    ))
    #expect(!ControlButtonsPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: requested,
        isSceneActive: false
    ))
}

@Test func deletionMatchesTheCurrentAssetButNotAnotherAsset() {
    let current = URL(fileURLWithPath: "/tmp/current.mp3")
    let other = URL(fileURLWithPath: "/tmp/other.mp3")

    #expect(ControlButtonsPlaybackRequestPolicy.currentAssetAffectedByDeletion(
        currentAsset: current,
        deletedURLs: [current]
    ))
    #expect(!ControlButtonsPlaybackRequestPolicy.currentAssetAffectedByDeletion(
        currentAsset: current,
        deletedURLs: [other]
    ))
}

@Test func deactivationInvalidatesPendingRequests() {
    let generation = ControlButtonsPlaybackRequestPolicy.generationAfterDeactivation(2)

    #expect(generation == 3)
    #expect(!ControlButtonsPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: URL(fileURLWithPath: "/tmp/requested.mp3"),
        currentAsset: URL(fileURLWithPath: "/tmp/requested.mp3"),
        isSceneActive: true,
        currentGeneration: generation,
        requestGeneration: 2
    ))
}

// MARK: - ViewModel 集成

@MainActor
private final class PlaybackProbe: PlaybackCapability {
    var currentURL: URL?
    var isPlaying = false
    var playMode: MagicPlayMode = .sequence
    var toggleCount = 0
    var togglePlayModeCount = 0
    var playedURLs: [URL] = []
    var resetCount = 0

    func toggle() { toggleCount += 1 }
    func togglePlayMode() { togglePlayModeCount += 1 }
    func play(_ url: URL) async { playedURLs.append(url) }
    func reset() async { resetCount += 1 }
}

@MainActor
private final class NavigationProbe: NavigationCapability {
    var nextResult: Result<URL?, Error> = .success(nil)
    var previousResult: Result<URL?, Error> = .success(nil)
    var firstURLValue: URL?
    var lastURLValue: URL?

    func nextURL(after current: URL?) async throws -> URL? { try nextResult.get() }
    func previousURL(before current: URL?) async throws -> URL? { try previousResult.get() }
    func firstURL() async throws -> URL? { firstURLValue }
    func lastURL() async throws -> URL? { lastURLValue }
}

@MainActor
private final class ToastProbe: ToastProviding {
    var errors: [(title: String, message: String)] = []
    var infos: [String] = []

    func show(_ toast: CisumToast) { infos.append(toast.title) }
    func presentError(title: String, message: String) { errors.append((title, message)) }
    func dismissError() {}
    func showLoading(title: String, detail: String?) {}
    func dismissLoading() {}
    func dismissAll() {}
}

@MainActor
struct ControlButtonsViewModelTests {
    @Test
    func initReflectsPlaybackState() {
        let playback = PlaybackProbe()
        playback.isPlaying = true
        playback.playMode = .shuffle
        let viewModel = ControlButtonsViewModel(
            playbackCapability: playback,
            targetScene: .music,
            currentScene: .music
        )
        #expect(viewModel.isPlaying)
        #expect(viewModel.playMode == .shuffle)
        #expect(viewModel.shouldActivateControl)
    }

    @Test
    func sceneMismatchDeactivatesControl() {
        let viewModel = ControlButtonsViewModel(
            playbackCapability: nil,
            targetScene: .music,
            currentScene: .audiobooks
        )
        #expect(!viewModel.shouldActivateControl)
    }

    @Test
    func applyStateChangedTracksPlaying() {
        let viewModel = ControlButtonsViewModel(playbackCapability: nil, targetScene: .music)
        viewModel.applyStateChanged(.playing)
        #expect(viewModel.isPlaying)
        viewModel.applyStateChanged(.paused)
        #expect(!viewModel.isPlaying)
        viewModel.applyStateChanged(.idle)
        #expect(!viewModel.isPlaying)
    }

    @Test
    func failureStatePresentsErrorOnce() {
        let toast = ToastProbe()
        let viewModel = ControlButtonsViewModel(
            playbackCapability: nil,
            toastProvider: toast,
            targetScene: .music
        )

        viewModel.applyStateChanged(.failed(.invalidAsset))
        #expect(toast.errors.count == 1)

        // 相同失败不重复弹窗。
        viewModel.applyStateChanged(.failed(.invalidAsset))
        #expect(toast.errors.count == 1)

        // 不同失败再次弹窗。
        viewModel.applyStateChanged(.failed(.noAsset))
        #expect(toast.errors.count == 2)

        // 恢复后同失败可再次弹窗。
        viewModel.applyStateChanged(.playing)
        viewModel.applyStateChanged(.failed(.invalidAsset))
        #expect(toast.errors.count == 3)
    }

    @Test
    func sceneChangeInvalidatesPendingNavigation() async throws {
        let playback = PlaybackProbe()
        let current = URL(fileURLWithPath: "/tmp/current.mp3")
        let next = URL(fileURLWithPath: "/tmp/next.mp3")
        playback.currentURL = current
        let navigation = NavigationProbe()
        navigation.nextResult = .success(next)

        let viewModel = ControlButtonsViewModel(
            playbackCapability: playback,
            navigationCapability: navigation,
            targetScene: .music,
            currentScene: .music
        )
        viewModel.handleNextRequested(current)
        // 导航尚未完成时切走场景 → 代际失效。
        viewModel.handleSceneChange(.audiobooks)

        try await Task.sleep(for: .milliseconds(50))
        #expect(playback.playedURLs.isEmpty)
    }

    @Test
    func nextNavigatesAndPlays() async throws {
        let playback = PlaybackProbe()
        let current = URL(fileURLWithPath: "/tmp/current.mp3")
        let next = URL(fileURLWithPath: "/tmp/next.mp3")
        playback.currentURL = current
        let navigation = NavigationProbe()
        navigation.nextResult = .success(next)

        let viewModel = ControlButtonsViewModel(
            playbackCapability: playback,
            navigationCapability: navigation,
            targetScene: .music,
            currentScene: .music
        )
        viewModel.handleNextRequested(current)

        for _ in 0..<50 where playback.playedURLs.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(playback.playedURLs == [next])
    }

    @Test
    func nextAtEndWithoutRepeatAllPresentsError() async throws {
        let playback = PlaybackProbe()
        let current = URL(fileURLWithPath: "/tmp/current.mp3")
        playback.currentURL = current
        playback.playMode = .sequence
        let navigation = NavigationProbe()
        navigation.nextResult = .success(nil)
        let toast = ToastProbe()

        let viewModel = ControlButtonsViewModel(
            playbackCapability: playback,
            navigationCapability: navigation,
            toastProvider: toast,
            targetScene: .music,
            currentScene: .music
        )
        viewModel.handleNextRequested(current)

        for _ in 0..<50 where toast.errors.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!toast.errors.isEmpty)
        #expect(playback.playedURLs.isEmpty)
    }

    @Test
    func previousAtStartWithoutRepeatAllPresentsError() async throws {
        let playback = PlaybackProbe()
        let current = URL(fileURLWithPath: "/tmp/current.mp3")
        playback.currentURL = current
        let navigation = NavigationProbe()
        navigation.previousResult = .success(nil)
        let toast = ToastProbe()

        let viewModel = ControlButtonsViewModel(
            playbackCapability: playback,
            navigationCapability: navigation,
            toastProvider: toast,
            targetScene: .music,
            currentScene: .music
        )
        viewModel.handlePreviousRequested(current)

        for _ in 0..<50 where toast.errors.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!toast.errors.isEmpty)
        #expect(playback.playedURLs.isEmpty)
    }

    @Test
    func nextWithRepeatAllFallsBackToFirst() async throws {
        let playback = PlaybackProbe()
        let current = URL(fileURLWithPath: "/tmp/current.mp3")
        let first = URL(fileURLWithPath: "/tmp/first.mp3")
        playback.currentURL = current
        playback.playMode = .repeatAll
        let navigation = NavigationProbe()
        navigation.nextResult = .success(nil)
        navigation.firstURLValue = first

        let viewModel = ControlButtonsViewModel(
            playbackCapability: playback,
            navigationCapability: navigation,
            targetScene: .music,
            currentScene: .music
        )
        viewModel.handleNextRequested(current)

        for _ in 0..<50 where playback.playedURLs.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(playback.playedURLs == [first])
    }

    @Test
    func previousWithoutCapabilityReportsUnavailable() {
        let toast = ToastProbe()
        let viewModel = ControlButtonsViewModel(
            playbackCapability: nil,
            navigationCapability: nil,
            toastProvider: toast,
            targetScene: .music,
            currentScene: .music
        )
        viewModel.previous()
        #expect(!toast.errors.isEmpty)
    }

    @Test
    func toggleWithoutCapabilityReportsUnavailable() {
        let toast = ToastProbe()
        let viewModel = ControlButtonsViewModel(
            playbackCapability: nil,
            toastProvider: toast,
            targetScene: .music,
            currentScene: .music
        )
        viewModel.toggle()
        #expect(!toast.errors.isEmpty)
    }

    @Test
    func deletionOfCurrentAssetResetsPlayback() async throws {
        let playback = PlaybackProbe()
        let current = URL(fileURLWithPath: "/tmp/deleted.mp3")
        playback.currentURL = current

        let viewModel = ControlButtonsViewModel(
            playbackCapability: playback,
            navigationCapability: nil,
            targetScene: .music,
            currentScene: .music
        )
        viewModel.handleDBDeleted(urlsToDelete: [current])

        for _ in 0..<50 where playback.resetCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(playback.resetCount == 1)
    }

    @Test
    func deletionOfUnrelatedAssetIsIgnored() async throws {
        let playback = PlaybackProbe()
        playback.currentURL = URL(fileURLWithPath: "/tmp/kept.mp3")

        let viewModel = ControlButtonsViewModel(
            playbackCapability: playback,
            navigationCapability: nil,
            targetScene: .music,
            currentScene: .music
        )
        viewModel.handleDBDeleted(urlsToDelete: [URL(fileURLWithPath: "/tmp/other.mp3")])

        try await Task.sleep(for: .milliseconds(50))
        #expect(playback.resetCount == 0)
    }
}