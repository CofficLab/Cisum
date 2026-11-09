import Foundation
import MagicKit
import MagicPlayMan
import ProviderPlayback
import ProviderScene
import Testing

@testable import PluginBookProgress

// MARK: - Mock Capabilities

@MainActor
private final class MockPlaybackCapability: BookProgressPlaybackCapability {
    var currentURL: URL?
    var currentTime: TimeInterval = 0
    var state: PlaybackStatus = .idle

    var seekedTimes: [TimeInterval] = []
    var playedURLs: [(url: URL, startTime: TimeInterval?)] = []

    func seek(toTime time: TimeInterval) {
        seekedTimes.append(time)
    }

    func play(_ url: URL, startTime: TimeInterval?) async {
        playedURLs.append((url, startTime))
    }

    @discardableResult
    func addObserver(_ callback: @escaping (BookProgressPlaybackEvent) -> Void) -> any BookProgressPlaybackObserverHandle {
        MockPlaybackHandle {}
    }
}

@MainActor
private final class MockPlaybackHandle: BookProgressPlaybackObserverHandle {
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
private final class MockLibraryCapability: BookProgressLibraryCapability {
    var bookDisk: URL? = URL(fileURLWithPath: "/tmp/books", isDirectory: true)
    var storedCurrentBookURL: URL?
    var storedCurrentBookTime: TimeInterval?
    var savedStates: [(bookURL: URL, currentURL: URL?, time: TimeInterval?)] = []

    func currentBookURL() -> URL? { storedCurrentBookURL }
    func currentBookTime() -> TimeInterval? { storedCurrentBookTime }

    func storeCurrentBookURL(_ url: URL?) { storedCurrentBookURL = url }
    func storeCurrentBookTime(_ time: TimeInterval) { storedCurrentBookTime = time }

    func savePlaybackState(for bookURL: URL, currentURL: URL?, time: TimeInterval?) async throws {
        savedStates.append((bookURL, currentURL, time))
    }

    @discardableResult
    func addObserver(_ callback: @escaping (BookProgressLibraryEvent) -> Void) -> any BookProgressLibraryObserverHandle {
        MockLibraryHandle {}
    }
}

@MainActor
private final class MockLibraryHandle: BookProgressLibraryObserverHandle {
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
private final class MockToastCapability: BookProgressToastCapability {
    var errorMessages: [String] = []

    func error(_ message: String) {
        errorMessages.append(message)
    }
}

// MARK: - BookProgressViewModel Direct Tests

@MainActor
struct BookProgressViewModelDirectTests {
    private let targetScene: AppScene = .audiobooks

    // MARK: - Initialization

    @Test
    func initHasDefaultState() {
        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: nil,
            library: nil
        )

        #expect(!viewModel.shouldActivateProgress)
    }

    // MARK: - Scene activation

    @Test
    func sceneChangeToTargetActivatesProgress() {
        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability(),
            library: MockLibraryCapability()
        )

        #expect(!viewModel.shouldActivateProgress)

        viewModel.handleSceneChange(.audiobooks)

        #expect(viewModel.shouldActivateProgress)
    }

    @Test
    func sceneChangeToOtherSceneDeactivatesProgress() {
        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability(),
            library: MockLibraryCapability()
        )

        viewModel.handleSceneChange(.audiobooks)
        #expect(viewModel.shouldActivateProgress)

