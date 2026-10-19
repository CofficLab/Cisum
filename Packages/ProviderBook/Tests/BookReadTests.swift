import Foundation
import SwiftData
import Testing
@testable import ProviderBookData

/// 建立一个内存态的 BookDB，schema 与生产一致。
@MainActor
private func makeBookDB() throws -> BookDB {
    let schema = Schema([BookModel.self])
    let container = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return BookDB(container, reason: "BookReadTests")
}

private let sampleURL = URL(fileURLWithPath: "/library/Novel.epub")
private let otherURL = URL(fileURLWithPath: "/library/Other.epub")

// MARK: - 查找

/// 空库中查找不存在的书应返回 nil，而不是崩溃。
@MainActor
@Test func findBookReturnsNilForEmptyLibrary() async throws {
    let db = try makeBookDB()
    let found = await db.findBook(url: sampleURL)
    let has = await db.hasBook(sampleURL)
    let count = await db.getBookCount()

    #expect(found == nil)
    #expect(!has)
    #expect(count == 0)
}

/// 存入后应能按 URL 找回。
@MainActor
@Test func findBookLocatesInsertedBook() async throws {
    let db = try makeBookDB()
    let created = await db.findOrCreateBook(sampleURL)
    let has = await db.hasBook(sampleURL)
    let found = await db.findBook(url: sampleURL)

    #expect(created != nil)
    #expect(has)
    #expect(found?.url == sampleURL)
}

/// `findOrCreateBook` 对同一 URL 必须复用既有记录，
/// 否则重复导入会产生重复书籍。
@MainActor
@Test func findOrCreateReusesExistingBookForSameURL() async throws {
    let db = try makeBookDB()
    let first = await db.findOrCreateBook(sampleURL)
    let second = await db.findOrCreateBook(sampleURL)

    #expect(first != nil)
    #expect(second != nil)
    if let first, let second {
        #expect(first === second)
    }
}

/// 不同 URL 必须创建不同记录。
@MainActor
@Test func findOrCreateCreatesDistinctBooksForDistinctURLs() async throws {
    let db = try makeBookDB()
    let first = await db.findOrCreateBook(sampleURL)
    let second = await db.findOrCreateBook(otherURL)

    #expect(first !== second)
    #expect(await db.hasBook(sampleURL))
    #expect(await db.hasBook(otherURL))
}

// MARK: - 首个书籍

/// 空库没有「第一本书」。
@MainActor
@Test func firstBookIsNilWhenLibraryIsEmpty() async throws {
    let db = try makeBookDB()
    let first = await db.firstBook()
    #expect(first == nil)
}

// MARK: - 列表

/// 列表在空库时应为空。
@MainActor
@Test func bookListsAreEmptyForEmptyLibrary() async throws {
    let db = try makeBookDB()
    let urls = await db.getBooks()
    let collections = await db.getBooksOfCollectionType()
    let noCover = await db.getBookCountOfNoCoverData()
    let needCover = await db.getBooksShouldUpdateCover()

    #expect(urls.isEmpty)
    #expect(collections.isEmpty)
    #expect(noCover == 0)
    #expect(needCover.isEmpty)
}

/// 非合集书籍不应出现在「合集列表」中。
@MainActor
@Test func singleBookIsNotReportedAsCollection() async throws {
    let db = try makeBookDB()
    let book = await db.findOrCreateBook(sampleURL)
    let collections = await db.getBooksOfCollectionType()

    #expect(book != nil)
    // 单本书不是合集
    #expect(collections.isEmpty)
}

/// `getBooks()` 只返回**合集**的 URL（内部复用 `getBooksOfCollectionType()`），
/// 普通单本书不在其中。这是既有契约，不是缺陷。
@MainActor
@Test func getBooksOnlyReturnsCollectionsNotPlainBooks() async throws {
    let db = try makeBookDB()
    _ = await db.findOrCreateBook(sampleURL)

    let urls = await db.getBooks()
    let collections = await db.getBooksOfCollectionType()

    #expect(urls == collections.map(\.url))
    // 单本书不是合集，故不在列表中
    #expect(urls.isEmpty)
}

/// `firstBook` / `getNextBookOf` 依赖已持久化的记录。
///
/// `findOrCreateBook` 只 `context.insert` 而不 `save`（save 调用在源码中被注释掉），
/// 且 `BookDB` 构造时关闭了 `autosaveEnabled`。因此仅 insert 的记录不会出现在
/// 后续 fetch 的结果里。
///
/// 这里锁定该现状，避免有人误以为「插入即可见」；若将来恢复 save，
/// 本测试会失败并提醒同步更新为「插入即可见」的期望。
@MainActor
@Test func insertedBookIsNotVisibleToFetchWithoutSave() async throws {
    let db = try makeBookDB()
    _ = await db.findOrCreateBook(sampleURL)

    // 同一 context 的直接查询可见（模型本身已插入）
    let has = await db.hasBook(sampleURL)
    #expect(has)

    // 但依赖 fetch 的接口看不到未保存的记录
    let first = await db.firstBook()
    #expect(first == nil)

    let next = await db.getNextBookOf(nil)
    #expect(next == nil)
}

/// 空库时 `firstBook` / `getNextBookOf` 应为 nil。
@MainActor
@Test func firstAndNextBookAreNilForEmptyLibrary() async throws {
    let db = try makeBookDB()
    let first = await db.firstBook()
    let next = await db.getNextBookOf(nil)

    #expect(first == nil)
    #expect(next == nil)
}
