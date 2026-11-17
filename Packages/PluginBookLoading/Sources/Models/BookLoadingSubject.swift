import Foundation

/// 横幅的主语：这本书叫什么、载入的是其中第几章。
///
/// `bookTitle` 为空表示书籍库还没给出书本边界，此时用 `chapterTitle`
/// （章节文件名 stem）兜底，避免横幅在解析完成前空着。
struct BookLoadingSubject: Equatable, Sendable {
    var bookTitle: String = ""
    var chapterIndex: Int?
    var chapterCount: Int?
    var chapterTitle: String = ""

    static let empty = BookLoadingSubject()

    var isEmpty: Bool {
        bookTitle.isEmpty && chapterTitle.isEmpty
    }

    /// 书名缺失时的回退主语。
    var fallbackTitle: String {
        bookTitle.isEmpty ? chapterTitle : bookTitle
    }

    /// 章节位置；章节数未知时不呈现，避免报出「第 1 章 / 共 0 章」。
    var chapterPosition: (index: Int, count: Int)? {
        guard let chapterIndex, let chapterCount, chapterCount > 0 else { return nil }
        return (chapterIndex, chapterCount)
    }
}