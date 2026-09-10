import Testing
@testable import PluginBookDB
import Foundation
import ProviderBook
import ProviderBookData
import ProviderBook
import SwiftData
import UniformTypeIdentifiers

@Test func bookDBInfoExportsMetadata() {
    #expect(BookDBPluginInfo.iconName == "books.vertical")
}

@Test func bookTilePlaceholderColorIsStableAndTitleDependent() {
    let title = "百年孤独"

    #expect(BookTileColorPolicy.hue(for: title) == BookTileColorPolicy.hue(for: title))
    #expect(BookTileColorPolicy.hue(for: title) != BookTileColorPolicy.hue(for: "三体"))
    #expect(BookTileColorPolicy.hue(for: title) >= 0)
    #expect(BookTileColorPolicy.hue(for: title) < 1)
}

@Test func folderImportRequiresPlayableFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let unsupportedFolder = root.appendingPathComponent("unsupported", isDirectory: true)
    let supportedFolder = root.appendingPathComponent("supported", isDirectory: true)
    let nestedFolder = supportedFolder.appendingPathComponent("disc-1", isDirectory: true)

    try FileManager.default.createDirectory(at: unsupportedFolder, withIntermediateDirectories: true)
    try Data("notes".utf8).write(to: unsupportedFolder.appendingPathComponent("notes.txt"))
    try Data("hidden audio".utf8).write(to: unsupportedFolder.appendingPathComponent(".hidden.m4b"))

    try FileManager.default.createDirectory(at: nestedFolder, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: nestedFolder.appendingPathComponent("chapter.m4b"))

    #expect(BookDBView.folderContainsPlayableFiles(unsupportedFolder) == false)
    #expect(BookDBView.folderContainsPlayableFiles(supportedFolder) == true)
}

@Test func bookImportFiltersUnsupportedTopLevelFilesBeforeImport() throws {
    let root = URL(fileURLWithPath: "/tmp/cisum-book-import-filter-tests", isDirectory: true)
    let supported = root.appendingPathComponent("chapter.M4B")
    let unsupported = root.appendingPathComponent("notes.txt")
    let folder = root.appendingPathComponent("audiobook", isDirectory: true)

    #expect(BookDBView.importableSourceCandidates([supported, unsupported, folder]) == [
        supported,
        folder,
    ])
    #expect(BookDBView.importableSourceCandidates([unsupported]).isEmpty)
}

@Test func bookImportReportsSkippedUnsupportedSources() {
    let root = URL(fileURLWithPath: "/tmp/cisum-book-import-filter-tests", isDirectory: true)
    let supported = root.appendingPathComponent("chapter.M4B")
    let unsupported = root.appendingPathComponent("notes.txt")
    let folder = root.appendingPathComponent("audiobook", isDirectory: true)

    #expect(BookDBView.shouldReportSkippedImportSources(
        [supported, unsupported, folder],
        importSources: [supported, folder]
    ))
    #expect(!BookDBView.shouldReportSkippedImportSources([supported, folder], importSources: [supported, folder]))
    #expect(!BookDBView.shouldReportSkippedImportSources([unsupported], importSources: []))
}

@Test func folderImportAcceptsSymlinkedBookFolders() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    try Data("audio".utf8).write(to: realBook.appendingPathComponent("001.m4b"))

    #expect(BookDBView.isFolderLikeImportSource(linkedBook))
    #expect(BookDBView.folderContainsPlayableFiles(linkedBook))

    let copiedItems = try await BookDBView.copyImportedItems([linkedBook], to: destinationRoot)
    let copiedBook = destinationRoot.appendingPathComponent("LinkedBook", isDirectory: true)

    #expect(copiedItems == [copiedBook])
    #expect(FileManager.default.fileExists(atPath: copiedBook.appendingPathComponent("001.m4b").path))
}

@Test func folderImportAvoidsDanglingSymlinkDestinationNames() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceBook = root.appendingPathComponent("Novel", isDirectory: true)
    let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
    let danglingDestination = destinationRoot.appendingPathComponent("Novel", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceBook, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: sourceBook.appendingPathComponent("001.m4b"))
    try FileManager.default.createSymbolicLink(
        at: danglingDestination,
        withDestinationURL: destinationRoot.appendingPathComponent("missing", isDirectory: true)
    )

    let copiedItems = try await BookDBView.copyImportedItems([sourceBook], to: destinationRoot)
    let copiedBook = destinationRoot.appendingPathComponent("Novel 2", isDirectory: true)

    #expect(copiedItems == [copiedBook])
    #expect(FileManager.default.fileExists(atPath: copiedBook.appendingPathComponent("001.m4b").path))
    #expect((try? danglingDestination.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true)
}

