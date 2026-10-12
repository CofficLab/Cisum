import Foundation
import Testing
@testable import ProviderBookData

struct BookPathContainmentTests {
    @Test
    func containmentIncludesRootAndDescendantsButNotSiblingPrefixes() {
        let root = URL(fileURLWithPath: "/tmp/audiobooks", isDirectory: true)

        #expect(BookPathContainment.contains(root, child: root))
        #expect(BookPathContainment.contains(root, child: root.appendingPathComponent("book/track.mp3")))
        #expect(!BookPathContainment.contains(root, child: URL(fileURLWithPath: "/tmp/audiobooks-old/track.mp3")))
    }

    @Test
    func canonicalIdentityUsesStandardizedPathForMissingFilesAndURLsForRemoteAssets() {
        let missing = URL(fileURLWithPath: "/tmp/audiobooks/../audiobooks/missing.mp3")
        let remote = URL(string: "https://example.com/a/../track.mp3")!

        #expect(BookPathContainment.canonicalIdentity(for: missing) == missing.standardizedFileURL.path)
        #expect(BookPathContainment.canonicalIdentity(for: remote) == remote.standardized.absoluteString)
    }

    @Test
    func symlinkAliasesResolveToTheSameBookAndStayWithinTheResolvedLibrary() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderBookTests-\(UUID().uuidString)", isDirectory: true)
        let realRoot = temporaryRoot.appendingPathComponent("library", isDirectory: true)
        let linkedRoot = temporaryRoot.appendingPathComponent("library-alias", isDirectory: true)
        let book = realRoot.appendingPathComponent("book/track.mp3")
        try FileManager.default.createDirectory(at: book.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x01]).write(to: book)
        try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        let linkedBook = linkedRoot.appendingPathComponent("book/track.mp3")
        #expect(BookPathContainment.representsSameFile(book, linkedBook))
        #expect(BookPathContainment.contains(linkedRoot, child: book))
    }

    @Test
    func sameResolvedParentRecognizesSymlinkedDirectory() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderBookParentTests-\(UUID().uuidString)", isDirectory: true)
        let realParent = temporaryRoot.appendingPathComponent("real", isDirectory: true)
        let linkedParent = temporaryRoot.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createDirectory(at: realParent, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linkedParent, withDestinationURL: realParent)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        let book = realParent.appendingPathComponent("book.epub")
        #expect(BookPathContainment.hasSameResolvedParent(book, as: linkedParent))
    }
}
