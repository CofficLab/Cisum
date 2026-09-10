@testable import PluginBook
import ProviderBook
import ProviderBookData
import Foundation
import Testing
@testable import ProviderBookData
import SwiftData
import SwiftUI

@Test func bookPluginInfoExportsMetadata() {
    #expect(BookPluginInfo.dirName == "audios_book")
    #expect(BookPluginInfo.iconName == "book")
    #expect(BookPluginInfo.supportedExtensions.contains("m4b"))
}

@Test func bookPluginSupportsPlayerRecognizedAudiobookExtensions() {
    let playerAudioExtensions = ["mp3", "m4a", "m4b", "aac", "wav", "aiff", "ogg", "opus", "flac", "alac"]

    for extensionName in playerAudioExtensions {
        #expect(BookPluginInfo.supportedExtensions.contains(extensionName))
    }
}

@Test func bookDBDownloadProgressPercentTextUsesFractionInput() {
    #expect(BookDB.downloadProgressPercentText(forFraction: .nan) == "0")
    #expect(BookDB.downloadProgressPercentText(forFraction: -0.25) == "0")
    #expect(BookDB.downloadProgressPercentText(forFraction: 0) == "0")
    #expect(BookDB.downloadProgressPercentText(forFraction: 0.5) == "50")
    #expect(BookDB.downloadProgressPercentText(forFraction: 1) == "100")
    #expect(BookDB.downloadProgressPercentText(forFraction: 1.4) == "100")
}

@MainActor
@Test func bookDiskCreationReplacesDanglingSymlink() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bookDisk = root.appendingPathComponent(BookPlugin.dirName, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
        at: bookDisk,
        withDestinationURL: root.appendingPathComponent("missing-books", isDirectory: true)
    )

    BookPluginHost.configure(
        dbRoot: { root.appendingPathComponent("db", isDirectory: true) },
        storageRoot: { root },
        storageLocationDidChangeNotifications: []
    )

    let preparedDisk = try #require(
        try BookPluginHost.getStorageRoot()?.appendingPathComponent(BookPlugin.dirName, isDirectory: true).ensureDirectory()
    )
    var isDirectory: ObjCBool = false

    #expect(preparedDisk == bookDisk)
    #expect(FileManager.default.fileExists(atPath: bookDisk.path, isDirectory: &isDirectory))
    #expect(isDirectory.boolValue)
    #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: bookDisk.path)) == nil)
}

@MainActor
@Test func bookDBDeletedNotificationPostsSynchronouslyOnMainThread() {
    let deletedURL = URL(fileURLWithPath: "/tmp/cisum-book-event-tests/deleted.m4b")
    let receivedURLs = TestNotificationValue<[URL]>([])
    let token = NotificationCenter.default.addObserver(
        forName: .bookDBDeleted,
        object: nil,
        queue: nil
    ) { notification in
        let urls = notification.userInfo?["urls"] as? [URL] ?? []
        guard urls == [deletedURL] else { return }
        receivedURLs.set(urls)
    }
    defer { NotificationCenter.default.removeObserver(token) }

    NotificationCenter.postBookDBDeleted(urls: [deletedURL])

    #expect(receivedURLs.value == [deletedURL])
}

@Test func symlinkedBookFolderIsSupportedLibraryItem() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    try Data("audio".utf8).write(to: realBook.appendingPathComponent("001.m4b"))

    #expect(BookDB.isSupportedBookLibraryItem(linkedBook))
    #expect(BookModel.playableChildCount(for: linkedBook) == 1)
}

@Test func bookLibraryItemSupportCountsPlayableChildrenWithoutImages() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let book = root.appendingPathComponent("Book", isDirectory: true)
    let nested = book.appendingPathComponent("Nested", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("cover".utf8).write(to: book.appendingPathComponent("cover.jpg"))
    try Data("notes".utf8).write(to: nested.appendingPathComponent("notes.txt"))
    try Data("audio".utf8).write(to: nested.appendingPathComponent("001.m4b"))
    try Data("audio".utf8).write(to: nested.appendingPathComponent("002.mp3"))

    #expect(BookDB.isSupportedBookLibraryItem(book))
    #expect(BookModel.playableChildCount(for: book) == 2)
}

