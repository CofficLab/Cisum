import Foundation
import ProviderBook
import ProviderBookData
import ProviderBook
import SwiftData
@testable import PluginBookProgress
import Testing

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(BookProgressPluginInfo.iconName == "book.closed")
    #expect(BookProgressPluginInfo.order == 5)
}

@Test func currentURLChangesDoNotOverwriteSavedPlaybackTime() {
    let url = URL(fileURLWithPath: "/tmp/book/chapter-01.mp3")

    let snapshot = BookProgressPersistencePolicy.currentURLChangeSnapshot(currentURL: url)

    #expect(snapshot == BookProgressStateSnapshot(currentURL: url, time: nil))
}

@Test func clearingCurrentURLClearsGlobalBookWithoutSavingChapterState() {
    let snapshot = BookProgressPersistencePolicy.currentURLChangeSnapshot(currentURL: nil)

    #expect(snapshot == nil)
}

@Test func playbackPositionSnapshotNormalizesInvalidTimes() {
    let url = URL(fileURLWithPath: "/tmp/book/chapter-01.mp3")

    #expect(BookProgressPersistencePolicy.snapshot(
        currentURL: url,
        currentTime: .nan,
        trigger: .playbackPositionChanged
    )?.time == 0)
    #expect(BookProgressPersistencePolicy.snapshot(
        currentURL: url,
        currentTime: .infinity,
        trigger: .playbackPositionChanged
    )?.time == 0)
    #expect(BookProgressPersistencePolicy.snapshot(
        currentURL: url,
        currentTime: -1,
        trigger: .playbackPositionChanged
    )?.time == 0)
    #expect(BookProgressPersistencePolicy.snapshot(
        currentURL: url,
        currentTime: 42,
        trigger: .playbackPositionChanged
    )?.time == 42)
}

@Test func differentCurrentBookURLResetsGlobalRestoreTime() {
    let oldURL = URL(fileURLWithPath: "/tmp/book/chapter-01.mp3")
    let newURL = URL(fileURLWithPath: "/tmp/book/chapter-02.mp3")

    #expect(BookProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(from: oldURL, to: newURL))
    #expect(BookProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(from: oldURL, to: nil))
    #expect(!BookProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(from: oldURL, to: oldURL))
}

@Test func symlinkedCurrentBookURLDoesNotResetGlobalRestoreTime() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    let realChapter = realBook.appendingPathComponent("chapter-01.m4b")
    let linkedChapter = linkedBook.appendingPathComponent("chapter-01.m4b")
    try Data("audio".utf8).write(to: realChapter)

    #expect(!BookProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(
        from: linkedChapter,
        to: realChapter
    ))
    #expect(!BookProgressPersistencePolicy.shouldPersistCurrentURLChange(
        from: linkedChapter,
        to: realChapter
    ))
}

@Test func distinctDanglingSymlinkedCurrentBookURLResetsGlobalRestoreTime() throws {
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

    let firstChapter = firstLink.appendingPathComponent("chapter-01.m4b")
    let secondChapter = secondLink.appendingPathComponent("chapter-01.m4b")

    #expect(BookProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(
        from: firstChapter,
        to: secondChapter
    ))
    #expect(BookProgressPersistencePolicy.shouldPersistCurrentURLChange(
        from: firstChapter,
        to: secondChapter
    ))
}

@Test func unchangedCurrentBookURLDoesNotPersistAgain() {
    let oldURL = URL(fileURLWithPath: "/tmp/book/chapter-01.mp3")
    let newURL = URL(fileURLWithPath: "/tmp/book/chapter-02.mp3")

    #expect(BookProgressPersistencePolicy.shouldPersistCurrentURLChange(from: oldURL, to: newURL))
    #expect(BookProgressPersistencePolicy.shouldPersistCurrentURLChange(from: oldURL, to: nil))
    #expect(!BookProgressPersistencePolicy.shouldPersistCurrentURLChange(from: oldURL, to: oldURL))
}

