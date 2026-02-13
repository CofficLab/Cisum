import Foundation
import MagicKit
import OSLog
import SwiftData
import SwiftUI

actor BookDB: ModelActor, ObservableObject, SuperLog, SuperEvent, SuperThread {
    static let emoji = "📦"
    static let verbose = false

    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor
    let context: ModelContext
    let queue = DispatchQueue(label: "DB")


    var onUpdated: () -> Void = { os_log("🍋 DB::updated") }

    init(_ container: ModelContainer, reason: String) {
        if Self.verbose {
            let message = "\(Self.t)🚩🚩🚩 初始化(\(reason))"

            os_log("\(message)")
        }

        modelContainer = container
        context = ModelContext(container)
        context.autosaveEnabled = false
        modelExecutor = DefaultSerialModelExecutor(
            modelContext: context
        )
    }

    func setOnUpdated(_ callback: @escaping () -> Void) {
        onUpdated = callback
    }

    func hasChanges() -> Bool {
        context.hasChanges
    }
}

// MARK: 增加

extension BookDB {
    func insertModel(_ model: any PersistentModel) throws {
        context.insert(model)
        try context.save()
    }
}

// MARK: 删除

extension BookDB {
    func destroy<T>(for model: T.Type) throws where T: PersistentModel {
        try context.delete(model: T.self)
    }
}

// MARK: 查询

extension BookDB {
    /// 所有指定的model
    func all<T: PersistentModel>() throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    /// 分页的方式查询model
    func paginate<T: PersistentModel>(page: Int) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    /// 获取指定条件的数量
    func getCount<T: PersistentModel>(for predicate: Predicate<T>) throws -> Int {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try context.fetchCount(descriptor)
    }

    /// 按照指定条件查询多个model
    func get<T: PersistentModel>(for predicate: Predicate<T>) throws -> [T] {
        // os_log("\(self.isMain) 🏠 LocalDB.get")
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try context.fetch(descriptor)
    }

    /// 某个model的总条数
    func count<T>(for model: T.Type) throws -> Int where T: PersistentModel {
        let descriptor = FetchDescriptor<T>(predicate: .true)
        return try context.fetchCount(descriptor)
    }
    
    /// 获取所有书籍的数据传输对象
    /// - Returns: 所有书籍的 BookDTO 数组
    func allBookDTOs() throws -> [BookDTO] {
        let books: [BookModel] = try context.fetch(FetchDescriptor<BookModel>())
        return books.toDTOs()
    }
}

// MARK: 辅助类函数

extension BookDB {
    /// 执行并输出耗时
    func printRunTime(_ title: String, tolerance: Double = 0.1, verbose: Bool = false, _ code: () -> Void) {
        if verbose {
            os_log("\(self.t)\(title)")
        }

        let startTime = DispatchTime.now()

        code()

        // 计算代码执行时间
        let nanoTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1000000000

        if verbose && timeInterval > tolerance {
            os_log("\(self.t)\(title) cost \(timeInterval) 秒 🐢🐢🐢")
        }
    }

    nonisolated func jobEnd(_ startTime: DispatchTime, title: String, tolerance: Double = 1.0) -> String {
        // 计算代码执行时间
        let nanoTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1000000000

        if timeInterval > tolerance {
            return "\(title) \(timeInterval) 秒 🐢🐢🐢"
        }

        return "\(title) \(timeInterval) 秒 🐢🐢🐢"
    }
}

extension BookDB {
    static func first(context: ModelContext) -> BookModel? {
        var descriptor = FetchDescriptor<BookModel>(predicate: #Predicate<BookModel> {
            $0.bookTitle != ""
        }, sortBy: [
            SortDescriptor(\.order, order: .forward),
        ])
        descriptor.fetchLimit = 1

        do {
            return try context.fetch(descriptor).first
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        return nil
    }

    static func nextOf(context: ModelContext, book: BookModel) -> BookModel? {
        os_log("🍋 DB::nextOf [\(book.order)] \(book.bookTitle)")
        let order = book.order
        let url = book.url
        var descriptor = FetchDescriptor<BookModel>()
        descriptor.sortBy.append(.init(\.order, order: .forward))
        descriptor.fetchLimit = 1
        descriptor.predicate = #Predicate {
            $0.order >= order && $0.url != url
        }

        do {
            let result = try context.fetch(descriptor)
            let next = result.first ?? Self.first(context: context)
            // os_log("🍋 DBAudio::nextOf [\(audio.order)] \(audio.title) -> [\(next?.order ?? -1)] \(next?.title ?? "-")")
            return next
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        return nil
    }