@Test func bookLibraryItemSupportRejectsFoldersWithoutPlayableChildren() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let book = root.appendingPathComponent("Book", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: book, withIntermediateDirectories: true)
    try Data("cover".utf8).write(to: book.appendingPathComponent("cover.jpg"))
    try Data("notes".utf8).write(to: book.appendingPathComponent("notes.txt"))

    #expect(!BookDB.isSupportedBookLibraryItem(book))
    #expect(BookModel.playableChildCount(for: book) == 0)
}

@Test func bookDBUniqueSupportedItemsDeduplicatesByResolvedIdentity() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    let otherBook = root.appendingPathComponent("OtherBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: otherBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    try Data("audio".utf8).write(to: realBook.appendingPathComponent("001.m4b"))
    try Data("audio".utf8).write(to: otherBook.appendingPathComponent("001.m4b"))

    #expect(BookPathContainment.canonicalIdentity(for: linkedBook) == BookPathContainment.canonicalIdentity(for: realBook))
    #expect(BookDB.uniqueSupportedBookLibraryItems([linkedBook, realBook, otherBook]) == [linkedBook, otherBook])
}

@Test func bookDBUniqueSupportedItemsKeepsDistinctDanglingSymlinkBooks() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingBook = root.appendingPathComponent("missing.m4b")
    let firstLink = root.appendingPathComponent("first.m4b")
    let secondLink = root.appendingPathComponent("second.m4b")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingBook)
    try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingBook)

    #expect(BookDB.isSupportedBookLibraryItem(firstLink))
    #expect(BookDB.isSupportedBookLibraryItem(secondLink))
    #expect(BookPathContainment.canonicalIdentity(for: firstLink) != BookPathContainment.canonicalIdentity(for: secondLink))
    #expect(BookDB.uniqueSupportedBookLibraryItems([firstLink, secondLink]) == [firstLink, secondLink])
}

@Test func bookPathContainmentKeepsDistinctChaptersUnderDanglingSymlinkBooks() throws {
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

    let firstChapter = firstLink.appendingPathComponent("Chapter 01.m4b")
    let secondChapter = secondLink.appendingPathComponent("Chapter 01.m4b")

    #expect(BookPathContainment.canonicalIdentity(for: firstChapter) != BookPathContainment.canonicalIdentity(for: secondChapter))
    #expect(!BookPathContainment.representsSameFile(firstChapter, secondChapter))
}

@Test func bookModelTreatsSymlinkedBookFolderAsCollection() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    try Data("audio".utf8).write(to: realBook.appendingPathComponent("001.m4b"))

    let book = BookModel(url: linkedBook)

    #expect(book.isCollection)
    #expect(book.childCount == 1)
}

@Test func bookCoverCandidatesIncludeStandaloneBookFile() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let standaloneBook = root.appendingPathComponent("Standalone.m4b")
    try Data("audio".utf8).write(to: standaloneBook)

    let candidates = BookCoverRepo.coverCandidates(in: standaloneBook)

    #expect(candidates.files.map(canonicalPath) == [canonicalPath(standaloneBook)])
    #expect(candidates.folders.isEmpty)
}

@Test func bookCoverCandidatesScanDirectFilesBeforeNestedFolders() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let nested = root.appendingPathComponent("Nested", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    let directAudio = root.appendingPathComponent("Chapter 01.m4b")
    let directCover = root.appendingPathComponent("cover.jpg")
    let nestedAudio = nested.appendingPathComponent("Chapter 02.m4b")
    try Data("audio".utf8).write(to: directAudio)
    try Data("cover".utf8).write(to: directCover)
    try Data("audio".utf8).write(to: nestedAudio)

    let candidates = BookCoverRepo.coverCandidates(in: root)

    #expect(candidates.files.map(canonicalPath) == [canonicalPath(directCover)])
    #expect(candidates.folders.map(canonicalPath) == [canonicalPath(nested)])
}