@Test func bookImportCopiesSymlinkedAudioFilesAsStandaloneFiles() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    let realSource = sourceRoot.appendingPathComponent("real.m4b")
    let linkedSource = sourceRoot.appendingPathComponent("linked.m4b")
    try Data("audio".utf8).write(to: realSource)
    try FileManager.default.createSymbolicLink(at: linkedSource, withDestinationURL: realSource)

    let copiedItems = try await BookDBView.copyImportedItems([linkedSource], to: destinationRoot)
    let collection = destinationRoot.appendingPathComponent("linked", isDirectory: true)
    let copiedFile = collection.appendingPathComponent("linked.m4b")
    let fileType = try FileManager.default.attributesOfItem(atPath: copiedFile.path)[.type] as? FileAttributeType

    #expect(copiedItems == [collection])
    #expect(fileType == .typeRegular)
    #expect((try Data(contentsOf: copiedFile)) == Data("audio".utf8))
}

@Test func bookImportDeduplicatesSymlinkedAudioSources() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    let realSource = sourceRoot.appendingPathComponent("real.m4b")
    let linkedSource = sourceRoot.appendingPathComponent("linked.m4b")
    try Data("audio".utf8).write(to: realSource)
    try FileManager.default.createSymbolicLink(at: linkedSource, withDestinationURL: realSource)

    #expect(BookDBView.representsSameImportSource(realSource, linkedSource))
    #expect(BookDBView.canonicalImportSourceIdentity(for: realSource) == BookDBView.canonicalImportSourceIdentity(for: linkedSource))
    #expect(BookDBView.uniqueImportSources([linkedSource, realSource]) == [linkedSource])

    let copiedItems = try await BookDBView.copyImportedItems([linkedSource, realSource], to: destinationRoot)
    let collection = destinationRoot.appendingPathComponent("linked", isDirectory: true)

    #expect(copiedItems == [collection])
    #expect(FileManager.default.fileExists(atPath: collection.appendingPathComponent("linked.m4b").path))
    #expect(!FileManager.default.fileExists(atPath: collection.appendingPathComponent("real.m4b").path))
}

@Test func bookImportSkipsFilesAlreadyCoveredBySelectedFolder() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceBook = root.appendingPathComponent("Book", isDirectory: true)
    let nestedChapter = sourceBook.appendingPathComponent("chapter.m4b")
    let outsideChapter = root.appendingPathComponent("bonus.m4b")
    let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceBook, withIntermediateDirectories: true)
    try Data("chapter".utf8).write(to: nestedChapter)
    try Data("bonus".utf8).write(to: outsideChapter)

    #expect(BookDBView.uniqueImportSources([
        nestedChapter,
        sourceBook,
        outsideChapter,
    ]) == [
        sourceBook,
        outsideChapter,
    ])

    let copiedItems = try await BookDBView.copyImportedItems([
        nestedChapter,
        sourceBook,
        outsideChapter,
    ], to: destinationRoot)

    #expect(copiedItems == [
        destinationRoot.appendingPathComponent("Book", isDirectory: true),
        destinationRoot.appendingPathComponent("bonus", isDirectory: true),
    ])
    #expect(FileManager.default.fileExists(atPath: destinationRoot.appendingPathComponent("Book/chapter.m4b").path))
    #expect(FileManager.default.fileExists(atPath: destinationRoot.appendingPathComponent("bonus/bonus.m4b").path))
    #expect(!FileManager.default.fileExists(atPath: destinationRoot.appendingPathComponent("chapter", isDirectory: true).path))
}

@Test func folderImportDeduplicatesSymlinkedBookFolders() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    try Data("audio".utf8).write(to: realBook.appendingPathComponent("001.m4b"))

    #expect(BookDBView.canonicalImportSourceIdentity(for: realBook) == BookDBView.canonicalImportSourceIdentity(for: linkedBook))
    let copiedItems = try await BookDBView.copyImportedItems([linkedBook, realBook], to: destinationRoot)

    #expect(copiedItems == [destinationRoot.appendingPathComponent("LinkedBook", isDirectory: true)])
    #expect(!FileManager.default.fileExists(atPath: destinationRoot.appendingPathComponent("RealBook", isDirectory: true).path))
}

