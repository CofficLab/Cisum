import ProviderToast
import MagicPlayMan
import Testing
import SwiftUI
@testable import PluginBookControlButtons

@Test @MainActor func pluginInfoExportsRegistrationMetadata() {
    #expect(BookControlButtonsPlugin().iconName == "playpause")
    #expect(BookControlButtonsPlugin().order == 8)
}

@Test @MainActor func repeatAllWrapsBookChapterNavigation() {
    let chapters = [
        URL(fileURLWithPath: "/tmp/book/001.m4b"),
        URL(fileURLWithPath: "/tmp/book/002.m4b"),
        URL(fileURLWithPath: "/tmp/book/003.m4b"),
    ]

    let next = BookControlChapterLoader.adjacentAsset(
        in: chapters,
        current: chapters[2],
        offset: 1,
        playMode: .repeatAll
    )
    let previous = BookControlChapterLoader.adjacentAsset(
        in: chapters,
        current: chapters[0],
        offset: -1,
        playMode: .repeatAll
    )
    let sequenceNext = BookControlChapterLoader.adjacentAsset(
        in: chapters,
        current: chapters[2],
        offset: 1,
        playMode: .sequence
    )

    #expect(next == chapters[0])
    #expect(previous == chapters[2])
    #expect(sequenceNext == nil)
}

@Test @MainActor func chapterNavigationMatchesSymlinkedCurrentChapter() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    let currentChapter = realBook.appendingPathComponent("001.m4b")
    let nextChapter = realBook.appendingPathComponent("002.m4b")
    try Data("audio".utf8).write(to: currentChapter)
    try Data("audio".utf8).write(to: nextChapter)

    let chapters = BookControlChapterLoader.playableChapters(in: linkedBook)
    let next = BookControlChapterLoader.adjacentAsset(
        in: chapters,
        current: currentChapter,
        offset: 1,
        playMode: .sequence
    )

    #expect(next == linkedBook.appendingPathComponent("002.m4b"))
}

@Test @MainActor func shuffledChapterCandidatesExcludeSymlinkedCurrentChapter() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    let realCurrentChapter = realBook.appendingPathComponent("001.m4b")
    let linkedCurrentChapter = linkedBook.appendingPathComponent("001.m4b")
    let linkedNextChapter = linkedBook.appendingPathComponent("002.m4b")
    try Data("audio".utf8).write(to: realCurrentChapter)
    try Data("audio".utf8).write(to: realBook.appendingPathComponent("002.m4b"))

    let candidates = BookControlChapterLoader.shuffleCandidates(
        in: [linkedCurrentChapter, linkedNextChapter],
        current: realCurrentChapter
    )

    #expect(candidates == [linkedNextChapter])
}

@Test @MainActor func shuffledChapterCandidatesKeepDistinctDanglingSymlinkedChapters() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingBook = root.appendingPathComponent("MissingBook", isDirectory: true)
    let firstLink = root.appendingPathComponent("FirstBook", isDirectory: true)
    let secondLink = root.appendingPathComponent("SecondBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingBook)
    try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingBook)

    let firstChapter = firstLink.appendingPathComponent("001.m4b")
    let secondChapter = secondLink.appendingPathComponent("001.m4b")
    let candidates = BookControlChapterLoader.shuffleCandidates(
        in: [firstChapter, secondChapter],
        current: firstChapter
    )

    #expect(candidates == [secondChapter])
}

@Test @MainActor func navigationResultOnlyAppliesToUnchangedCurrentChapter() {
    let requested = URL(fileURLWithPath: "/tmp/book/001.m4b")
    let switched = URL(fileURLWithPath: "/tmp/book/002.m4b")

    #expect(BookControlPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: requested,
        isSceneActive: true
    ))
    #expect(!BookControlPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: switched,
        isSceneActive: true
    ))
    #expect(!BookControlPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: nil,
        isSceneActive: true
    ))
    #expect(!BookControlPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: requested,
        isSceneActive: false
    ))
}

@Test @MainActor func navigationResultAppliesToSymlinkedCurrentChapter() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    let realChapter = realBook.appendingPathComponent("001.m4b")
    let linkedChapter = linkedBook.appendingPathComponent("001.m4b")
    try Data("audio".utf8).write(to: realChapter)

    #expect(BookControlPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: linkedChapter,
        currentAsset: realChapter,
        isSceneActive: true
    ))
}