@Test func bookCoverCandidatesIgnoreAudioChaptersInFolders() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let firstChapter = root.appendingPathComponent("001.m4b")
    let secondChapter = root.appendingPathComponent("002.mp3")
    try Data("audio".utf8).write(to: firstChapter)
    try Data("audio".utf8).write(to: secondChapter)

    let candidates = BookCoverRepo.coverCandidates(in: root)

    #expect(candidates.files.isEmpty)
}

@Test func bookCoverCandidatesPreferNamedCoverImages() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let artwork = root.appendingPathComponent("artwork.png")
    let folder = root.appendingPathComponent("folder.png")
    let cover = root.appendingPathComponent("cover.jpg")
    try Data("image".utf8).write(to: artwork)
    try Data("image".utf8).write(to: folder)
    try Data("image".utf8).write(to: cover)

    let candidates = BookCoverRepo.coverCandidates(in: root)

    #expect(candidates.files.map(canonicalPath) == [
        canonicalPath(cover),
        canonicalPath(folder),
        canonicalPath(artwork),
    ])
}

@Test func bookCoverCacheDeduplicatesConcurrentLoadsAndCachesMissingCovers() async {
    let cache = BookCoverCache()
    let probe = CoverLoaderProbe()

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 {
            group.addTask {
                _ = await cache.value(for: "same-book_100x100") {
                    await probe.load()
                }
            }
        }
    }

    #expect(await probe.callCount == 1)

    _ = await cache.value(for: "same-book_100x100") {
        await probe.load()
    }
    #expect(await probe.callCount == 1)
}

@Test func clearingBookCoverCachePreventsInFlightResultFromBeingRestored() async {
    let cache = BookCoverCache()
    let probe = CoverLoaderProbe()
    let firstRequest = Task {
        await cache.value(for: "book_100x100") {
            await probe.load()
        }
    }

    while await probe.callCount == 0 {
        await Task.yield()
    }

    cache.clear()
    _ = await firstRequest.value
    _ = await cache.value(for: "book_100x100") {
        await probe.load()
    }

    #expect(await probe.callCount == 2)
}

private func canonicalPath(_ url: URL) -> String {
    url.resolvingSymlinksInPath().standardizedFileURL.path
}

private actor CoverLoaderProbe {
    private(set) var callCount = 0

    func load() async -> Image? {
        callCount += 1
        try? await Task.sleep(for: .milliseconds(20))
        return nil
    }
}

@Test func emptyCloudBookURLIsIgnored() {
    #expect(BookSettingRepo.storedURL(from: "") == nil)
    #expect(BookSettingRepo.storedURL(from: nil) == nil)
    #expect(BookSettingRepo.storedURL(from: "file:///tmp/book/chapter.m4b") == URL(fileURLWithPath: "/tmp/book/chapter.m4b"))
    #expect(BookSettingRepo.storedURL(from: "  file:///tmp/book/spaced.m4b\n") == URL(fileURLWithPath: "/tmp/book/spaced.m4b"))
    #expect(BookSettingRepo.storedURL(from: "/tmp/book/legacy-chapter.m4b") == URL(fileURLWithPath: "/tmp/book/legacy-chapter.m4b"))
    #expect(BookSettingRepo.storedURL(from: "\t/tmp/book/legacy-spaced.m4b ") == URL(fileURLWithPath: "/tmp/book/legacy-spaced.m4b"))
    #expect(BookSettingRepo.storedURL(from: "not a url") == nil)
}

