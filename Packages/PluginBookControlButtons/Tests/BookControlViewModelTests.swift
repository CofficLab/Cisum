import Foundation
import MagicKit
import MagicPlayMan
import ProviderPlayback
import ProviderScene
import Testing

@testable import PluginBookControlButtons

// MARK: - Mock Capabilities

@MainActor
private final class MockPlaybackCapability: BookControlPlaybackCapability {
    var isPlaying: Bool = false
    var playMode: PlaybackMode = .sequence
    var currentURL: URL?

    var toggleCount = 0
    var togglePlayModeCount = 0
    var playedURLs: [(url: URL, startTime: TimeInterval?)] = []
    var resetCount = 0

    func toggle() { toggleCount += 1 }
    func togglePlayMode() { togglePlayModeCount += 1 }

    func play(_ url: URL, startTime: TimeInterval?) async {
        playedURLs.append((url, startTime))
    }

    func reset() async { resetCount += 1 }

    @discardableResult
    func addObserver(_ callback: @escaping (BookControlPlaybackEvent) -> Void) -> any BookControlPlaybackObserverHandle {
        MockPlaybackHandle {}
    }
}

@MainActor
private final class MockPlaybackHandle: BookControlPlaybackObserverHandle {
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
private final class MockLibraryCapability: BookControlLibraryCapability {
    var bookDisk: URL? = URL(fileURLWithPath: "/tmp/books", isDirectory: true)

    @discardableResult
    func addObserver(_ callback: @escaping (BookControlLibraryEvent) -> Void) -> any BookControlLibraryObserverHandle {
        MockLibraryHandle {}
    }
}

@MainActor
private final class MockLibraryHandle: BookControlLibraryObserverHandle {
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
private final class MockToastCapability: BookControlToastCapability {
    var errorPresentations: [(title: String, message: String, sourceWindowID: String?)] = []

    func presentError(title: String, message: String, sourceWindowID: String?) {
        errorPresentations.append((title, message, sourceWindowID))
    }
}

// MARK: - BookControlViewModel Scene & State Tests

@MainActor
struct BookControlViewModelSceneTests {
    private let targetScene: AppScene = .audiobooks

    // MARK: - Initialization

    @Test
    func initWithNilPlaybackHasDefaultState() {
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: nil
        )

        #expect(!viewModel.isPlaying)
        #expect(viewModel.playMode == .sequence)
    }

    @Test
    func initWithPlaybackAdoptsPlaybackState() {
        let playback = MockPlaybackCapability()
        playback.isPlaying = true
        playback.playMode = .loop

        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: playback
        )

        #expect(viewModel.isPlaying)
        #expect(viewModel.playMode == .loop)
    }

    // MARK: - Scene activation

    @Test
    func sceneChangeToTargetActivatesControl() {
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability()
        )

        #expect(!viewModel.shouldActivateControl)

        viewModel.handleSceneChange(.audiobooks)

