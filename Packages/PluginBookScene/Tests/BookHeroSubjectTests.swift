import Foundation
import ProviderBook
import Testing
@testable import PluginBookScene

struct BookHeroSubjectTests {
    @Test
    func singleFileBookMatchesItself() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let bookURL = root.appendingPathComponent("单本.m4b")
        let subject = BookHeroSubjectResolver.resolve(
            chapterURL: bookURL,
            books: [BookDTO(url: bookURL, bookTitle: "单本", childCount: 1, isCollection: false, order: 0)]
        )

        #expect(subject.bookTitle == "单本")
        #expect(subject.chapterTitle == nil)
        #expect(subject.bookURL == bookURL)
    }

    @Test
    func chapterInsideCollectionResolvesBookAndChapter() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let bookURL = root.appendingPathComponent("三体", isDirectory: true)
        try FileManager.default.createDirectory(at: bookURL, withIntermediateDirectories: true)
        let chapterURL = bookURL.appendingPathComponent("第一章.m4b")

        let subject = BookHeroSubjectResolver.resolve(
            chapterURL: chapterURL,
            books: [BookDTO(url: bookURL, bookTitle: "三体", childCount: 3, isCollection: true, order: 0)]
        )

        #expect(subject.bookTitle == "三体")
        #expect(subject.chapterTitle == "第一章")
        #expect(subject.bookURL == bookURL)
    }

    @Test
    func chapterOutsideLibraryFallsBackToFileName() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let bookURL = root.appendingPathComponent("三体", isDirectory: true)
        try FileManager.default.createDirectory(at: bookURL, withIntermediateDirectories: true)
        let chapterURL = root.appendingPathComponent("音乐/另一首.mp3")

        let subject = BookHeroSubjectResolver.resolve(
            chapterURL: chapterURL,
            books: [BookDTO(url: bookURL, bookTitle: "三体", childCount: 3, isCollection: true, order: 0)]
        )

        #expect(subject.bookTitle == "另一首")
        #expect(subject.chapterTitle == nil)
        #expect(subject.bookURL == nil)
    }

    @Test
    func deepestCollectionWins() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let outerURL = root.appendingPathComponent("全集", isDirectory: true)
        let innerURL = outerURL.appendingPathComponent("第一部", isDirectory: true)
        try FileManager.default.createDirectory(at: innerURL, withIntermediateDirectories: true)
        let chapterURL = innerURL.appendingPathComponent("第一章.m4b")

        let subject = BookHeroSubjectResolver.resolve(
            chapterURL: chapterURL,
            books: [
                BookDTO(url: outerURL, bookTitle: "全集", childCount: 9, isCollection: true, order: 0),
                BookDTO(url: innerURL, bookTitle: "第一部", childCount: 3, isCollection: true, order: 1),
            ]
        )

        #expect(subject.bookTitle == "第一部")
        #expect(subject.chapterTitle == "第一章")
        #expect(subject.bookURL == innerURL)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookHeroSubjectTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