@Test func invalidRestoredBookURLShouldClearCurrentBook() {
    let url = URL(fileURLWithPath: "/tmp/book/missing.mp3")

    #expect(BookProgressPersistencePolicy.shouldClearRestoredCurrentURL(currentURL: url, isPlayable: false))
    #expect(!BookProgressPersistencePolicy.shouldClearRestoredCurrentURL(currentURL: url, isPlayable: true))
    #expect(!BookProgressPersistencePolicy.shouldClearRestoredCurrentURL(currentURL: nil, isPlayable: false))
    #expect(BookProgressPersistencePolicy.shouldClearRestoredCurrentTime(currentURL: url, isPlayable: false))
    #expect(!BookProgressPersistencePolicy.shouldClearRestoredCurrentTime(currentURL: url, isPlayable: true))
    #expect(!BookProgressPersistencePolicy.shouldClearRestoredCurrentTime(currentURL: nil, isPlayable: false))
}

@Test func deletedStoredCurrentBookChapterShouldClearRestoreState() {
    let book = URL(fileURLWithPath: "/tmp/books/Novel", isDirectory: true)
    let chapter = book.appendingPathComponent("Chapter 01.m4b")
    let otherBook = URL(fileURLWithPath: "/tmp/books/Other", isDirectory: true)

    #expect(BookProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: chapter,
        deletedURLs: [chapter]
    ))
    #expect(BookProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: chapter,
        deletedURLs: [book]
    ))
    #expect(!BookProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: chapter,
        deletedURLs: [otherBook]
    ))
    #expect(!BookProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: nil,
        deletedURLs: [book]
    ))
}

@Test func symlinkedDeletedStoredCurrentBookChapterShouldClearRestoreState() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    let realChapter = realBook.appendingPathComponent("Chapter 01.m4b")
    let linkedChapter = linkedBook.appendingPathComponent("Chapter 01.m4b")
    try Data("audio".utf8).write(to: realChapter)

    #expect(BookProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: linkedChapter,
        deletedURLs: [realBook]
    ))
}

@Test func danglingSymlinkedStoredCurrentBookChapterShouldClearRestoreState() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingBook = root.appendingPathComponent("MissingBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    let linkedChapter = linkedBook.appendingPathComponent("Chapter 01.m4b")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: missingBook)

    #expect(BookProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: linkedChapter,
        deletedURLs: [linkedBook]
    ))
}

@Test func distinctDanglingSymlinkedStoredCurrentBookChapterShouldNotClearRestoreState() throws {
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

    #expect(!BookProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: secondLink.appendingPathComponent("Chapter 01.m4b"),
        deletedURLs: [firstLink]
    ))
}

@Test func playbackPositionChangesPersistCurrentTime() {
    let url = URL(fileURLWithPath: "/tmp/book/chapter-01.mp3")

    let snapshot = BookProgressPersistencePolicy.snapshot(
        currentURL: url,
        currentTime: 42,
        trigger: .playbackPositionChanged
    )

    #expect(snapshot == BookProgressStateSnapshot(currentURL: url, time: 42))
}

@Test func playbackPositionDoesNotPersistForAudioOutsideBookDisk() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bookDisk = root.appendingPathComponent("books", isDirectory: true)
    let outside = root.appendingPathComponent("audio", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: bookDisk, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    let book = bookDisk.appendingPathComponent("Novel", isDirectory: true)
    try FileManager.default.createDirectory(at: book, withIntermediateDirectories: true)
    let chapter = book.appendingPathComponent("Chapter 01.m4b")
    let outsideAudio = outside.appendingPathComponent("Track.m4b")
    try Data("book".utf8).write(to: chapter)
    try Data("audio".utf8).write(to: outsideAudio)

    #expect(BookProgressPersistencePolicy.shouldPersistPlaybackProgress(
        currentURL: chapter,
        bookDisk: bookDisk
    ))
    #expect(!BookProgressPersistencePolicy.shouldPersistPlaybackProgress(
        currentURL: outsideAudio,
        bookDisk: bookDisk
    ))
    #expect(!BookProgressPersistencePolicy.shouldPersistPlaybackProgress(
        currentURL: nil,
        bookDisk: bookDisk
    ))
}

