import Foundation
import MagicKit
import ProviderBook

/// 有声书封面区的主语：这本书叫什么、正在听哪一章。
struct BookHeroSubject: Equatable {
    /// 书名；无法归到某一本书时回退为章节文件名。
    var bookTitle: String
    /// 章节名；书本身就是单文件时为 `nil`（不重复显示同一行）。
    var chapterTitle: String?
    /// 命中的书籍根 URL；用于取封面，未命中时为 `nil`。
    var bookURL: URL?
}

/// 把「正在播放的章节」映射为书籍封面区的主语。
///
/// 书本边界优先取书籍库的 DTO：章节可能属于某个书籍目录（多层目录也算），
/// 也可能本身就是一本书（单文件）。库还没给出列表时回退为章节文件名，
/// 避免封面区空着。
enum BookHeroSubjectResolver {
    static func resolve(
        chapterURL: URL,
        books: [BookDTO]
    ) -> BookHeroSubject {
        let chapterTitle = chapterURL.deletingPathExtension().lastPathComponent

        guard let book = matchingBook(for: chapterURL, in: books) else {
            // 没有书库口径（或章节不在任何书籍目录内）：章节自身就是一本单文件书。
            return BookHeroSubject(bookTitle: chapterTitle, chapterTitle: nil, bookURL: nil)
        }

        let subtitle: String? = book.isCollection && book.bookTitle != chapterTitle
            ? chapterTitle
            : nil
        return BookHeroSubject(bookTitle: book.bookTitle, chapterTitle: subtitle, bookURL: book.url)
    }

    private static func matchingBook(for chapterURL: URL, in books: [BookDTO]) -> BookDTO? {
        if let exact = books.first(where: { $0.url.isSameFileLocation(as: chapterURL) }) {
            return exact
        }

        return books
            .filter { $0.isCollection && $0.url.isFolder && contains(chapterURL, in: $0.url) }
            .max { $0.url.path.count < $1.url.path.count }
    }

    private static func contains(_ childURL: URL, in folderURL: URL) -> Bool {
        let folderPath = stablePath(for: folderURL)
        let childPath = stablePath(for: childURL)
        return childPath.hasPrefix(folderPath.hasSuffix("/") ? folderPath : folderPath + "/")
    }

    private static func stablePath(for url: URL) -> String {
        if FileManager.default.fileExists(atPath: url.path) {
            return url.resolvingSymlinksInPath().standardizedFileURL.path
        }
        return url.standardizedFileURL.path
    }
}