    func delete(ids: [BookModel.ID], verbose: Bool) -> BookModel? {
        if verbose {
            os_log("\(self.t)删除")
        }

        // 本批次的最后一个删除后的下一个
        var next: BookModel?

        for (index, id) in ids.enumerated() {
            guard let book = context.model(for: id) as? BookModel else {
                os_log(.error, "\(self.t)删除时找不到")
                continue
            }

            let url = book.url

            // 找出本批次的最后一个删除后的下一个
            if index == ids.count - 1 {
                next = Self.nextOf(context: context, book: book)

                // 如果下一个等于当前，设为空
                if next?.url == url {
                    next = nil
                }
            }

            do {
                context.delete(book)
                try context.save()
            } catch let e {
                os_log(.error, "\(self.t)删除出错 \(e)")
            }
        }

        return next
    }

    func sync(_ items: [URL], isFirst: Bool) {
        var message = "\(self.t)SyncBook(\(items.count))"

        if let first = items.first, first.checkIsDownloading() == true {
            message += " -> \(first.title) -> \(String(format: "%.0f", first.getDownloadProgressSnapshot()))% ⏬⏬⏬"
        }

        if isFirst {
            message += " Full"
        } else {
            message += " Update"
        }

        if Self.verbose {
            os_log("\(message)")
        }

        if isFirst {
            bookSyncWithDisk(items)
        } else {
            bookSyncWithUpdatedItems(items)
        }
    }

    // MARK: SyncWithDisk

    private func bookSyncWithDisk(_ items: [URL]) {
        let verbose = false
        let startTime: DispatchTime = .now()

        // 将数组转换成哈希表，方便通过键来快速查找元素，这样可以将时间复杂度降低到：O(m+n)
        var hashMap = [URL: URL]()
        for element in items {
            hashMap[element] = element
        }

        do {
            try context.enumerate(FetchDescriptor<BookModel>(), block: { book in
                if let item = hashMap[book.url] {
                    // 更新数据库记录
                    book.isCollection = item.isDirectory
                    book.bookTitle = book.bookTitle

                    // 记录存在哈希表中，同步完成，删除哈希表记录
                    hashMap.removeValue(forKey: book.url)
                } else {
                    // 记录不存在哈希表中，数据库删除
                    if verbose {
                        os_log("\(self.t) 删除 \(book.bookTitle)")
                    }
                    context.delete(book)
                }
            })

            // 余下的是需要插入数据库的
            for (_, value) in hashMap {
                context.insert(BookModel(url: value))
            }
        } catch {
            os_log(.error, "\(error.localizedDescription)")
        }

        do {
            try context.save()
        } catch {
            os_log(.error, "\(error.localizedDescription)")
        }

        if Self.verbose {
            os_log("\(self.jobEnd(startTime, title: "\(self.t)SyncBookWithDisk(\(items.count))", tolerance: 0.01))")
        }

        self.updateBookParent()
    }

    // MARK: SyncWithUpdatedItems

    func bookSyncWithUpdatedItems(_ metas: [URL], verbose: Bool = false) {
//        if verbose {
//            os_log("\(self.t)SyncWithUpdatedItems with count=\(metas.count)")
//        }
//
//        // 如果url属性为unique，数据库已存在相同url的记录，再执行context.insert，发现已存在的被替换成新的了
//        // 但在这里，希望如果存在，就不要插入
//        for (_, meta) in metas.files.enumerated() {
//            if meta.isDeleted {
//                let deletedURL = meta.url
//
//                do {
//                    try context.delete(model: Book.self, where: #Predicate { book in
//                        book.url == deletedURL
//                    })
//                } catch let e {
//                    os_log(.error, "\(e.localizedDescription)")
//                }
//            } else {
//                if findBook(meta.url) == nil {
//                    context.insert(meta.toBook())
//                }
//            }
//        }
//
//        do {
//            try context.save()
//        } catch let e {
//            os_log(.error, "\(e.localizedDescription)")
//        }
    }
}

// MARK: - BookState Operations

extension BookDB {
    /// 查找书籍状态
    func findBookState(_ url: URL) -> BookState? {
        do {
            let descriptor = BookState.descriptorOf(url)
            let result = try context.fetch(descriptor)
            return result.first
        } catch {
            os_log(.error, "\(self.t)查找书籍状态失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 更新书籍当前播放的URL
    func updateBookCurrent(_ bookURL: URL, currentURL: URL?, time: TimeInterval? = nil) {
        if let existingState = findBookState(bookURL) {
            // 更新现有状态
            existingState.currentURL = currentURL
            if let time = time {
                existingState.time = time
            }
            existingState.updateAt = .now
        } else {
            // 创建新状态
            let newState = BookState(url: bookURL, currentURL: currentURL, time: time ?? 0)
            context.insert(newState)
        }

        do {
            try context.save()
            if Self.verbose {
                os_log("\(self.t)💾 保存书籍状态: \(bookURL.lastPathComponent)")
            }
        } catch {
            os_log(.error, "\(self.t)保存书籍状态失败: \(error.localizedDescription)")
        }
    }

    /// 获取书籍的播放时间
    func getBookTime(_ bookURL: URL) -> TimeInterval? {
        findBookState(bookURL)?.time
    }
}

#Preview {
    RootView {
        ContentView()
    }
}