@Test func restoreResultOnlyAppliesWhenCurrentBookDidNotChange() {
    let starting = URL(fileURLWithPath: "/tmp/book/chapter-01.m4b")
    let switched = URL(fileURLWithPath: "/tmp/book/chapter-02.m4b")

    #expect(BookProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: nil,
        currentAsset: nil
    ))
    #expect(BookProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: starting,
        currentAsset: starting
    ))
    #expect(!BookProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: nil,
        currentAsset: switched
    ))
    #expect(!BookProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: starting,
        currentAsset: switched
    ))
}

@Test func staleRestoreRequestDoesNotApplyAfterSceneChange() {
    #expect(BookProgressPersistencePolicy.shouldApplyRestoreRequest(
        currentGeneration: 4,
        requestGeneration: 4,
        isSceneActive: true
    ))
    #expect(!BookProgressPersistencePolicy.shouldApplyRestoreRequest(
        currentGeneration: 5,
        requestGeneration: 4,
        isSceneActive: true
    ))
    #expect(!BookProgressPersistencePolicy.shouldApplyRestoreRequest(
        currentGeneration: 4,
        requestGeneration: 4,
        isSceneActive: false
    ))
}

@Test func restoreDoesNotReplayAlreadyLoadedBookChapter() {
    let restored = URL(fileURLWithPath: "/tmp/book/chapter-01.m4b")
    let other = URL(fileURLWithPath: "/tmp/book/chapter-02.m4b")

    #expect(!BookProgressPersistencePolicy.shouldPlayRestoredAsset(
        restoredAsset: restored,
        currentAsset: restored
    ))
    #expect(BookProgressPersistencePolicy.shouldPlayRestoredAsset(
        restoredAsset: restored,
        currentAsset: other
    ))
    #expect(BookProgressPersistencePolicy.shouldPlayRestoredAsset(
        restoredAsset: restored,
        currentAsset: nil
    ))
}

@Test func restoreTreatsSymlinkedCurrentChapterAsAlreadyLoaded() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    let realChapter = realBook.appendingPathComponent("chapter-01.m4b")
    let linkedChapter = linkedBook.appendingPathComponent("chapter-01.m4b")
    try Data("audio".utf8).write(to: realChapter)

    #expect(BookProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: linkedChapter,
        currentAsset: realChapter
    ))
    #expect(!BookProgressPersistencePolicy.shouldPlayRestoredAsset(
        restoredAsset: linkedChapter,
        currentAsset: realChapter
    ))
    #expect(BookProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: linkedChapter,
        currentAsset: realChapter
    ))
}

@Test func restoreDoesNotTreatDistinctDanglingSymlinkedChapterAsAlreadyLoaded() throws {
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

    let firstChapter = firstLink.appendingPathComponent("chapter-01.m4b")
    let secondChapter = secondLink.appendingPathComponent("chapter-01.m4b")

    #expect(!BookProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: firstChapter,
        currentAsset: secondChapter
    ))
    #expect(BookProgressPersistencePolicy.shouldPlayRestoredAsset(
        restoredAsset: firstChapter,
        currentAsset: secondChapter
    ))
    #expect(!BookProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: firstChapter,
        currentAsset: secondChapter
    ))
}

@Test func staleCurrentURLChangeDoesNotOverwriteNewBookChapter() {
    let requested = URL(fileURLWithPath: "/tmp/book/chapter-01.m4b")
    let switched = URL(fileURLWithPath: "/tmp/book/chapter-02.m4b")

    #expect(BookProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: requested
    ))
    #expect(!BookProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: switched
    ))
    #expect(!BookProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: nil
    ))
}