@Test func bookImportAvoidsDanglingSymlinkCollectionNames() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
    let danglingCollection = destinationRoot.appendingPathComponent("chapter", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
    let source = sourceRoot.appendingPathComponent("chapter.m4b")
    try Data("audio".utf8).write(to: source)
    try FileManager.default.createSymbolicLink(
        at: danglingCollection,
        withDestinationURL: destinationRoot.appendingPathComponent("missing", isDirectory: true)
    )

    let copiedItems = try await BookDBView.copyImportedItems([source], to: destinationRoot)
    let collection = destinationRoot.appendingPathComponent("chapter 2", isDirectory: true)
    let copiedFile = collection.appendingPathComponent("chapter.m4b")

    #expect(copiedItems == [collection])
    #expect((try Data(contentsOf: copiedFile)) == Data("audio".utf8))
    #expect((try? danglingCollection.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true)
}

@Test func bookImportCleansCopiedItemsWhenBatchFails() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    let validSource = sourceRoot.appendingPathComponent("chapter-1.m4b")
    let missingSource = sourceRoot.appendingPathComponent("chapter-2.m4b")
    try Data("audio".utf8).write(to: validSource)

    await #expect(throws: Error.self) {
        try await BookDBView.copyImportedItems([validSource, missingSource], to: destinationRoot)
    }

    #expect(FileManager.default.fileExists(atPath: destinationRoot.appendingPathComponent("source").path) == false)
}

@Test func bookImportRejectsDestinationInsideSourceFolderBeforeCopying() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let destinationRoot = sourceRoot.appendingPathComponent("library", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    let chapter = sourceRoot.appendingPathComponent("chapter-1.m4b")
    try Data("audio".utf8).write(to: chapter)

    #expect(BookDBView.isDestinationNestedInSource(
        source: sourceRoot,
        destination: destinationRoot.appendingPathComponent("source", isDirectory: true)
    ))

    await #expect(throws: Error.self) {
        try await BookDBView.copyImportedItems([sourceRoot], to: destinationRoot)
    }

    #expect(FileManager.default.fileExists(atPath: chapter.path))
    #expect(!FileManager.default.fileExists(atPath: destinationRoot.appendingPathComponent("source").path))
}

@Test func bookImportTreatsRootSourceAsContainingDestination() {
    let source = URL(fileURLWithPath: "/", isDirectory: true)
    let destination = URL(fileURLWithPath: "/tmp/cisum-book-import/source", isDirectory: true)

    #expect(BookDBView.isDestinationNestedInSource(source: source, destination: destination))
    #expect(!BookDBView.isDestinationNestedInSource(source: source, destination: source))
}

@Test func bookImportRejectsSymlinkedDestinationInsideSourceFolder() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let realLibrary = sourceRoot.appendingPathComponent("library", isDirectory: true)
    let linkedLibrary = root.appendingPathComponent("linked-library", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realLibrary, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedLibrary, withDestinationURL: realLibrary)
    let chapter = sourceRoot.appendingPathComponent("chapter-1.m4b")
    try Data("audio".utf8).write(to: chapter)

    let destination = linkedLibrary.appendingPathComponent("source", isDirectory: true)
    #expect(BookDBView.isDestinationNestedInSource(source: sourceRoot, destination: destination))

    await #expect(throws: Error.self) {
        try await BookDBView.copyImportedItems([sourceRoot], to: linkedLibrary)
    }

    #expect(FileManager.default.fileExists(atPath: chapter.path))
    #expect(!FileManager.default.fileExists(atPath: destination.path))
}

@Test func bookDropReadsFileURLDataProvider() async throws {
    let expected = URL(fileURLWithPath: "/tmp/cisum-book-drop-provider-tests/audiobook")
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
        completion(expected.dataRepresentation, nil)
        return nil
    }

    let url = try await BookDBView.droppedFileURL(from: provider)

    #expect(url == expected)
}

@Test func bookDropFallsBackToURLObjectAfterInvalidFileURLData() async throws {
    let expected = URL(fileURLWithPath: "/tmp/cisum-book-drop-provider-tests/audiobook")
    let provider = NSItemProvider(object: expected as NSURL)
    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
        completion(Data("not a file url".utf8), nil)
        return nil
    }

    let url = try await BookDBView.droppedFileURL(from: provider)

    #expect(url == expected)
}