        #expect(viewModel.shouldActivateControl)
    }

    @Test
    func sceneChangeToOtherSceneDeactivatesControl() {
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability()
        )

        viewModel.handleSceneChange(.audiobooks)
        #expect(viewModel.shouldActivateControl)

        viewModel.handleSceneChange(.music)
        #expect(!viewModel.shouldActivateControl)
    }

    @Test
    func sceneChangeToNilDeactivatesControl() {
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability()
        )

        viewModel.handleSceneChange(.audiobooks)
        viewModel.handleSceneChange(nil)

        #expect(!viewModel.shouldActivateControl)
    }

    // MARK: - State updates

    @Test
    func applyStateChangedUpdatesIsPlaying() {
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability()
        )

        viewModel.applyStateChanged(.playing)
        #expect(viewModel.isPlaying)

        viewModel.applyStateChanged(.paused)
        #expect(!viewModel.isPlaying)

        viewModel.applyStateChanged(.idle)
        #expect(!viewModel.isPlaying)
    }

    @Test
    func applyPlayModeChangedUpdatesPlayMode() {
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability()
        )

        viewModel.applyPlayModeChanged(.loop)
        #expect(viewModel.playMode == .loop)

        viewModel.applyPlayModeChanged(.shuffle)
        #expect(viewModel.playMode == .shuffle)

        viewModel.applyPlayModeChanged(.repeatAll)
        #expect(viewModel.playMode == .repeatAll)
    }

    // MARK: - Toggle

    @Test
    func toggleCallsPlaybackToggle() {
        let playback = MockPlaybackCapability()
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: playback
        )

        viewModel.toggle()

        #expect(playback.toggleCount == 1)
    }

    @Test
    func toggleWithNilPlaybackReportsError() {
        let toast = MockToastCapability()
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: nil,
            toast: toast
        )

        viewModel.toggle()

        #expect(toast.errorPresentations.count == 1)
    }

    // MARK: - Toggle play mode

    @Test
    func togglePlayModeCallsPlaybackTogglePlayMode() {
        let playback = MockPlaybackCapability()
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: playback
        )

        viewModel.togglePlayMode()

        #expect(playback.togglePlayModeCount == 1)
    }

    @Test
    func togglePlayModeWithNilPlaybackReportsError() {
        let toast = MockToastCapability()
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: nil,
            toast: toast
        )

        viewModel.togglePlayMode()

        #expect(toast.errorPresentations.count == 1)
    }

    // MARK: - Previous / Next without current asset

    @Test
    func previousWithNoCurrentURLReportsError() {
        let playback = MockPlaybackCapability()
        playback.currentURL = nil
        let toast = MockToastCapability()
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: playback,
            toast: toast
        )
        viewModel.handleSceneChange(.audiobooks)

        viewModel.previous()

        #expect(toast.errorPresentations.count == 1)
    }

    @Test
    func nextWithNoCurrentURLReportsError() {
        let playback = MockPlaybackCapability()
        playback.currentURL = nil
        let toast = MockToastCapability()
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: playback,
            toast: toast
        )
        viewModel.handleSceneChange(.audiobooks)

        viewModel.next()

        #expect(toast.errorPresentations.count == 1)
    }

    // MARK: - Source window ID

    @Test
    func setSourceWindowIDIsUsedInErrorPresentation() {
        let toast = MockToastCapability()
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: nil,
            toast: toast
        )

        viewModel.setSourceWindowID("window-123")
        viewModel.toggle()

        #expect(toast.errorPresentations.first?.sourceWindowID == "window-123")
    }

    // MARK: - DB deletion handling

    @Test
    func handleBookDBRefreshedClearsChapterCache() {
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability(),
            library: MockLibraryCapability()
        )

        // Should not crash when called
        viewModel.handleBookDBRefreshed()
    }

    @Test
    func handleStorageLocationDidResetWithNilPlaybackDoesNotCrash() {
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: nil,
            library: MockLibraryCapability()
        )
        viewModel.handleSceneChange(.audiobooks)

        // Should not crash
        viewModel.handleStorageLocationDidReset()
    }

    @Test
    func handleBookDBDeletedWithNilPlaybackDoesNotCrash() {
        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: nil,
            library: MockLibraryCapability()
        )
        viewModel.handleSceneChange(.audiobooks)

        // Should not crash
        viewModel.handleBookDBDeleted(deletedURLs: [URL(fileURLWithPath: "/tmp/book")])
    }

    // MARK: - Navigation with inactive scene

    @Test
    func handlePreviousRequestedWithInactiveSceneDoesNotNavigate() async {
        let playback = MockPlaybackCapability()
        playback.currentURL = URL(fileURLWithPath: "/tmp/books/Novel/01.m4b")

        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: playback,
            library: MockLibraryCapability()
        )
        // Scene is NOT activated (default nil)

        viewModel.handlePreviousRequested(URL(fileURLWithPath: "/tmp/books/Novel/01.m4b"))

        try? await Task.sleep(for: .milliseconds(100))
        #expect(playback.playedURLs.isEmpty)
    }

    @Test
    func handleNextRequestedWithInactiveSceneDoesNotNavigate() async {
        let playback = MockPlaybackCapability()
        playback.currentURL = URL(fileURLWithPath: "/tmp/books/Novel/01.m4b")

        let viewModel = BookControlViewModel(
            targetScene: targetScene,
            playback: playback,
            library: MockLibraryCapability()
        )
        // Scene is NOT activated

        viewModel.handleNextRequested(URL(fileURLWithPath: "/tmp/books/Novel/01.m4b"))

        try? await Task.sleep(for: .milliseconds(100))
        #expect(playback.playedURLs.isEmpty)
    }
}