@Test func staleCurrentURLChangeDoesNotApplyAfterBookSceneInvalidation() {
    let requested = URL(fileURLWithPath: "/tmp/book/chapter-01.m4b")

    #expect(BookProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: requested,
        currentGeneration: 1,
        requestGeneration: 1,
        isSceneActive: true
    ))
    #expect(!BookProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: requested,
        currentGeneration: 2,
        requestGeneration: 1,
        isSceneActive: true
    ))
    #expect(!BookProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: requested,
        currentGeneration: 1,
        requestGeneration: 1,
        isSceneActive: false
    ))
}

@Test func rootLevelBookFileResolvesToItself() {
    let disk = URL(fileURLWithPath: "/tmp/cisum-books", isDirectory: true)
    let book = disk.appendingPathComponent("Standalone.m4b")

    let root = BookProgressBookRootResolver.bookRoot(containing: book, bookDisk: disk)

    #expect(root == book.standardizedFileURL)
}

@Test func nestedBookChapterResolvesToTopLevelBookFolder() {
    let disk = URL(fileURLWithPath: "/tmp/cisum-books", isDirectory: true)
    let book = disk.appendingPathComponent("Novel", isDirectory: true)
    let chapter = book
        .appendingPathComponent("Disc 1", isDirectory: true)
        .appendingPathComponent("Chapter 01.mp3")

    let root = BookProgressBookRootResolver.bookRoot(containing: chapter, bookDisk: disk)

    #expect(root == book.standardizedFileURL)
}

@Test func outsideBookDiskFallsBackToParentFolder() {
    let disk = URL(fileURLWithPath: "/tmp/cisum-books", isDirectory: true)
    let chapter = URL(fileURLWithPath: "/tmp/other-books/Novel/Chapter 01.mp3")

    let root = BookProgressBookRootResolver.bookRoot(containing: chapter, bookDisk: disk)

    #expect(root == chapter.deletingLastPathComponent().standardizedFileURL)
}

@Test func rootBookDiskContainsNestedPlaybackURL() {
    let disk = URL(fileURLWithPath: "/", isDirectory: true)
    let chapter = URL(fileURLWithPath: "/tmp/cisum-root-books/Novel/Chapter 01.m4b")

    #expect(BookProgressPathContainment.resolved(chapter, isContainedIn: disk))
    #expect(BookProgressPathContainment.relativePath(of: chapter.path, in: disk.path) == "tmp/cisum-root-books/Novel/Chapter 01.m4b")
}

@Test func symlinkedBookDiskResolvesRealPlaybackURLToConfiguredRoot() throws {
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

    let resolved = BookProgressBookLookup.bookURL(for: chapter, bookDisk: linkedDisk)

    #expect(resolved == linkedDisk.appendingPathComponent("Novel", isDirectory: true).standardizedFileURL)
}

@Test func bookLookupFindsStandaloneBookFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let book = root.appendingPathComponent("Standalone.m4b")
    try Data("audio".utf8).write(to: book)

    #expect(BookProgressBookLookup.bookURL(for: book, bookDisk: root) == book.standardizedFileURL)
}

@Test func bookLookupRejectsUnsupportedStandaloneFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let notes = root.appendingPathComponent("notes.txt")
    try Data("notes".utf8).write(to: notes)

    #expect(BookProgressBookLookup.bookURL(for: notes, bookDisk: root) == nil)
}

@Test func bookLookupRejectsFilesOutsideConfiguredBookDisk() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bookDisk = root.appendingPathComponent("books", isDirectory: true)
    let outside = root.appendingPathComponent("outside", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: bookDisk, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    let chapter = outside.appendingPathComponent("Chapter 01.m4b")
    try Data("audio".utf8).write(to: chapter)

    #expect(BookProgressBookLookup.bookURL(for: chapter, bookDisk: bookDisk) == nil)
}