@Test func bookDropFallsBackToURLObjectAfterFileURLDataError() async throws {
    let expected = URL(fileURLWithPath: "/tmp/cisum-book-drop-provider-tests/audiobook")
    let provider = NSItemProvider(object: expected as NSURL)
    let error = NSError(domain: "BookDrop", code: 1)
    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
        completion(nil, error)
        return nil
    }

    let url = try await BookDBView.droppedFileURL(from: provider)

    #expect(url == expected)
}

@Test func bookDropSkipsEmptyImportAfterProviderFailure() {
    let error = NSError(domain: "BookDrop", code: 1)
    let url = URL(fileURLWithPath: "/tmp/cisum-book-drop-provider-tests/audiobook")

    #expect(BookDBView.shouldImportDroppedURLs([], after: [error]) == false)
    #expect(BookDBView.shouldImportDroppedURLs([url], after: [error]) == true)
    #expect(BookDBView.shouldImportDroppedURLs([], after: []) == false)
    #expect(BookDBView.shouldReportDroppedURLLoadFailure([], errors: [error]))
    #expect(!BookDBView.shouldReportDroppedURLLoadFailure([url], errors: [error]))
    #expect(!BookDBView.shouldReportDroppedURLLoadFailure([], errors: []))
    #expect(BookDBView.shouldReportPartialDroppedURLLoadFailure([url], errors: [error]))
    #expect(!BookDBView.shouldReportPartialDroppedURLLoadFailure([], errors: [error]))
    #expect(!BookDBView.shouldReportPartialDroppedURLLoadFailure([url], errors: []))
}

@Test func bookImportDoesNotStartWhileAlreadyImporting() {
    #expect(BookDBView.shouldStartImport(isImporting: false))
    #expect(!BookDBView.shouldStartImport(isImporting: true))
}

@Test func bookImportAllowsReadableLocalItemsWithoutSecurityScope() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let readableFolder = root.appendingPathComponent("book", isDirectory: true)
    let missingFolder = root.appendingPathComponent("missing", isDirectory: true)
    try FileManager.default.createDirectory(at: readableFolder, withIntermediateDirectories: true)

    #expect(BookDBView.hasImportSourceAccess(readableFolder, securityScopeGranted: false))
    #expect(BookDBView.hasImportSourceAccess(missingFolder, securityScopeGranted: true))
    #expect(!BookDBView.hasImportSourceAccess(missingFolder, securityScopeGranted: false))
}

@Test func bookPlaybackOrderingUsesRelativePaths() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let disc1 = root.appendingPathComponent("Disc 1", isDirectory: true)
    let disc2 = root.appendingPathComponent("Disc 2", isDirectory: true)
    try FileManager.default.createDirectory(at: disc1, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: disc2, withIntermediateDirectories: true)

    let disc1Chapter2 = disc1.appendingPathComponent("02.m4b")
    let disc2Chapter1 = disc2.appendingPathComponent("01.m4b")
    try Data("audio".utf8).write(to: disc1Chapter2)
    try Data("audio".utf8).write(to: disc2Chapter1)
    try Data("hidden audio".utf8).write(to: disc1.appendingPathComponent(".hidden.m4b"))
    try Data("notes".utf8).write(to: disc2.appendingPathComponent("notes.txt"))

    let playable = BookPlaybackOrdering.playableChildren(for: root)

    #expect(playable.map { BookPlaybackOrdering.relativePath($0, in: root) } == [
        "Disc 1/02.m4b",
        "Disc 2/01.m4b",
    ])
    #expect(BookPlaybackOrdering.relativePath(disc1Chapter2, in: root) == "Disc 1/02.m4b")
}

@Test func bookPlaybackOrderingRejectsSiblingPrefixPaths() {
    let root = URL(fileURLWithPath: "/tmp/cisum-books/Book", isDirectory: true)
    let sibling = URL(fileURLWithPath: "/tmp/cisum-books/Book Backup/01.m4b")

    #expect(BookPlaybackOrdering.relativePath(sibling, in: root) == "01.m4b")
}