@Test func localZeroBookTimeOverridesStaleCloudTime() {
    #expect(BookSettingRepo.storedTime(
        localObject: 0.0,
        localDouble: 0,
        cloudString: "42"
    ) == 0)
    #expect(BookSettingRepo.storedTime(
        localObject: nil,
        localDouble: 0,
        cloudString: "42"
    ) == 42)
    #expect(BookSettingRepo.storedTime(
        localObject: nil,
        localDouble: 0,
        cloudString: "not a time"
    ) == nil)
}

@Test func invalidLocalBookTimesFallBackToCloud() {
    #expect(BookSettingRepo.storedTime(
        localObject: Double.nan,
        localDouble: .nan,
        cloudString: "42"
    ) == 42)
    #expect(BookSettingRepo.storedTime(
        localObject: Double.infinity,
        localDouble: .infinity,
        cloudString: "42"
    ) == 42)
    #expect(BookSettingRepo.storedTime(
        localObject: -1.0,
        localDouble: -1,
        cloudString: "42"
    ) == 42)
    #expect(BookSettingRepo.storedTime(
        localObject: nil,
        localDouble: 0,
        cloudString: "inf"
    ) == nil)
    #expect(BookSettingRepo.storedTime(
        localObject: nil,
        localDouble: 0,
        cloudString: "-1"
    ) == nil)
}

@Test func bookTimesAreNormalizedBeforeStorage() {
    #expect(BookSettingRepo.normalizedTimeForStorage(.nan) == 0)
    #expect(BookSettingRepo.normalizedTimeForStorage(.infinity) == 0)
    #expect(BookSettingRepo.normalizedTimeForStorage(-1) == 0)
    #expect(BookSettingRepo.normalizedTimeForStorage(0) == 0)
    #expect(BookSettingRepo.normalizedTimeForStorage(42) == 42)
}

@Test func deletedBookFolderContainsNestedRecords() {
    let root = URL(fileURLWithPath: "/tmp/cisum-book-delete-tests", isDirectory: true)
    let book = root.appendingPathComponent("Book", isDirectory: true)
    let nestedChapter = book
        .appendingPathComponent("Disc 1", isDirectory: true)
        .appendingPathComponent("Chapter 1.m4b")
    let siblingBook = root
        .appendingPathComponent("Book Extras", isDirectory: true)
        .appendingPathComponent("Chapter 1.m4b")

    #expect(BookDB.contains(book, bookURL: book))
    #expect(BookDB.contains(book, bookURL: nestedChapter))
    #expect(!BookDB.contains(book, bookURL: siblingBook))
}

@Test func deletedBookFolderContainsSavedState() {
    let root = URL(fileURLWithPath: "/tmp/cisum-book-state-delete-tests", isDirectory: true)
    let book = root.appendingPathComponent("Book", isDirectory: true)
    let nestedChapter = book
        .appendingPathComponent("Disc 1", isDirectory: true)
        .appendingPathComponent("Chapter 1.m4b")
    let state = BookState(url: book, currentURL: nestedChapter, time: 42)
    let siblingState = BookState(
        url: root.appendingPathComponent("Book Extras", isDirectory: true),
        currentURL: root
            .appendingPathComponent("Book Extras", isDirectory: true)
            .appendingPathComponent("Chapter 1.m4b"),
        time: 42
    )

    #expect(BookDB.contains(book, state: state))
    #expect(!BookDB.contains(book, state: siblingState))
}

@Test func bookStateDoesNotMatchDistinctDanglingSymlinkedCurrentChapter() throws {
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

    #expect(!BookState.representsSameBookURL(
        firstLink.appendingPathComponent("Chapter 01.m4b"),
        as: secondLink.appendingPathComponent("Chapter 01.m4b")
    ))
}

@Test func deletedSymlinkedBookFolderContainsRealPathRecords() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-books", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("library-link", isDirectory: true)
    let book = realRoot.appendingPathComponent("Book", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: book, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)
    let nestedChapter = book.appendingPathComponent("Chapter 1.m4b")
    try Data("audio".utf8).write(to: nestedChapter)

    #expect(BookDB.contains(linkedRoot, bookURL: nestedChapter))
}

