import Foundation
import Testing
import SwiftData
import ProviderBook
@testable import ProviderBookData

@Test
func bookStateProvidesSafeDefaultsAndCurrentChapterTitle() {
    let bookURL = URL(fileURLWithPath: "/library/Novel")
    let chapterURL = URL(fileURLWithPath: "/library/Novel/Chapter 01.mp3")
    let state = BookState(url: bookURL, currentURL: chapterURL)
    let emptyState = BookState(url: bookURL)

    #expect(state.url == bookURL)
    #expect(state.currentURL == chapterURL)
    #expect(state.fileHash == nil)
    #expect(state.currentFileHash == nil)
    #expect(state.relativePath == nil)
    #expect(state.currentTitle == "Chapter 01.mp3")
    #expect(state.time == 0)
    #expect(state.createdAt != nil)
    #expect(state.updateAt != nil)
    #expect(emptyState.currentTitle == "None")
}

@Test
func bookStateDescriptorsFetchAllAndMatchTheRequestedBook() throws {
    let schema = Schema([BookState.self])
    let container = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let firstURL = URL(fileURLWithPath: "/library/First")
    let secondURL = URL(fileURLWithPath: "/library/Second")
    context.insert(BookState(url: firstURL))
    context.insert(BookState(url: secondURL))
    try context.save()

    #expect(try context.fetch(BookState.descriptorAll).count == 2)
    #expect(try context.fetch(BookState.descriptorOf(firstURL)).map(\.url) == [firstURL])
    #expect(try context.fetch(BookState.descriptorOf(URL(fileURLWithPath: "/library/Missing"))).isEmpty)
}

@Test
func bookStateIdentityHandlesMissingAndAliasedURLs() throws {
    let bookURL = URL(fileURLWithPath: "/library/Novel")
    #expect(!BookState.representsSameBookURL(nil, as: bookURL))
    #expect(BookState.representsSameBookURL(bookURL, as: bookURL))

    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("BookStateIdentityTests-\(UUID().uuidString)", isDirectory: true)
    let realBook = root.appendingPathComponent("Novel.epub")
    let alias = root.appendingPathComponent("Alias.epub")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data([0x01]).write(to: realBook)
    try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: realBook)
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(BookState.representsSameBookURL(realBook, as: alias))
}

@Test
func bookDTOExposesStableIdentityAndCollectionState() {
    let url = URL(fileURLWithPath: "/library/Novel")
    let collection = BookDTO(url: url, bookTitle: "Novel", childCount: 2, isCollection: true, order: 4)
    let sameURL = BookDTO(url: url, bookTitle: "Renamed", childCount: 0, isCollection: false, order: 9)

    #expect(collection.id == url)
    #expect(collection.getParentURL() == url.deletingLastPathComponent())
    #expect(collection.isCollection)
    #expect(!collection.isBook)
    #expect(collection.hasChildren)
    #expect(!sameURL.isCollection)
    #expect(sameURL.isBook)
    #expect(!sameURL.hasChildren)
    #expect(collection == sameURL)
}

@Test
func bookDTOResolvesSiblingAndChildURLsFromTheFilesystem() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("BookDTOFileTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let first = root.appendingPathComponent("01.mp3")
    let second = root.appendingPathComponent("02.mp3")
    let third = root.appendingPathComponent("03.mp3")
    for url in [first, second, third] {
        try Data([0x01]).write(to: url)
    }
    let dto = BookDTO(url: second, bookTitle: "Second", childCount: 0, isCollection: false, order: 1)
    let collectionDTO = BookDTO(url: root, bookTitle: "Collection", childCount: 3, isCollection: true, order: 0)

    #expect(dto.getNextURL().map { BookPathContainment.representsSameFile($0, third) } == true)
    let childIdentities = Set(collectionDTO.getChildrenURLs().map(BookPathContainment.canonicalIdentity(for:)))
    #expect(childIdentities == Set([first, second, third].map(BookPathContainment.canonicalIdentity(for:))))
    #expect(BookDTO(url: third, bookTitle: "Third", childCount: 0, isCollection: false, order: 2).getNextURL() == nil)
}

@Test
func bookPluginInfoSeparatesAudiobookFilesFromMusicLibrary() {
    #expect(BookPluginInfo.dirName == "audios_book")
    #expect(BookPluginInfo.supportedExtensions.contains("m4b"))
    #expect(!BookPluginInfo.supportedExtensions.isEmpty)
}

@Test
func bookPluginErrorsProvideDescriptionsAndRecoveryHints() {
    let errors: [BookPluginError] = [
        .configurationMissing,
        .NoNextAsset,
        .NoPrevAsset,
        .NoDisk,
        .DiskNotFound,
        .initialization(reason: "test failure"),
    ]

    for error in errors {
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.failureReason?.isEmpty == false)
        #expect(error.recoverySuggestion?.isEmpty == false)
    }
    #expect(BookPluginError.initialization(reason: "database unavailable").errorDescription?.contains("database unavailable") == true)
}