@Test func bookProgressRejectsCurrentAudioOutsideConfiguredBookDisk() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bookDisk = root.appendingPathComponent("books", isDirectory: true)
    let outside = root.appendingPathComponent("outside", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: bookDisk, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)

    let book = bookDisk.appendingPathComponent("Novel", isDirectory: true)
    try FileManager.default.createDirectory(at: book, withIntermediateDirectories: true)
    let chapter = book.appendingPathComponent("Chapter 01.m4b")
    try Data("book".utf8).write(to: chapter)

    let outsideAudio = outside.appendingPathComponent("Track.m4b")
    try Data("audio".utf8).write(to: outsideAudio)

    #expect(BookProgressPersistencePolicy.shouldAcceptBookURL(chapter, bookDisk: bookDisk))
    #expect(!BookProgressPersistencePolicy.shouldAcceptBookURL(outsideAudio, bookDisk: bookDisk))
}

@Test func bookLookupRejectsSymlinkEscapesOutsideConfiguredBookDisk() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bookDisk = root.appendingPathComponent("books", isDirectory: true)
    let outside = root.appendingPathComponent("outside", isDirectory: true)
    let outsideBook = outside.appendingPathComponent("Novel", isDirectory: true)
    let linkedBook = bookDisk.appendingPathComponent("LinkedNovel", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: bookDisk, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outsideBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: outsideBook)
    let chapter = linkedBook.appendingPathComponent("Chapter 01.m4b")
    try Data("audio".utf8).write(to: outsideBook.appendingPathComponent("Chapter 01.m4b"))

    #expect(BookProgressBookLookup.bookURL(for: chapter, bookDisk: bookDisk) == nil)
}

@Test func bookLookupFindsFolderBooksForNestedChapters() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let book = root.appendingPathComponent("Novel", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: book, withIntermediateDirectories: true)
    let chapter = book.appendingPathComponent("Chapter 01.m4b")
    try Data("audio".utf8).write(to: chapter)

    #expect(BookProgressBookLookup.bookURL(for: chapter, bookDisk: root) == book.standardizedFileURL)
}

@MainActor
@Test func bookProgressStatePersistenceUpdatesOnMainActor() throws {
    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)

    let book = URL(fileURLWithPath: "/tmp/cisum-book-progress/Novel", isDirectory: true)
    let firstChapter = book.appendingPathComponent("Chapter 01.m4b")
    let secondChapter = book.appendingPathComponent("Chapter 02.m4b")

    try BookProgressStatePersistence.save(
        bookURL: book,
        currentURL: firstChapter,
        time: nil,
        container: container
    )
    var states = try context.fetch(BookState.descriptorOf(book))
    #expect(states.count == 1)
    #expect(states.first?.currentURL == firstChapter)
    #expect(states.first?.time == 0)

    try BookProgressStatePersistence.save(
        bookURL: book,
        currentURL: secondChapter,
        time: 42,
        container: container
    )
    states = try context.fetch(BookState.descriptorOf(book))
    #expect(states.count == 1)
    #expect(states.first?.currentURL == secondChapter)
    #expect(states.first?.time == 42)
}

@MainActor
@Test func bookProgressStatePersistenceUpdatesSymlinkedBookState() throws {
    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-books", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("library-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)
    let realBook = realRoot.appendingPathComponent("Novel", isDirectory: true)
    let linkedBook = linkedRoot.appendingPathComponent("Novel", isDirectory: true)
    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    let realChapter = realBook.appendingPathComponent("Chapter 01.m4b")
    let linkedChapter = linkedBook.appendingPathComponent("Chapter 01.m4b")
    try Data("audio".utf8).write(to: realChapter)

    try BookProgressStatePersistence.save(
        bookURL: realBook,
        currentURL: realChapter,
        time: 12,
        container: container
    )
    try BookProgressStatePersistence.save(
        bookURL: linkedBook,
        currentURL: linkedChapter,
        time: 42,
        container: container
    )

    let states = try context.fetch(BookState.descriptorAll)
    #expect(states.count == 1)
    #expect(states.first?.url == realBook)
    #expect(states.first?.currentURL == linkedChapter)
    #expect(states.first?.time == 42)
}