@Test func bookPlaybackOrderingChecksPlayableChildContainmentWithoutScanning() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let book = root.appendingPathComponent("Book", isDirectory: true)
    let siblingBook = root.appendingPathComponent("Book Backup", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: book, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: siblingBook, withIntermediateDirectories: true)
    let chapter = book.appendingPathComponent("001.m4b")
    let unsupported = book.appendingPathComponent("notes.txt")
    let siblingChapter = siblingBook.appendingPathComponent("001.m4b")
    try Data("audio".utf8).write(to: chapter)
    try Data("notes".utf8).write(to: unsupported)
    try Data("audio".utf8).write(to: siblingChapter)

    #expect(BookPlaybackOrdering.containsPlayableChild(chapter, in: book))
    #expect(!BookPlaybackOrdering.containsPlayableChild(unsupported, in: book))
    #expect(!BookPlaybackOrdering.containsPlayableChild(siblingChapter, in: book))
}

@Test func bookPlaybackOrderingMatchesSymlinkedPlayableChildren() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    let savedChapter = realBook.appendingPathComponent("001.m4b")
    try Data("audio".utf8).write(to: savedChapter)

    let playable = BookPlaybackOrdering.playableChildren(for: linkedBook)

    #expect(BookPlaybackOrdering.contains(savedChapter, in: playable))
    #expect(BookPlaybackOrdering.containsPlayableChild(savedChapter, in: linkedBook))
    #expect(BookPlaybackOrdering.containsPlayableChild(
        linkedBook.appendingPathComponent("001.m4b"),
        in: linkedBook
    ))
    #expect(BookPlaybackOrdering.representsSameFile(
        savedChapter,
        linkedBook.appendingPathComponent("001.m4b")
    ))
}

@Test func bookGridLoadsPlayableChildrenAsynchronously() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let book = root.appendingPathComponent("Book", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: book, withIntermediateDirectories: true)
    let first = book.appendingPathComponent("01.m4b")
    let second = book.appendingPathComponent("02.m4b")
    try Data("audio".utf8).write(to: second)
    try Data("audio".utf8).write(to: first)

    let playable = await BookGridPlayableChildrenLoader.load(for: book)

    #expect(playable.map(\.standardizedFileURL.path) == [first, second].map(\.standardizedFileURL.path))
}

@Test func bookPlaybackOrderingSeparatesDistinctDanglingSymlinkedChapters() throws {
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

    #expect(!BookPlaybackOrdering.representsSameFile(firstChapter, secondChapter))
    #expect(!BookPlaybackOrdering.contains(secondChapter, in: [firstChapter]))
}

@Test func bookTileReloadsWhenDatabaseRootChanges() {
    let bookURL = URL(fileURLWithPath: "/tmp/cisum-book-tile/book")
    let firstRoot = URL(fileURLWithPath: "/tmp/cisum-book-tile/db-1")
    let secondRoot = URL(fileURLWithPath: "/tmp/cisum-book-tile/db-2")

    #expect(BookTileLoadIdentity(
        bookURL: bookURL,
        dbRoot: firstRoot,
        stateRevision: 0
    ) == BookTileLoadIdentity(
        bookURL: bookURL,
        dbRoot: firstRoot,
        stateRevision: 0
    ))
    #expect(BookTileLoadIdentity(
        bookURL: bookURL,
        dbRoot: firstRoot,
        stateRevision: 0
    ) != BookTileLoadIdentity(
        bookURL: bookURL,
        dbRoot: secondRoot,
        stateRevision: 0
    ))
}

@Test func bookTileReloadsWhenMatchingBookStateChanges() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("RealBook", isDirectory: true)
    let linkedBook = root.appendingPathComponent("LinkedBook", isDirectory: true)
    let otherBook = root.appendingPathComponent("OtherBook", isDirectory: true)
    let dbRoot = root.appendingPathComponent("db", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: otherBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)
    try Data("audio".utf8).write(to: realBook.appendingPathComponent("001.m4b"))

    #expect(BookTileStateRefreshPolicy.shouldReloadTile(bookURL: linkedBook, updatedBookURL: realBook))
    #expect(!BookTileStateRefreshPolicy.shouldReloadTile(bookURL: linkedBook, updatedBookURL: otherBook))
    #expect(!BookTileStateRefreshPolicy.shouldReloadTile(bookURL: linkedBook, updatedBookURL: nil))

    let nextRevision = BookTileStateRefreshPolicy.nextRevision(after: 0)
    #expect(nextRevision == 1)
    #expect(BookTileLoadIdentity(
        bookURL: linkedBook,
        dbRoot: dbRoot,
        stateRevision: nextRevision
    ) != BookTileLoadIdentity(
        bookURL: linkedBook,
        dbRoot: dbRoot,
        stateRevision: 0
    ))
}