@Test @MainActor func navigationResultDoesNotApplyToDistinctDanglingSymlinkedChapters() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingBook = root.appendingPathComponent("MissingBook", isDirectory: true)
    let firstLink = root.appendingPathComponent("FirstBook", isDirectory: true)
    let secondLink = root.appendingPathComponent("SecondBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingBook)
    try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingBook)

    #expect(!BookControlPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: firstLink.appendingPathComponent("001.m4b"),
        currentAsset: secondLink.appendingPathComponent("001.m4b"),
        isSceneActive: true
    ))
}

@Test @MainActor func staleNavigationDoesNotApplyAfterSceneReactivation() {
    let requested = URL(fileURLWithPath: "/tmp/book/001.m4b")
    let generation = BookControlPlaybackRequestPolicy.generationAfterDeactivation(2)

    #expect(BookControlPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: requested,
        isSceneActive: true,
        currentGeneration: 2,
        requestGeneration: 2
    ))
    #expect(!BookControlPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: requested,
        isSceneActive: true,
        currentGeneration: generation,
        requestGeneration: 2
    ))
}

@Test @MainActor func navigationRejectsCurrentAudioOutsideConfiguredBookDisk() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bookDisk = root.appendingPathComponent("books", isDirectory: true)
    let outside = root.appendingPathComponent("outside", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: bookDisk, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)

    let chapter = bookDisk
        .appendingPathComponent("Novel", isDirectory: true)
        .appendingPathComponent("Chapter 01.m4b")
    try FileManager.default.createDirectory(
        at: chapter.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data("book".utf8).write(to: chapter)

    let outsideAudio = outside.appendingPathComponent("Track.m4b")
    try Data("audio".utf8).write(to: outsideAudio)

    #expect(BookControlPlaybackRequestPolicy.shouldNavigateBookAsset(chapter, bookDisk: bookDisk))
    #expect(!BookControlPlaybackRequestPolicy.shouldNavigateBookAsset(outsideAudio, bookDisk: bookDisk))
    #expect(BookControlPlaybackRequestPolicy.shouldNavigateBookAsset(outsideAudio, bookDisk: nil))
}

@Test @MainActor func deletionAffectsCurrentChapterInsideDeletedBook() {
    let deletedBook = URL(fileURLWithPath: "/tmp/books/Novel", isDirectory: true)
    let currentChapter = deletedBook.appendingPathComponent("Chapter 01.m4b")
    let otherChapter = URL(fileURLWithPath: "/tmp/books/Other/Chapter 01.m4b")

    #expect(BookControlPlaybackRequestPolicy.currentAssetAffectedByDeletion(
        currentAsset: currentChapter,
        deletedURLs: [deletedBook]
    ))
    #expect(!BookControlPlaybackRequestPolicy.currentAssetAffectedByDeletion(
        currentAsset: otherChapter,
        deletedURLs: [deletedBook]
    ))
    #expect(!BookControlPlaybackRequestPolicy.currentAssetAffectedByDeletion(
        currentAsset: nil,
        deletedURLs: [deletedBook]
    ))
}

@Test @MainActor func deletionAffectsCurrentChapterThroughSymlinkedBook() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    let currentChapter = realBook.appendingPathComponent("Chapter 01.m4b")
    try Data("audio".utf8).write(to: currentChapter)

    #expect(BookControlPlaybackRequestPolicy.currentAssetAffectedByDeletion(
        currentAsset: currentChapter,
        deletedURLs: [linkedBook]
    ))
}

@Test @MainActor func deletionAffectsCurrentChapterUnderDanglingSymlinkedBook() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingBook = root.appendingPathComponent("MissingBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    let currentChapter = linkedBook.appendingPathComponent("Chapter 01.m4b")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: missingBook)

    #expect(BookControlPlaybackRequestPolicy.currentAssetAffectedByDeletion(
        currentAsset: currentChapter,
        deletedURLs: [linkedBook]
    ))
}

@Test @MainActor func deletionDoesNotAffectDistinctDanglingSymlinkedBook() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingBook = root.appendingPathComponent("MissingBook", isDirectory: true)
    let firstLink = root.appendingPathComponent("FirstBook", isDirectory: true)
    let secondLink = root.appendingPathComponent("SecondBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingBook)
    try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingBook)

    #expect(!BookControlPlaybackRequestPolicy.currentAssetAffectedByDeletion(
        currentAsset: secondLink.appendingPathComponent("Chapter 01.m4b"),
        deletedURLs: [firstLink]
    ))
}