@Test func deletedDanglingSymlinkBookFolderContainsLexicalChildRecords() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let library = root.appendingPathComponent("books", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
    let linkedBook = library.appendingPathComponent("Broken Book", isDirectory: true)
    try FileManager.default.createSymbolicLink(
        at: linkedBook,
        withDestinationURL: root.appendingPathComponent("missing-book", isDirectory: true)
    )
    let savedChapter = linkedBook.appendingPathComponent("Chapter 1.m4b")

    #expect(BookDB.contains(linkedBook, bookURL: savedChapter))
}

@Test func deletedRootBookFolderContainsNestedRecords() {
    let root = URL(fileURLWithPath: "/", isDirectory: true)
    let nestedChapter = URL(fileURLWithPath: "/tmp/cisum-root-book/Chapter 1.m4b")

    #expect(BookDB.contains(root, bookURL: nestedChapter))
}

@Test func displayableLibraryItemsIncludeTopLevelStandaloneBooks() {
    let root = URL(fileURLWithPath: "/tmp/cisum-books", isDirectory: true)
    let book = BookDTO(
        url: root.appendingPathComponent("Standalone.m4b"),
        bookTitle: "Standalone",
        childCount: 1,
        isCollection: false,
        order: 0
    )

    #expect(BookRepo.isDisplayableLibraryItem(book, libraryRoot: root))
}

@Test func displayableLibraryItemsIncludeRealBooksUnderSymlinkedLibraryRoot() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-books", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("library-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)
    let bookURL = realRoot.appendingPathComponent("Standalone.m4b")
    try Data("audio".utf8).write(to: bookURL)
    let book = BookDTO(
        url: bookURL,
        bookTitle: "Standalone",
        childCount: 1,
        isCollection: false,
        order: 0
    )

    #expect(BookRepo.isDisplayableLibraryItem(book, libraryRoot: linkedRoot))
}

@Test func displayableLibraryItemsExcludeNestedChapters() {
    let root = URL(fileURLWithPath: "/tmp/cisum-books", isDirectory: true)
    let chapter = BookDTO(
        url: root
            .appendingPathComponent("Novel", isDirectory: true)
            .appendingPathComponent("Chapter 01.m4b"),
        bookTitle: "Chapter 01",
        childCount: 1,
        isCollection: false,
        order: 0
    )

    #expect(!BookRepo.isDisplayableLibraryItem(chapter, libraryRoot: root))
}

@Test func displayableLibraryItemsExcludeEmptyTopLevelFolders() {
    let root = URL(fileURLWithPath: "/tmp/cisum-books", isDirectory: true)
    let emptyFolder = BookDTO(
        url: root.appendingPathComponent("Empty", isDirectory: true),
        bookTitle: "Empty",
        childCount: 0,
        isCollection: true,
        order: 0
    )

    #expect(!BookRepo.isDisplayableLibraryItem(emptyFolder, libraryRoot: root))
}

@MainActor
@Test func bookRepoWaitsForInitialDiskSyncBeforeReturningBooks() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let bookURL = root.appendingPathComponent("book.m4b")
    try Data("audio".utf8).write(to: bookURL)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let repo = try BookRepo(
        disk: root,
        db: BookDB(container, reason: "bookRepoWaitsForInitialDiskSyncBeforeReturningBooks")
    )

    let books = await repo.getAll(reason: "bookRepoWaitsForInitialDiskSyncBeforeReturningBooks")

    #expect(books.count == 1)
    #expect(BookPathContainment.representsSameFile(books[0].url, bookURL))
}

@Test func bookDBFullSyncInsertsBooksInStablePathOrder() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBFullSyncInsertsBooksInStablePathOrder")

    let second = root.appendingPathComponent("02-second.m4b")
    let first = root.appendingPathComponent("01-first.m4b")
    for file in [second, first] {
        try Data("audio".utf8).write(to: file)
    }

    await db.sync([second, first], isFirst: true)

    let orderedURLs = try await db.allBookDTOs()
        .sorted { $0.order < $1.order }
        .map(\.url)
    #expect(orderedURLs == [first, second])
}