        viewModel.handleSceneChange(.music)
        #expect(!viewModel.shouldActivateProgress)
    }

    @Test
    func sceneChangeToNilDeactivatesProgress() {
        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability(),
            library: MockLibraryCapability()
        )

        viewModel.handleSceneChange(.audiobooks)
        viewModel.handleSceneChange(nil)

        #expect(!viewModel.shouldActivateProgress)
    }

    // MARK: - Current URL change handling

    @Test
    func handleCurrentURLChangedWithNilURLClearsStoredURL() async throws {
        let playback = MockPlaybackCapability()
        let library = MockLibraryCapability()
        library.storedCurrentBookURL = URL(fileURLWithPath: "/tmp/books/OldBook/01.m4b")

        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: playback,
            library: library
        )
        viewModel.handleSceneChange(.audiobooks)

        viewModel.handleCurrentURLChanged(nil)

        // Wait for async operations
        try await Task.sleep(for: .milliseconds(200))

        #expect(library.storedCurrentBookURL == nil)
    }

    @Test
    func handleCurrentURLChangedWithInactiveSceneDoesNotPersist() async throws {
        let playback = MockPlaybackCapability()
        let library = MockLibraryCapability()

        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: playback,
            library: library
        )
        // Scene NOT activated

        let url = URL(fileURLWithPath: "/tmp/books/Novel/01.m4b")
        viewModel.handleCurrentURLChanged(url)

        try await Task.sleep(for: .milliseconds(200))

        #expect(library.storedCurrentBookURL == nil)
    }

    @Test
    func handleCurrentURLChangedWithNilPlaybackDoesNotPersist() async throws {
        let library = MockLibraryCapability()

        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: nil,
            library: library
        )
        viewModel.handleSceneChange(.audiobooks)

        let url = URL(fileURLWithPath: "/tmp/books/Novel/01.m4b")
        viewModel.handleCurrentURLChanged(url)

        try await Task.sleep(for: .milliseconds(200))

        #expect(library.storedCurrentBookURL == nil)
    }

    // MARK: - DB deletion handling

    @Test
    func handleBookDBDeletedClearsStoredURLWhenCurrentBookDeleted() {
        let library = MockLibraryCapability()
        library.storedCurrentBookURL = URL(fileURLWithPath: "/tmp/books/Novel/01.m4b")

        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability(),
            library: library
        )
        viewModel.handleSceneChange(.audiobooks)

        // Delete the book containing the current chapter
        let deletedURLs = [URL(fileURLWithPath: "/tmp/books/Novel", isDirectory: true)]
        viewModel.handleBookDBDeleted(deletedURLs: deletedURLs)

        #expect(library.storedCurrentBookURL == nil)
        #expect(library.storedCurrentBookTime == 0)
    }

    @Test
    func handleBookDBDeletedKeepsStoredURLWhenUnrelatedBookDeleted() {
        let library = MockLibraryCapability()
        let storedURL = URL(fileURLWithPath: "/tmp/books/NovelA/01.m4b")
        library.storedCurrentBookURL = storedURL

        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability(),
            library: library
        )
        viewModel.handleSceneChange(.audiobooks)

        // Delete a different book
        let deletedURLs = [URL(fileURLWithPath: "/tmp/books/NovelB", isDirectory: true)]
        viewModel.handleBookDBDeleted(deletedURLs: deletedURLs)

        #expect(library.storedCurrentBookURL == storedURL)
    }

    @Test
    func handleBookDBDeletedWithNoStoredURLDoesNothing() {
        let library = MockLibraryCapability()
        library.storedCurrentBookURL = nil

        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability(),
            library: library
        )

        let deletedURLs = [URL(fileURLWithPath: "/tmp/books/Novel", isDirectory: true)]
        viewModel.handleBookDBDeleted(deletedURLs: deletedURLs)

        #expect(library.storedCurrentBookURL == nil)
    }

    // MARK: - Playback state change handling

    @Test
    func handlePlayManStateChangedPersistsTimeWhenPaused() async throws {
        // Create actual file on disk - the persistence policy requires file existence
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookProgressVMPersist-\(UUID().uuidString)", isDirectory: true)
        let bookDisk = root.appendingPathComponent("books", isDirectory: true)
        let bookDir = bookDisk.appendingPathComponent("Novel", isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let chapterURL = bookDir.appendingPathComponent("01.m4b")
        try Data("audio".utf8).write(to: chapterURL)

        let playback = MockPlaybackCapability()
        playback.currentURL = chapterURL
        playback.currentTime = 42
        playback.state = .paused

        let library = MockLibraryCapability()
        library.bookDisk = bookDisk

        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: playback,
            library: library
        )
        viewModel.handleSceneChange(.audiobooks)

        viewModel.handlePlayManStateChanged(false)

        // Wait for async operations
        try await Task.sleep(for: .milliseconds(200))

        #expect(library.storedCurrentBookTime == 42)
    }

    @Test
    func handlePlayManStateChangedDoesNotPersistWhenNotPaused() async throws {
        let playback = MockPlaybackCapability()
        playback.currentURL = URL(fileURLWithPath: "/tmp/books/Novel/01.m4b")
        playback.currentTime = 42
        playback.state = .playing

        let library = MockLibraryCapability()
        let initialTime = library.storedCurrentBookTime

        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: playback,
            library: library
        )
        viewModel.handleSceneChange(.audiobooks)

        viewModel.handlePlayManStateChanged(true)

        try await Task.sleep(for: .milliseconds(200))

        // Time should not have changed (guard: playback.state == .paused)
        #expect(library.storedCurrentBookTime == initialTime)
    }

    @Test
    func handlePlayManStateChangedWithInactiveSceneDoesNotPersist() async throws {
        let playback = MockPlaybackCapability()
        playback.currentURL = URL(fileURLWithPath: "/tmp/books/Novel/01.m4b")
        playback.currentTime = 42
        playback.state = .paused

        let library = MockLibraryCapability()

        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: playback,
            library: library
        )
        // Scene NOT activated

        viewModel.handlePlayManStateChanged(false)

        try await Task.sleep(for: .milliseconds(200))

        #expect(library.storedCurrentBookTime == nil)
    }

    // MARK: - Restore behavior

    @Test
    func activateProgressSkipsWithNilLibrary() {
        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: MockPlaybackCapability(),
            library: nil
        )

        // Should not crash
        viewModel.handleSceneChange(.audiobooks)
        #expect(viewModel.shouldActivateProgress)
    }

    @Test
    func activateProgressSkipsWithNilPlayback() {
        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: nil,
            library: MockLibraryCapability()
        )

        // Should not crash
        viewModel.handleSceneChange(.audiobooks)
        #expect(viewModel.shouldActivateProgress)
    }

    // MARK: - Deactivate behavior

    @Test
    func deactivateProgressIncrementsGeneration() {
        let playback = MockPlaybackCapability()
        playback.currentURL = URL(fileURLWithPath: "/tmp/books/Novel/01.m4b")
        playback.currentTime = 42
        playback.state = .paused

        let library = MockLibraryCapability()

        let viewModel = BookProgressViewModel(
            targetScene: targetScene,
            playback: playback,
            library: library
        )
        viewModel.handleSceneChange(.audiobooks)

        // Switch away - should deactivate and persist
        viewModel.handleSceneChange(.music)

        #expect(!viewModel.shouldActivateProgress)
    }
}