@MainActor
@Test func bookDeletionInvalidatesChapterCacheEvenWhenCurrentChapterSurvives() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        BookControlChapterCache.removeAll()
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let current = root.appendingPathComponent("001.m4b")
    let deleted = root.appendingPathComponent("002.m4b")
    try Data("audio".utf8).write(to: current)
    try Data("audio".utf8).write(to: deleted)

    BookControlChapterCache.removeAll()
    BookControlChapterCache.store([current, deleted], in: root)

    #expect(!BookControlPlaybackRequestPolicy.currentAssetAffectedByDeletion(
        currentAsset: current,
        deletedURLs: [deleted]
    ))
    #expect(BookControlPlaybackRequestPolicy.shouldInvalidateChapterCacheAfterDeletion(deletedURLs: [deleted]))

    if BookControlPlaybackRequestPolicy.shouldInvalidateChapterCacheAfterDeletion(deletedURLs: [deleted]) {
        BookControlChapterCache.removeAll()
    }

    #expect(BookControlChapterCache.cachedChapters(in: root) == nil)
}

@MainActor
@Test func bookLibraryRefreshInvalidatesChapterCacheForNewChapters() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        BookControlChapterCache.removeAll()
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let first = root.appendingPathComponent("001.m4b")
    try Data("audio".utf8).write(to: first)

    BookControlChapterCache.removeAll()
    BookControlChapterCache.store([first], in: root)

    #expect(BookControlChapterCache.cachedChapters(in: root) == [first])
    #expect(BookControlPlaybackRequestPolicy.shouldInvalidateChapterCacheAfterLibraryRefresh())

    if BookControlPlaybackRequestPolicy.shouldInvalidateChapterCacheAfterLibraryRefresh() {
        BookControlChapterCache.removeAll()
    }

    #expect(BookControlChapterCache.cachedChapters(in: root) == nil)
}

@Test @MainActor func staleDeletionResetDoesNotApplyAfterSceneReactivation() {
    let deletedBook = URL(fileURLWithPath: "/tmp/books/Novel", isDirectory: true)
    let currentChapter = deletedBook.appendingPathComponent("Chapter 01.m4b")
    let generation = BookControlPlaybackRequestPolicy.generationAfterDeactivation(2)

    #expect(BookControlPlaybackRequestPolicy.shouldApplyDeletionReset(
        currentAsset: currentChapter,
        deletedURLs: [deletedBook],
        currentGeneration: 2,
        requestGeneration: 2
    ))
    #expect(!BookControlPlaybackRequestPolicy.shouldApplyDeletionReset(
        currentAsset: currentChapter,
        deletedURLs: [deletedBook],
        currentGeneration: generation,
        requestGeneration: 2
    ))
}

@Test @MainActor func storageResetOnlyAppliesInActiveBookScene() {
    #expect(BookControlPlaybackRequestPolicy.shouldResetForStorageLocationChange(isSceneActive: true))
    #expect(!BookControlPlaybackRequestPolicy.shouldResetForStorageLocationChange(isSceneActive: false))
}

@Test @MainActor func staleBookStorageResetDoesNotApplyAfterDeactivation() {
    let generation = BookControlPlaybackRequestPolicy.generationAfterDeactivation(2)

    #expect(generation == 3)
    #expect(BookControlPlaybackRequestPolicy.shouldApplyStorageReset(
        currentGeneration: 2,
        requestGeneration: 2,
        isSceneActive: true
    ))
    #expect(!BookControlPlaybackRequestPolicy.shouldApplyStorageReset(
        currentGeneration: generation,
        requestGeneration: 2,
        isSceneActive: true
    ))
    #expect(!BookControlPlaybackRequestPolicy.shouldApplyStorageReset(
        currentGeneration: 2,
        requestGeneration: 2,
        isSceneActive: false
    ))
}

@Test @MainActor func bookRootUsesStandaloneBookAtDiskRoot() {
    let disk = URL(fileURLWithPath: "/tmp/cisum-books", isDirectory: true)
    let book = disk.appendingPathComponent("Standalone.m4b")

    let root = BookControlBookRootResolver.bookRoot(containing: book, bookDisk: disk)

    #expect(root == book.standardizedFileURL)
}