@Test func bookDBUpdateSyncAppendsNewBooksInStablePathOrder() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBUpdateSyncAppendsNewBooksInStablePathOrder")

    let existing = root.appendingPathComponent("00-existing.m4b")
    let second = root.appendingPathComponent("02-second.m4b")
    let first = root.appendingPathComponent("01-first.m4b")
    for file in [existing, second, first] {
        try Data("audio".utf8).write(to: file)
    }

    try await db.syncImportedItems([existing])
    try await db.syncImportedItems([second, first])

    let orderedURLs = try await db.allBookDTOs()
        .sorted { $0.order < $1.order }
        .map(\.url)
    #expect(orderedURLs == [existing, first, second])
}

@Test func bookDBUpdateSyncMatchesExistingBookThroughSymlink() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-books", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("library-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBUpdateSyncMatchesExistingBookThroughSymlink")

    let realBook = realRoot.appendingPathComponent("Novel.m4b")
    let linkedBook = linkedRoot.appendingPathComponent("Novel.m4b")
    try Data("audio".utf8).write(to: realBook)

    try await db.insertModel(BookModel(url: realBook, order: 10))
    try await db.syncImportedItems([linkedBook])

    let books = try await db.allBookDTOs()
    #expect(books.count == 1)
    #expect(books.first?.url == realBook)
    #expect(books.first?.order == 10)
}

@Test func bookDBFullSyncKeepsSymlinkedExistingBookState() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-books", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("library-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBFullSyncKeepsSymlinkedExistingBookState")

    let realBook = realRoot.appendingPathComponent("Novel.m4b")
    let linkedBook = linkedRoot.appendingPathComponent("Novel.m4b")
    try Data("audio".utf8).write(to: realBook)

    try await db.insertModel(BookModel(url: realBook, order: 10))
    await db.updateBookCurrent(realBook, currentURL: realBook, time: 42)
    await db.sync([linkedBook], isFirst: true)

    let books = try await db.allBookDTOs()
    #expect(books.count == 1)
    #expect(books.first?.url == realBook)
    #expect(books.first?.order == 10)
    #expect(await db.getBookTime(realBook) == 42)
}

@Test func bookDBFullSyncDeduplicatesSymlinkedScanItems() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-books", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("library-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBFullSyncDeduplicatesSymlinkedScanItems")

    let realBook = realRoot.appendingPathComponent("Novel.m4b")
    let linkedBook = linkedRoot.appendingPathComponent("Novel.m4b")
    try Data("audio".utf8).write(to: realBook)

    await db.sync([linkedBook, realBook], isFirst: true)

    let books = try await db.allBookDTOs()
    #expect(books.map(\.url) == [linkedBook])
}

@Test func bookDBFindsBookStateThroughSymlink() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-books", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("library-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBFindsBookStateThroughSymlink")

    let realBook = realRoot.appendingPathComponent("Novel", isDirectory: true)
    let linkedBook = linkedRoot.appendingPathComponent("Novel", isDirectory: true)
    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: realBook.appendingPathComponent("Chapter 01.m4b"))

    await db.updateBookCurrent(realBook, currentURL: realBook.appendingPathComponent("Chapter 01.m4b"), time: 42)

    #expect(await db.getBookTime(linkedBook) == 42)
}

@Test func bookDBSyncKeepsSymlinkedBookFolderDisplayable() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-books", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("library-link", isDirectory: true)
    let realBook = realRoot.appendingPathComponent("Novel", isDirectory: true)
    let linkedBook = linkedRoot.appendingPathComponent("Novel", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)
    try Data("audio".utf8).write(to: realBook.appendingPathComponent("Chapter 01.m4b"))

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBSyncKeepsSymlinkedBookFolderDisplayable")

    await db.sync([linkedBook], isFirst: true)

    let book = try #require(await db.allBookDTOs().first)
    #expect(book.isCollection)
    #expect(book.childCount == 1)
    #expect(BookRepo.isDisplayableLibraryItem(book, libraryRoot: linkedRoot))
}