@Test func bookDBViewFindsSymlinkedBookState() throws {
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
    try Data("audio".utf8).write(to: realChapter)

    let schema = Schema([BookModel.self, BookState.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)
    context.insert(BookState(url: realBook, currentURL: realChapter, time: 42))
    try context.save()

    let state = try #require(try BookDBViewBookStateLookup.findBookState(for: linkedBook, in: context))
    #expect(state.currentURL == realChapter)
    #expect(state.time == 42)
}

@Test func bookGridOnlyAppliesCurrentUpdateGeneration() {
    #expect(BookGridUpdatePolicy.shouldApplyResult(currentGeneration: 2, resultGeneration: 2))
    #expect(!BookGridUpdatePolicy.shouldApplyResult(currentGeneration: 3, resultGeneration: 2))
}

@Test func bookGridSchedulingRefreshInvalidatesPendingUpdateResults() {
    let nextGeneration = BookGridUpdatePolicy.nextGeneration(after: 2)

    #expect(nextGeneration == 3)
    #expect(!BookGridUpdatePolicy.shouldApplyResult(
        currentGeneration: nextGeneration,
        resultGeneration: 2
    ))
}

@Test func bookGridOnlyAppliesCurrentPlaybackRequestGeneration() {
    let book = URL(fileURLWithPath: "/tmp/cisum-book-grid/Book", isDirectory: true)
    let other = URL(fileURLWithPath: "/tmp/cisum-book-grid/Other", isDirectory: true)
    let displayedBook = BookDTO(
        url: book,
        bookTitle: "Book",
        childCount: 1,
        isCollection: true,
        order: 0
    )

    #expect(BookGridPlaybackRequestPolicy.shouldApplyResult(
        currentGeneration: 2,
        resultGeneration: 2,
        requestedBookURL: book,
        selectedBookURL: book,
        displayedBooks: [displayedBook]
    ))
    #expect(!BookGridPlaybackRequestPolicy.shouldApplyResult(
        currentGeneration: 3,
        resultGeneration: 2,
        requestedBookURL: book,
        selectedBookURL: book,
        displayedBooks: [displayedBook]
    ))
    #expect(!BookGridPlaybackRequestPolicy.shouldApplyResult(
        currentGeneration: 2,
        resultGeneration: 2,
        requestedBookURL: book,
        selectedBookURL: other,
        displayedBooks: [displayedBook]
    ))
    #expect(!BookGridPlaybackRequestPolicy.shouldApplyResult(
        currentGeneration: 2,
        resultGeneration: 2,
        requestedBookURL: book,
        selectedBookURL: nil,
        displayedBooks: [displayedBook]
    ))
    #expect(!BookGridPlaybackRequestPolicy.shouldApplyResult(
        currentGeneration: 2,
        resultGeneration: 2,
        requestedBookURL: book,
        selectedBookURL: book,
        displayedBooks: []
    ))
}

@Test func bookGridInvalidatesPendingPlaybackWhenDisappearing() {
    let book = URL(fileURLWithPath: "/tmp/cisum-book-grid/Book", isDirectory: true)
    let generation = BookGridPlaybackRequestPolicy.generationAfterInvalidatingPendingPlayback(2)

    #expect(generation == 3)
    #expect(!BookGridPlaybackRequestPolicy.shouldApplyResult(
        currentGeneration: generation,
        resultGeneration: 2,
        requestedBookURL: book,
        selectedBookURL: book,
        displayedBooks: [
            BookDTO(
                url: book,
                bookTitle: "Book",
                childCount: 1,
                isCollection: true,
                order: 0
            ),
        ]
    ))
}

@Test func bookGridOnlyReportsNoPlayableChaptersForCurrentSelection() {
    let book = URL(fileURLWithPath: "/tmp/cisum-book-grid/Book", isDirectory: true)
    let other = URL(fileURLWithPath: "/tmp/cisum-book-grid/Other", isDirectory: true)
    let displayedBook = BookDTO(
        url: book,
        bookTitle: "Book",
        childCount: 0,
        isCollection: true,
        order: 0
    )

    #expect(BookGridPlaybackRequestPolicy.shouldReportNoPlayableChapters(
        currentGeneration: 2,
        resultGeneration: 2,
        requestedBookURL: book,
        selectedBookURL: book,
        displayedBooks: [displayedBook]
    ))
    #expect(!BookGridPlaybackRequestPolicy.shouldReportNoPlayableChapters(
        currentGeneration: 3,
        resultGeneration: 2,
        requestedBookURL: book,
        selectedBookURL: book,
        displayedBooks: [displayedBook]
    ))
    #expect(!BookGridPlaybackRequestPolicy.shouldReportNoPlayableChapters(
        currentGeneration: 2,
        resultGeneration: 2,
        requestedBookURL: book,
        selectedBookURL: other,
        displayedBooks: [displayedBook]
    ))
}

