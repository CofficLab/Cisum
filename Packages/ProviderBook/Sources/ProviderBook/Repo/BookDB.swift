import Foundation
import ProviderBook
import CisumUIComponents
import OSLog
import SwiftData
import SwiftUI

public actor BookDB: ModelActor, ObservableObject, SuperLog, SuperEvent, SuperThread {
    public static let emoji = "📦"
    public static let verbose = false

    public let modelContainer: ModelContainer
    public let modelExecutor: any ModelExecutor
    public let context: ModelContext
    let queue = DispatchQueue(label: "DB")


    var onUpdated: () -> Void = { os_log("🍋 DB::updated") }

    public init(_ container: ModelContainer, reason: String) {
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

    static func downloadProgressPercentText(forFraction progress: Double) -> String {
        guard progress.isFinite else {
            return "0"
        }

        let percent = min(max(progress, 0), 1) * 100
        return String(format: "%.0f", percent)
    }
}

enum BookLibraryItemSupport {
    static func isSupported(_ url: URL) -> Bool {
        if isFolderLike(url) {
            return containsPlayableChild(in: url)
        }

        return BookPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func isCollection(_ url: URL) -> Bool {
        isFolderLike(url)
    }

    static func playableChildCount(for url: URL) -> Int {
        guard isFolderLike(url) else {
            return BookPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased()) ? 1 : 0
        }

        return playableChildCount(in: url)
    }

    private static func containsPlayableChild(in folder: URL) -> Bool {
        for child in playableChildSequence(in: folder) {
            if isPlayableChild(child) {
                return true
            }
        }

        return false
    }

    private static func playableChildCount(in folder: URL) -> Int {
        var count = 0
        for child in playableChildSequence(in: folder) where isPlayableChild(child) {
            count += 1
        }
        return count
    }

    private static func playableChildSequence(in folder: URL) -> AnySequence<URL> {
        let root = scanRoot(for: folder)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return AnySequence([])
        }

        return AnySequence {
            AnyIterator {
                while let child = enumerator.nextObject() as? URL {
                    if !child.isFolder {
                        return child
                    }
                }

                return nil
            }
        }
    }

    private static func isPlayableChild(_ url: URL) -> Bool {
        BookPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private static func isFolderLike(_ url: URL) -> Bool {
        url.isFolder || resolvedDirectoryURL(for: url) != nil
    }

    private static func resolvedDirectoryURL(for url: URL) -> URL? {
        let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
        return resolvedURL.isFolder ? resolvedURL : nil
    }

    private static func scanRoot(for folder: URL) -> URL {
        folder.isFolder ? folder : folder.resolvingSymlinksInPath().standardizedFileURL
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
    public func allBookDTOs() throws -> [BookDTO] {
        let books: [BookModel] = try context.fetch(FetchDescriptor<BookModel>())
        return books.toDTOs()
    }

    func playbackState(for bookURL: URL) throws -> BookPlaybackStateDTO? {
        let state = try context.fetch(BookState.descriptorOf(bookURL)).first
            ?? context.fetch(BookState.descriptorAll).first { state in
                BookState.representsSameBookURL(state.url, as: bookURL)
            }
        guard let state else { return nil }
        return BookPlaybackStateDTO(currentURL: state.currentURL, time: state.time)
    }

    func savePlaybackState(
        for bookURL: URL,
        currentURL: URL?,
        time: TimeInterval?
    ) throws {
        let existingState = try context.fetch(BookState.descriptorOf(bookURL)).first
            ?? context.fetch(BookState.descriptorAll).first { state in
                BookState.representsSameBookURL(state.url, as: bookURL)
            }

        if let existingState {
            existingState.currentURL = currentURL
            if let time {
                existingState.time = time
            }
            existingState.updateAt = .now
        } else {
            context.insert(BookState(url: bookURL, currentURL: currentURL, time: time ?? 0))
        }

        try context.save()
        NotificationCenter.postBookStateUpdated(bookURL: bookURL)
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
            os_log("\(self.t)\(title) cost \(timeInterval)s 🐢🐢🐢")
        }
    }

    nonisolated func jobEnd(_ startTime: DispatchTime, title: String, tolerance: Double = 1.0) -> String {
        // 计算代码执行时间
        let nanoTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1000000000

        if timeInterval > tolerance {
            return "\(title) \(timeInterval)s 🐢🐢🐢"
        }

        return "\(title) \(timeInterval)s 🐢🐢🐢"
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

    static func nextOf(context: ModelContext, book: BookModel, excluding excludedURLs: [URL] = []) -> BookModel? {
        os_log("🍋 DB::nextOf [\(book.order)] \(book.bookTitle)")
        let order = book.order
        let url = book.url
        var descriptor = FetchDescriptor<BookModel>()
        descriptor.sortBy.append(.init(\.order, order: .forward))
        descriptor.predicate = #Predicate {
            $0.order >= order && $0.url != url
        }

        do {
            let result = try context.fetch(descriptor)
            if let next = result.first(where: { candidate in
                !BookPathContainment.representsSameFile(candidate.url, url)
                    && !excludedURLs.contains { BookPathContainment.representsSameFile($0, candidate.url) }
            }) {
                return next
            }

            let allBooks = try context.fetch(BookModel.descriptorAll)
                .sorted { $0.order < $1.order }
            let next = allBooks.first { candidate in
                !BookPathContainment.representsSameFile(candidate.url, url)
                    && !excludedURLs.contains { BookPathContainment.representsSameFile($0, candidate.url) }
            }
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

        let urlsBeingDeleted = ids.compactMap { id in
            (context.model(for: id) as? BookModel)?.url
        }
        var deletedURLs: [URL] = []

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
                next = Self.nextOf(context: context, book: book, excluding: urlsBeingDeleted)

                // 如果下一个等于当前，设为空
                if next?.url == url {
                    next = nil
                }
            }

            do {
                deleteStates(for: url)
                context.delete(book)
                try context.save()
                deletedURLs.append(url)
            } catch let e {
                os_log(.error, "\(self.t)删除出错 \(e)")
            }
        }

        if !deletedURLs.isEmpty {
            NotificationCenter.postBookDBDeleted(urls: deletedURLs)
        }

        return next
    }

    func delete(urls: [URL]) {
        for deletedURL in urls {
            deleteModels(for: deletedURL)
        }

        saveAndNotifyDeleted(urls: urls)
    }

    public func sync(_ items: [URL], isFirst: Bool) {
        var message = "\(self.t)SyncBook(\(items.count))"

        if let first = items.first, first.checkIsDownloading() == true {
            message += " -> \(first.title) -> \(Self.downloadProgressPercentText(forFraction: first.getDownloadProgressSnapshot()))% ⏬⏬⏬"
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
            do {
                try bookSyncWithUpdatedItems(items)
            } catch let e {
                os_log(.error, "\(e.localizedDescription)")
            }
        }
    }

    public func syncImportedItems(_ items: [URL]) throws {
        try bookSyncWithUpdatedItems(items)
    }

    // MARK: SyncWithDisk

    private func bookSyncWithDisk(_ items: [URL]) {
        let verbose = false
        let startTime: DispatchTime = .now()

        // 将数组转换成哈希表，方便通过键来快速查找元素，这样可以将时间复杂度降低到：O(m+n)
        var hashMap = [URL: URL]()
        for element in Self.uniqueSupportedBookLibraryItems(items) {
            hashMap[element] = element
        }

        do {
            try context.enumerate(FetchDescriptor<BookModel>(), block: { book in
                if let item = removeMatchingSyncItem(for: book.url, from: &hashMap) {
                    // 更新数据库记录
                    update(book, from: item)

                    // 记录存在哈希表中，同步完成，删除哈希表记录。
                } else {
                    // 记录不存在哈希表中，数据库删除
                    if verbose {
                        os_log("\(self.t) 删除 \(book.bookTitle)")
                    }
                    deleteStates(for: book.url)
                    context.delete(book)
                }
            })

            // 余下的是需要插入数据库的，按路径稳定追加，避免首次导入后默认顺序随机。
            var nextOrder = nextAppendOrder()
            for value in Self.sortedForStableInsertion(Array(hashMap.values)) {
                context.insert(BookModel(url: value, order: nextOrder))
                nextOrder += 1
            }

            repairBookOrderIfNeeded()
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
        NotificationCenter.postBookDBSynced()
    }

    // MARK: SyncWithUpdatedItems

    func bookSyncWithUpdatedItems(_ metas: [URL], verbose: Bool = false) throws {
        let startTime: DispatchTime = .now()

        var nextOrder = nextAppendOrder()
        for meta in Self.sortedForStableInsertion(Self.uniqueSupportedBookLibraryItems(metas)) {
            if meta.isNotFileExist {
                deleteModels(for: meta)
            } else if !Self.isSupportedBookLibraryItem(meta) {
                deleteModels(for: meta)
            } else if let book = findBook(url: meta) {
                update(book, from: meta)
            } else {
                context.insert(BookModel(url: meta, order: nextOrder))
                nextOrder += 1
            }
        }

        repairBookOrderIfNeeded()
        try context.save()
        updateBookParent()
        NotificationCenter.postBookDBUpdated()

        if verbose {
            os_log("\(self.jobEnd(startTime, title: "\(self.t)SyncBookWithUpdatedItems(\(metas.count))", tolerance: 0.01))")
        }
    }

    static func isSupportedBookLibraryItem(_ url: URL) -> Bool {
        BookLibraryItemSupport.isSupported(url)
    }

    static func uniqueSupportedBookLibraryItems(_ urls: [URL]) -> [URL] {
        var seenIdentities = Set<String>()
        var uniqueURLs: [URL] = []
        uniqueURLs.reserveCapacity(urls.count)

        for url in urls where isSupportedBookLibraryItem(url) {
            let identity = BookPathContainment.canonicalIdentity(for: url)
            guard seenIdentities.insert(identity).inserted else { continue }
            uniqueURLs.append(url)
        }

        return uniqueURLs
    }

    private func nextAppendOrder() -> Int {
        var descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate<BookModel> { book in
                book.order != -1
            },
            sortBy: [SortDescriptor(\.order, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            return (try context.fetch(descriptor).first?.order ?? 99) + 1
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
            return 100
        }
    }

    static func sortedForStableInsertion(_ urls: [URL]) -> [URL] {
        urls.sorted {
            $0.standardizedFileURL.path.localizedStandardCompare($1.standardizedFileURL.path) == .orderedAscending
        }
    }

    private func repairBookOrderIfNeeded() {
        do {
            let books = try context.fetch(BookModel.descriptorAll)
            guard Self.needsStableOrderRepair(books.map(\.order)) else { return }

            var nextOrder = 100
            for book in Self.sortedForStableInsertion(books) {
                book.order = nextOrder
                nextOrder += 1
            }
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    static func needsStableOrderRepair(_ orders: [Int]) -> Bool {
        Set(orders).count != orders.count
    }

    private static func sortedForStableInsertion(_ books: [BookModel]) -> [BookModel] {
        books.sorted {
            $0.url.standardizedFileURL.path.localizedStandardCompare($1.url.standardizedFileURL.path) == .orderedAscending
        }
    }

    private func removeMatchingSyncItem(for url: URL, from hashMap: inout [URL: URL]) -> URL? {
        if let item = hashMap.removeValue(forKey: url) {
            return item
        }

        guard let matchingKey = hashMap.keys.first(where: { BookPathContainment.representsSameFile($0, url) }) else {
            return nil
        }

        return hashMap.removeValue(forKey: matchingKey)
    }

    private func update(_ book: BookModel, from url: URL) {
        book.isCollection = BookLibraryItemSupport.isCollection(url)
        book.bookTitle = url.title
        book.parentBookURL = url.getParent()
        book.childCount = BookModel.playableChildCount(for: url)
    }

    private func deleteModels(for deletedURL: URL) {
        do {
            let books = try context.fetch(BookModel.descriptorAll)
            for book in books where Self.contains(deletedURL, bookURL: book.url) {
                context.delete(book)
            }
            deleteStates(for: deletedURL)
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    static func contains(_ parentURL: URL, bookURL: URL) -> Bool {
        BookPathContainment.contains(parentURL, child: bookURL)
    }

    static func contains(_ parentURL: URL, state: BookState) -> Bool {
        [state.url, state.currentURL].contains { url in
            guard let url else { return false }
            return Self.contains(parentURL, bookURL: url)
        }
    }

    private func deleteStates(for deletedURL: URL) {
        do {
            let states = try context.fetch(BookState.descriptorAll)
            for state in states where Self.contains(deletedURL, state: state) {
                context.delete(state)
            }
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    private func saveAndNotifyDeleted(urls: [URL]) {
        do {
            try context.save()
            NotificationCenter.postBookDBDeleted(urls: urls)
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }
}

// MARK: - BookState Operations

extension BookDB {
    /// 查找书籍状态
    public func findBookState(_ url: URL) -> BookState? {
        do {
            let descriptor = BookState.descriptorOf(url)
            if let state = try context.fetch(descriptor).first {
                return state
            }

            return try context.fetch(BookState.descriptorAll).first { state in
                BookState.representsSameBookURL(state.url, as: url)
            }
        } catch {
            os_log(.error, "\(self.t)查找书籍状态失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 更新书籍当前播放的URL
    public func updateBookCurrent(_ bookURL: URL, currentURL: URL?, time: TimeInterval? = nil) {
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
            NotificationCenter.postBookStateUpdated(bookURL: bookURL)
            if Self.verbose {
                os_log("\(self.t)💾 保存书籍状态: \(bookURL.lastPathComponent)")
            }
        } catch {
            os_log(.error, "\(self.t)保存书籍状态失败: \(error.localizedDescription)")
        }
    }

    /// 获取书籍的播放时间
    public func getBookTime(_ bookURL: URL) -> TimeInterval? {
        findBookState(bookURL)?.time
    }
}