@Test func bookDBFullSyncIgnoresUnsupportedFiles() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBFullSyncIgnoresUnsupportedFiles")

    let book = root.appendingPathComponent("Novel.m4b")
    let notes = root.appendingPathComponent("notes.txt")
    try Data("audio".utf8).write(to: book)
    try Data("notes".utf8).write(to: notes)

    await db.sync([notes, book], isFirst: true)

    let books = try await db.allBookDTOs()
    #expect(books.map(\.url) == [book])
}

@Test func bookDBUpdateSyncIgnoresUnsupportedFilesAndFolders() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBUpdateSyncIgnoresUnsupportedFilesAndFolders")

    let book = root.appendingPathComponent("Novel.m4b")
    let notes = root.appendingPathComponent("notes.txt")
    let emptyFolder = root.appendingPathComponent("Empty", isDirectory: true)
    try Data("audio".utf8).write(to: book)
    try Data("notes".utf8).write(to: notes)
    try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)

    try await db.syncImportedItems([notes, emptyFolder, book])

    let books = try await db.allBookDTOs()
    #expect(books.map(\.url) == [book])
}

@Test func bookDBNextBookUsesCurrentBookOrder() async throws {
    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBNextBookUsesCurrentBookOrder")

    let root = URL(fileURLWithPath: "/tmp/cisum-book-next-tests", isDirectory: true)
    let first = root.appendingPathComponent("first.m4b")
    let second = root.appendingPathComponent("second.m4b")
    let third = root.appendingPathComponent("third.m4b")

    try await db.insertModel(BookModel(url: first, order: 10))
    try await db.insertModel(BookModel(url: second, order: 20))
    try await db.insertModel(BookModel(url: third, order: 30))

    #expect(db.getNextBookOf(second)?.url == third)
}

@Test func bookDBNextBookSkipsSymlinkedDuplicateBook() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-books", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("library-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBNextBookSkipsSymlinkedDuplicateBook")

    let realBook = realRoot.appendingPathComponent("Novel.m4b")
    let linkedBook = linkedRoot.appendingPathComponent("Novel.m4b")
    let nextBook = realRoot.appendingPathComponent("Next.m4b")
    for file in [realBook, nextBook] {
        try Data("audio".utf8).write(to: file)
    }

    try await db.insertModel(BookModel(url: realBook, order: 10))
    try await db.insertModel(BookModel(url: linkedBook, order: 20))
    try await db.insertModel(BookModel(url: nextBook, order: 30))

    #expect(db.getNextBookOf(realBook)?.url == nextBook)
}

@Test func bookDBDeleteReturnsNilWhenOnlyNextBookIsSymlinkedDuplicate() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-books", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("library-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBDeleteReturnsNilWhenOnlyNextBookIsSymlinkedDuplicate")

    let realBook = realRoot.appendingPathComponent("Novel.m4b")
    let linkedBook = linkedRoot.appendingPathComponent("Novel.m4b")
    try Data("audio".utf8).write(to: realBook)

    #expect(try await db.deleteReturnsNilWhenOnlyNextIsSymlinkedDuplicate(realBook: realBook, linkedBook: linkedBook))
}

@Test func bookDBBatchDeleteSkipsBooksDeletedLaterInSameBatch() async throws {
    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBBatchDeleteSkipsBooksDeletedLaterInSameBatch")

    let root = URL(fileURLWithPath: "/tmp/cisum-book-batch-delete", isDirectory: true)
    let first = root.appendingPathComponent("first.m4b")
    let second = root.appendingPathComponent("second.m4b")
    let third = root.appendingPathComponent("third.m4b")
    let fourth = root.appendingPathComponent("fourth.m4b")

    let next = try await db.deleteNextURLAfterBatchDeleting(
        first: first,
        second: second,
        third: third,
        fourth: fourth
    )

    #expect(next == fourth)
}