@Test func bookGridSelectionMatchesSymlinkedBookURLs() throws {
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

    let book = BookDTO(
        url: linkedBook,
        bookTitle: "LinkedBook",
        childCount: 1,
        isCollection: true,
        order: 0
    )

    #expect(BookGridSelectionPolicy.representsSelectedBook(linkedBook, selectedURL: realBook))
    #expect(BookGridSelectionPolicy.containsSelectedBook(realBook, in: [book]))
    #expect(!BookGridSelectionPolicy.containsSelectedBook(
        root.appendingPathComponent("OtherBook", isDirectory: true),
        in: [book]
    ))
}

@Test func bookGridSelectionUsesReadableAccessibilityLabel() {
    #expect(BookGridSelectionPolicy.selectionLabel(bookTitle: "Novel") == "Select Novel")
}

@MainActor
@Test func bookDBPluginProvidesSettingsNavigationItem() {
    let item = BookDBPlugin.shared.addSettingNavigationItem()

    #expect(item != nil)
    #expect(item?.id == "bookdb")
    #expect(item?.title == BookDBPluginInfo.titleKey)
    #expect(item?.description == BookDBPlugin.metadata.description)
    #expect(item?.iconName == BookDBPluginInfo.iconName)
    #expect(item?.order == BookDBPlugin.metadata.order)
}

// MARK: - Book tree builder

@Test func bookTreeBuilderBuildsNestedDirectoryStructure() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let bookA = root.appendingPathComponent("Book A", isDirectory: true)
    let bookB = root.appendingPathComponent("Book B", isDirectory: true)
    let disc1 = bookB.appendingPathComponent("Disc 1", isDirectory: true)
    try FileManager.default.createDirectory(at: bookA, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: disc1, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: bookA.appendingPathComponent("01.m4b"))
    try Data("audio".utf8).write(to: disc1.appendingPathComponent("track.mp3"))
    try Data("audio".utf8).write(to: root.appendingPathComponent("bonus.m4b"))

    let children = BookTreeBuilder.buildRootChildren(from: root)

    // 目录优先，再文件；同层按名称本地化排序。
    #expect(children.map(\.name) == ["Book A", "Book B", "bonus.m4b"])
    #expect(children.map(\.isDirectory) == [true, true, false])

    let bookBNode = try #require(children.first { $0.name == "Book B" })
    #expect(bookBNode.children?.map(\.name) == ["Disc 1"])
    #expect(bookBNode.childCount == 1)
    #expect(bookBNode.isExpandable)

    let disc1Node = try #require(bookBNode.children?.first)
    #expect(disc1Node.children?.map(\.name) == ["track.mp3"])
    #expect(disc1Node.isExpandable)

    let fileNode = try #require(children.first { $0.name == "bonus.m4b" })
    #expect(fileNode.isDirectory == false)
    #expect(fileNode.childCount == 0)
    #expect(!fileNode.isExpandable)
}

@Test func bookTreeBuilderSkipsHiddenAndUnsupportedFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: root.appendingPathComponent("chapter.m4b"))
    try Data("hidden".utf8).write(to: root.appendingPathComponent(".hidden.m4b"))
    try Data("notes".utf8).write(to: root.appendingPathComponent("notes.txt"))
    try Data("cover".utf8).write(to: root.appendingPathComponent("cover.jpg"))

    let children = BookTreeBuilder.buildRootChildren(from: root)

    #expect(children.map(\.name) == ["chapter.m4b"])
    #expect(BookTreeBuilder.isSupportedAudioFile(root.appendingPathComponent("Chapter.M4B")))
    #expect(!BookTreeBuilder.isSupportedAudioFile(root.appendingPathComponent("notes.txt")))
}

@Test func bookTreeBuilderReturnsEmptyForMissingRoot() {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    #expect(BookTreeBuilder.buildRootChildren(from: root).isEmpty)
}
