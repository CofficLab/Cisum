import Foundation
import Testing
@testable import ProviderBookData

struct BookLibraryPolicyTests {
    @Test
    func progressTextClampsFractionsAndHandlesNonFiniteValues() {
        #expect(BookDB.downloadProgressPercentText(forFraction: .nan) == "0")
        #expect(BookDB.downloadProgressPercentText(forFraction: .infinity) == "0")
        #expect(BookDB.downloadProgressPercentText(forFraction: -0.2) == "0")
        #expect(BookDB.downloadProgressPercentText(forFraction: 0.5) == "50")
        #expect(BookDB.downloadProgressPercentText(forFraction: 1.2) == "100")
    }

    @Test
    func libraryItemSupportDistinguishesPlayableFilesAndCollections() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookLibraryPolicyTests-\(UUID().uuidString)", isDirectory: true)
        let collection = temporaryRoot.appendingPathComponent("collection", isDirectory: true)
        let nested = collection.appendingPathComponent("nested", isDirectory: true)
        let unsupportedFolder = temporaryRoot.appendingPathComponent("documents", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unsupportedFolder, withIntermediateDirectories: true)
        let firstTrack = collection.appendingPathComponent("01.MP3")
        let secondTrack = nested.appendingPathComponent("02.m4b")
        try Data([0x01]).write(to: firstTrack)
        try Data([0x02]).write(to: secondTrack)
        try Data([0x03]).write(to: collection.appendingPathComponent(".hidden.flac"))
        try Data([0x04]).write(to: unsupportedFolder.appendingPathComponent("notes.txt"))
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        #expect(BookDB.isSupportedBookLibraryItem(firstTrack))
        #expect(!BookDB.isSupportedBookLibraryItem(temporaryRoot.appendingPathComponent("notes.txt")))
        #expect(BookDB.isSupportedBookLibraryItem(collection))
        #expect(BookLibraryItemSupport.isCollection(collection))
        #expect(BookLibraryItemSupport.playableChildCount(for: firstTrack) == 1)
        #expect(BookLibraryItemSupport.playableChildCount(for: collection) == 2)
        #expect(!BookDB.isSupportedBookLibraryItem(unsupportedFolder))
        #expect(BookLibraryItemSupport.playableChildCount(for: unsupportedFolder) == 0)
    }

    @Test
    func supportedItemsAreDeduplicatedByResolvedFileIdentity() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookLibraryIdentityTests-\(UUID().uuidString)", isDirectory: true)
        let audio = root.appendingPathComponent("track.mp3")
        let alias = root.appendingPathComponent("alias.mp3")
        let unsupported = root.appendingPathComponent("notes.txt")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data([0x01]).write(to: audio)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: audio)
        try Data([0x02]).write(to: unsupported)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(BookDB.uniqueSupportedBookLibraryItems([audio, alias, unsupported]) == [audio])
    }

    @Test
    func insertionOrderIsStableAndDuplicateOrdersAreDetected() {
        let urls = ["/library/z.mp3", "/library/a.mp3", "/library/m.mp3"].map { URL(fileURLWithPath: $0) }
        #expect(BookDB.sortedForStableInsertion(urls).map(\.lastPathComponent) == ["a.mp3", "m.mp3", "z.mp3"])
        #expect(!BookDB.needsStableOrderRepair([]))
        #expect(!BookDB.needsStableOrderRepair([100, 101, 102]))
        #expect(BookDB.needsStableOrderRepair([100, 100]))
    }

    @Test
    func bookContainmentChecksBothStoredBookAndCurrentChapterPaths() {
        let root = URL(fileURLWithPath: "/library", isDirectory: true)
        let child = root.appendingPathComponent("Novel/01.mp3")
        let outside = URL(fileURLWithPath: "/other/Novel")

        #expect(BookDB.contains(root, bookURL: child))
        #expect(!BookDB.contains(root, bookURL: outside))
        #expect(BookDB.contains(root, state: BookState(url: child)))
        #expect(BookDB.contains(root, state: BookState(url: outside, currentURL: child)))
        #expect(!BookDB.contains(root, state: BookState(url: outside)))
    }

    @Test
    func bookModelDerivesFileAndFolderMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookModelMetadataTests-\(UUID().uuidString)", isDirectory: true)
        let folder = root.appendingPathComponent("Novel", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let track = folder.appendingPathComponent("01.mp3")
        try Data([0x01]).write(to: track)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileModel = BookModel(url: track, order: 5)
        let folderModel = BookModel(url: folder)

        #expect(fileModel.bookTitle == "01")
        #expect(fileModel.order == 5)
        #expect(!fileModel.isCollection)
        #expect(fileModel.childCount == 1)
        #expect(fileModel.getParentURL() == folder)
        #expect(folderModel.bookTitle == "Novel")
        #expect(folderModel.isCollection)
        #expect(folderModel.childCount == 1)
    }
}