@Test func bookDBDeleteByIDPostsDeletedURLs() async throws {
    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBDeleteByIDPostsDeletedURLs")
    let bookURL = URL(fileURLWithPath: "/tmp/cisum-book-delete-notification/Novel.m4b")
    let receivedURLs = TestNotificationValue<[URL]>([])
    let token = NotificationCenter.default.addObserver(
        forName: .bookDBDeleted,
        object: nil,
        queue: nil
    ) { notification in
        let urls = notification.userInfo?["urls"] as? [URL] ?? []
        guard urls == [bookURL] else { return }
        receivedURLs.set(urls)
    }
    defer { NotificationCenter.default.removeObserver(token) }

    try await db.insertAndDeleteBookForTesting(bookURL)

    for _ in 0..<10 where receivedURLs.value != [bookURL] {
        try await Task.sleep(nanoseconds: 10_000_000)
    }

    #expect(receivedURLs.value == [bookURL])
}

@Test func bookDBFindOrCreateReturnsInsertedBook() async throws {
    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBFindOrCreateReturnsInsertedBook")

    let bookURL = URL(fileURLWithPath: "/tmp/cisum-book-find-or-create/Novel.m4b")
    #expect(await db.findOrCreateReturnsInsertedBook(bookURL))
}

@Test func bookDBFullSyncRepairsDuplicateLegacyBookOrders() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = BookDB(container, reason: "bookDBFullSyncRepairsDuplicateLegacyBookOrders")

    let second = root.appendingPathComponent("02-second.m4b")
    let first = root.appendingPathComponent("01-first.m4b")
    for file in [second, first] {
        try Data("audio".utf8).write(to: file)
        try await db.insertModel(BookModel(url: file, order: 0))
    }

    await db.sync([second, first], isFirst: true)

    let books = try await db.allBookDTOs()
        .sorted { $0.order < $1.order }
    #expect(books.map(\.url) == [first, second])
    #expect(Set(books.map(\.order)).count == 2)
}

@Test func bookDBKeepsUniqueExistingBookOrders() {
    #expect(!BookDB.needsStableOrderRepair([20, 10, 30]))
    #expect(BookDB.needsStableOrderRepair([0, 0]))
}

extension BookDB {
    func insertAndDeleteBookForTesting(_ url: URL) throws {
        let book = BookModel(url: url, order: 10)
        try insertModel(book)
        _ = delete(ids: [book.id], verbose: false)
    }

    func findOrCreateReturnsInsertedBook(_ url: URL) -> Bool {
        guard let created = findOrCreateBook(url), let fetched = findBook(url: url) else {
            return false
        }

        return created === fetched
    }

    func deleteReturnsNilWhenOnlyNextIsSymlinkedDuplicate(realBook: URL, linkedBook: URL) throws -> Bool {
        let book = BookModel(url: realBook, order: 10)
        try insertModel(book)
        try insertModel(BookModel(url: linkedBook, order: 20))

        return delete(ids: [book.id], verbose: false) == nil
    }

    func deleteNextURLAfterBatchDeleting(
        first: URL,
        second: URL,
        third: URL,
        fourth: URL
    ) throws -> URL? {
        try insertModel(BookModel(url: first, order: 10))
        let secondBook = BookModel(url: second, order: 20)
        let thirdBook = BookModel(url: third, order: 30)
        try insertModel(secondBook)
        try insertModel(thirdBook)
        try insertModel(BookModel(url: fourth, order: 40))

        return delete(ids: [thirdBook.id, secondBook.id], verbose: false)?.url
    }
}

private final class TestNotificationValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    init(_ value: Value) {
        self.storedValue = value
    }

    var value: Value {
        lock.withLock { storedValue }
    }

    func set(_ value: Value) {
        lock.withLock {
            storedValue = value
        }
    }
}