@Test @MainActor func bookRootUsesTopLevelFolderForChapterBooks() {
    let disk = URL(fileURLWithPath: "/tmp/cisum-books", isDirectory: true)
    let book = disk.appendingPathComponent("Novel", isDirectory: true)
    let chapter = book
        .appendingPathComponent("Part 1", isDirectory: true)
        .appendingPathComponent("Chapter 01.m4b")

    let root = BookControlBookRootResolver.bookRoot(containing: chapter, bookDisk: disk)

    #expect(root == book.standardizedFileURL)
}

@Test @MainActor func bookRootFallsBackToParentOutsideBookDisk() {
    let disk = URL(fileURLWithPath: "/tmp/cisum-books", isDirectory: true)
    let chapter = URL(fileURLWithPath: "/tmp/other-books/Novel/Chapter 01.m4b")

    let root = BookControlBookRootResolver.bookRoot(containing: chapter, bookDisk: disk)

    #expect(root == chapter.deletingLastPathComponent().standardizedFileURL)
}

@Test @MainActor func bookRootMapsSymlinkedBookDiskToConfiguredRoot() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realDisk = root.appendingPathComponent("real-books", isDirectory: true)
    let linkedDisk = root.appendingPathComponent("library-link", isDirectory: true)
    let book = realDisk.appendingPathComponent("Novel", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: book, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedDisk, withDestinationURL: realDisk)
    let chapter = book.appendingPathComponent("Chapter 01.m4b")
    try Data("audio".utf8).write(to: chapter)

    let resolved = BookControlBookRootResolver.bookRoot(containing: chapter, bookDisk: linkedDisk)

    #expect(resolved == linkedDisk.appendingPathComponent("Novel", isDirectory: true).standardizedFileURL)
}

@Test @MainActor func chapterLoaderReturnsPlayableChaptersInRelativeOrder() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let disc1 = root.appendingPathComponent("Disc 1", isDirectory: true)
    let disc2 = root.appendingPathComponent("Disc 2", isDirectory: true)
    try FileManager.default.createDirectory(at: disc1, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: disc2, withIntermediateDirectories: true)

    let unsupported = disc1.appendingPathComponent("notes.txt")
    let hidden = disc1.appendingPathComponent(".hidden.m4b")
    let chapter2 = disc1.appendingPathComponent("02.m4b")
    let chapter1 = disc2.appendingPathComponent("01.m4b")
    try Data("notes".utf8).write(to: unsupported)
    try Data("hidden".utf8).write(to: hidden)
    try Data("audio".utf8).write(to: chapter2)
    try Data("audio".utf8).write(to: chapter1)

    let chapters = BookControlChapterLoader.playableChapters(in: root)

    #expect(chapters.map { BookControlChapterLoader.relativePath($0, in: root) } == [
        "Disc 1/02.m4b",
        "Disc 2/01.m4b",
    ])
}

@MainActor
@Test func chapterCacheReusesLoadedChaptersForNavigation() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        BookControlChapterCache.removeAll()
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let first = root.appendingPathComponent("001.m4b")
    let second = root.appendingPathComponent("002.m4b")
    let third = root.appendingPathComponent("003.m4b")
    try Data("audio".utf8).write(to: first)
    try Data("audio".utf8).write(to: second)

    BookControlChapterCache.removeAll()
    BookControlChapterCache.store([first, second], in: root)
    try Data("audio".utf8).write(to: third)

    let next = await BookControlViewModel.adjacentAssetLoadingChapters(
        in: root,
        current: second,
        offset: 1,
        playMode: .sequence
    )

    #expect(next == nil)
}

@MainActor
@Test func chapterCacheMatchesSymlinkedBookRoots() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    defer {
        BookControlChapterCache.removeAll()
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    let chapter = realBook.appendingPathComponent("001.m4b")
    try Data("audio".utf8).write(to: chapter)

    BookControlChapterCache.removeAll()
    BookControlChapterCache.store([chapter], in: realBook)

    #expect(BookControlChapterCache.cachedChapters(in: linkedBook) == [chapter])
}

@Test @MainActor func chapterLoaderRejectsSiblingPrefixPaths() {
    let root = URL(fileURLWithPath: "/tmp/cisum-books/Book", isDirectory: true)
    let sibling = URL(fileURLWithPath: "/tmp/cisum-books/Book Backup/01.m4b")

    #expect(BookControlChapterLoader.relativePath(sibling, in: root) == "01.m4b")
}

