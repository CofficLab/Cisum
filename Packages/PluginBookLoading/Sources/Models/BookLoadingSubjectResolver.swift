import Foundation
import MagicKit

/// 书籍库交给横幅的最小书籍描述。
struct BookLoadingBookRef: Equatable, Sendable {
    let url: URL
    let title: String
    let childCount: Int
    let isCollection: Bool
}

/// 把「正在载入的章节文件」映射为书名与章节位置。
///
/// 书本边界优先取书籍库的顶层条目：章节可能是单文件书本身，也可能藏在
/// 多层目录（如 CD1/02.mp3）里。库尚未就绪时退回父目录推断。
/// 章节顺序按播放侧一致的相对路径自然排序，所以「第 n 章 / 共 m 章」
/// 与书卡上的章节数对得上。
enum BookLoadingSubjectResolver {
    static func resolve(
        chapterURL: URL?,
        books: [BookLoadingBookRef],
        libraryDisk: URL?,
        playableExtensions: Set<String>
    ) -> BookLoadingSubject {
        guard let chapterURL else { return .empty }

        let chapterTitle = chapterURL.title

        if let book = matchingBook(for: chapterURL, in: books) {
            guard book.isCollection else {
                return BookLoadingSubject(bookTitle: book.title, chapterTitle: chapterTitle)
            }

            return collectionSubject(
                bookURL: book.url,
                bookTitle: book.title,
                chapterURL: chapterURL,
                chapterTitle: chapterTitle,
                playableExtensions: playableExtensions
            )
        }

        let parent = chapterURL.deletingLastPathComponent()
        if let libraryDisk, parent.isSameFileLocation(as: libraryDisk) {
            return BookLoadingSubject(bookTitle: chapterTitle, chapterTitle: chapterTitle)
        }

        // 没有书籍库口径（能力未接入）时不去猜：父目录可能只是临时目录或
        // 书库根，按目录枚举会把无关文件算成章节。
        guard !playableExtensions.isEmpty else {
            return BookLoadingSubject(chapterTitle: chapterTitle)
        }

        return collectionSubject(
            bookURL: parent,
            bookTitle: parent.title,
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            playableExtensions: playableExtensions
        )
    }

    // MARK: - Book boundary

    private static func matchingBook(
        for chapterURL: URL,
        in books: [BookLoadingBookRef]
    ) -> BookLoadingBookRef? {
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
        return childPath == folderPath || childPath.hasPrefix(folderPrefix(folderPath))
    }

    private static func folderPrefix(_ path: String) -> String {
        path.hasSuffix("/") ? path : path + "/"
    }

    // MARK: - Chapter position

    private static func collectionSubject(
        bookURL: URL,
        bookTitle: String,
        chapterURL: URL,
        chapterTitle: String,
        playableExtensions: Set<String>
    ) -> BookLoadingSubject {
        let files = playableFiles(in: bookURL, extensions: playableExtensions)
        guard !files.isEmpty else {
            return BookLoadingSubject(bookTitle: bookTitle, chapterTitle: chapterTitle)
        }

        let index = files.firstIndex { $0.isSameFileLocation(as: chapterURL) }
        return BookLoadingSubject(
            bookTitle: bookTitle,
            chapterIndex: index.map { $0 + 1 },
            chapterCount: files.count,
            chapterTitle: chapterTitle
        )
    }

    private static func playableFiles(in folder: URL, extensions: Set<String>) -> [URL] {
        guard folder.isFolder else { return [] }

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            guard !url.isFolder else { continue }
            guard extensions.isEmpty || extensions.contains(url.pathExtension.lowercased()) else { continue }
            files.append(url)
        }

        let rootPath = stablePath(for: folder)
        return files.sorted {
            relativePath($0, rootPath: rootPath).localizedStandardCompare(
                relativePath($1, rootPath: rootPath)
            ) == .orderedAscending
        }
    }

    private static func relativePath(_ url: URL, rootPath: String) -> String {
        let path = stablePath(for: url)
        guard path.hasPrefix(folderPrefix(rootPath)) else {
            return url.lastPathComponent
        }
        return String(path.dropFirst(folderPrefix(rootPath).count))
    }

    private static func stablePath(for url: URL) -> String {
        if FileManager.default.fileExists(atPath: url.path) {
            return url.resolvingSymlinksInPath().standardizedFileURL.path
        }
        return url.standardizedFileURL.path
    }
}