// MARK: - ViewModel 集成

@MainActor
private final class BookControlPlaybackProbe: BookControlPlaybackCapability {
    var currentURL: URL?
    var isPlaying = false
    var playMode: MagicPlayMode = .sequence
    var toggleCount = 0
    var togglePlayModeCount = 0
    var resetCount = 0

    func toggle() { toggleCount += 1 }
    func togglePlayMode() { togglePlayModeCount += 1 }
    func play(_ url: URL, reason: String) async {}
    func reset(reason: String) async { resetCount += 1 }
}

@MainActor
private final class BookToastProbe: ToastProviding {
    var errors: [(title: String, message: String)] = []

    func show(_ toast: CisumToast) {}
    func presentError(title: String, message: String) { errors.append((title, message)) }
    func dismissError() {}
    func showLoading(title: String, detail: String?) {}
    func dismissLoading() {}
    func dismissAll() {}
}

@MainActor
struct BookControlViewModelTests {
    @Test
    func initReflectsPlaybackState() {
        let playback = BookControlPlaybackProbe()
        playback.isPlaying = true
        playback.playMode = .shuffle
        let viewModel = BookControlViewModel(
            targetScene: .audiobooks,
            playbackCapability: playback
        )
        viewModel.handleSceneChange(.audiobooks)
        #expect(viewModel.isPlaying)
        #expect(viewModel.playMode == .shuffle)
        #expect(viewModel.shouldActivateControl)
    }

    @Test
    func toggleWithoutCapabilityReportsUnavailable() {
        let toast = BookToastProbe()
        let viewModel = BookControlViewModel(
            targetScene: .audiobooks,
            playbackCapability: nil,
            toastProvider: toast
        )
        viewModel.toggle()
        #expect(!toast.errors.isEmpty)
    }

    @Test
    func previousWithoutCurrentChapterReportsUnavailable() {
        let toast = BookToastProbe()
        let viewModel = BookControlViewModel(
            targetScene: .audiobooks,
            playbackCapability: BookControlPlaybackProbe(),
            toastProvider: toast
        )
        viewModel.previous()
        #expect(!toast.errors.isEmpty)
    }

    @Test
    func storageLocationResetResetsPlaybackInActiveScene() async throws {
        let playback = BookControlPlaybackProbe()
        let viewModel = BookControlViewModel(
            targetScene: .audiobooks,
            playbackCapability: playback
        )
        viewModel.handleSceneChange(.audiobooks)
        viewModel.handleStorageLocationDidReset()

        for _ in 0..<50 where playback.resetCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(playback.resetCount == 1)
    }

    @Test
    func storageLocationResetIgnoredWhenSceneInactive() async throws {
        let playback = BookControlPlaybackProbe()
        let viewModel = BookControlViewModel(
            targetScene: .audiobooks,
            playbackCapability: playback
        )
        viewModel.handleSceneChange(.music)
        viewModel.handleStorageLocationDidReset()
        try await Task.sleep(for: .milliseconds(50))
        #expect(playback.resetCount == 0)
    }

    @Test
    func deletionOfCurrentChapterResetsPlayback() async throws {
        let playback = BookControlPlaybackProbe()
        playback.currentURL = URL(fileURLWithPath: "/tmp/book/chapter-01.mp3")
        let viewModel = BookControlViewModel(
            targetScene: .audiobooks,
            playbackCapability: playback
        )
        viewModel.handleSceneChange(.audiobooks)
        viewModel.handleBookDBDeleted(deletedURLs: [URL(fileURLWithPath: "/tmp/book/chapter-01.mp3")])

        for _ in 0..<50 where playback.resetCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(playback.resetCount == 1)
    }

    @Test
    func sceneChangeInvalidatesPendingDeletionReset() async throws {
        let playback = BookControlPlaybackProbe()
        playback.currentURL = URL(fileURLWithPath: "/tmp/book/chapter-01.mp3")
        let viewModel = BookControlViewModel(
            targetScene: .audiobooks,
            playbackCapability: playback
        )
        viewModel.handleSceneChange(.audiobooks)
        viewModel.handleBookDBDeleted(deletedURLs: [URL(fileURLWithPath: "/tmp/book/chapter-01.mp3")])
        viewModel.handleSceneChange(.music)

        try await Task.sleep(for: .milliseconds(50))
        #expect(playback.resetCount == 0)
    }
}