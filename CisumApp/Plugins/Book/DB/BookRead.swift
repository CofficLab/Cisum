import Foundation
import SwiftUI
import OSLog
import SwiftData

extension BookDB {
    func getBookCount() -> Int {
        do {
            return try context.fetchCount(BookModel.descriptorAll)
        } catch {
            os_log(.error, "\(error.localizedDescription)")
            
            return 0
        }
    }

    func getBookCountOfNoCoverData() -> Int {
        do {
            return try context.fetchCount(BookModel.descriptorOfShouldUpdateCover)
        } catch {
            os_log(.error, "\(error.localizedDescription)")
            
            return 0
        }
    }

    func getBooksShouldUpdateCover() -> [BookModel] {
        do {
            return try context.fetch(BookModel.descriptorOfShouldUpdateCover)
        } catch {
            os_log(.error, "\(error.localizedDescription)")
            
            return []
        }
    }
    
    func getBooksOfCollectionType() -> [BookModel] {
        do {
            return try context.fetch(BookModel.descriptorOfFolder)
        } catch {
            os_log(.error, "\(error.localizedDescription)")
            
            return []
        }
    }
    
    func getBooks() -> [URL] {
        self.getBooksOfCollectionType().map(\.url)
    }
}

// MARK: First

extension BookDB {
    static func firstBook(context: ModelContext) -> BookModel? {
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

    /// 第一个
    nonisolated func firstBook() -> BookModel? {
        Self.firstBook(context: ModelContext(self.modelContainer))
    }
}

// MARK: Find

extension BookDB {
    static func findBook(_ url: URL, context: ModelContext, verbose: Bool = false) -> BookModel? {
        if verbose {
            os_log("\(self.t)FindBook -> \(url.lastPathComponent)")
        }
        
        do {
            return try context.fetch(BookModel.descriptorOf(url)).first
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        return nil
    }
    
    func findBook(url: URL) -> BookModel? {
        Self.findBook(url, context: context)
    }
    
//    func findBook(_ id: BookModel.ID) -> BookModel? {
//        context.model(for: id) as? BookModel
//    }
    
    func findOrCreateBook(_ url: URL) -> BookModel? {
        if let book = self.findBook(url: url) {
            return book
        } else {
            let book = BookModel(url: url)
            context.insert(BookModel(url: url))
            
//            do {
//                try context.save()
//            } catch {
//                os_log(.error, "\(error.localizedDescription)")
//            }
            return book
//            return self.findBook(url)
        }
    }
    
    func hasBook(_ url: URL) -> Bool {
        self.findBook(url: url) != nil
    }
}

// MARK: Children

extension BookDB {
    func getChildren(_ url: URL, verbose: Bool = true) -> [BookModel] {
        if verbose {
            os_log("\(self.t)GetChildren -> \(url.lastPathComponent)")
        }
        
        do {
            return try context.fetch(FetchDescriptor<BookModel>(predicate: #Predicate<BookModel> {
                $0.url.absoluteString == url.absoluteString
            }))
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        return []
    }
}


// MARK: Next

extension BookDB {
    nonisolated func getNextBookOf(_ url: URL?, verbose: Bool = false) -> BookModel? {
        if verbose {
            os_log("\(self.t)NextBookOf -> \(url?.lastPathComponent ?? "-")")
        }
        
        guard let url = url else {
            return nil
        }
        
        let context = ModelContext(self.modelContainer)
        guard let book = Self.findBook(url, context: context) else {
            return nil
        }
        
        return Self.nextBookOf(context: context, book: book)
    }
    
    /// The next one of provided URL
    func nextBookOf(_ url: URL?, verbose: Bool = false) -> BookModel? {
        if verbose {
            os_log("\(self.t)NextBookOf -> \(url?.lastPathComponent ?? "-")")
        }
        
        guard let url = url else {
            return nil
        }
        
        guard let book = self.findBook(url: url) else {
            return nil
        }
        
        return self.nextBookOf(book)
    }

    /// The next one of provided Book
    func nextBookOf(_ book: BookModel) -> BookModel? {
        Self.nextBookOf(context: context, book: book)
    }
    
    static func nextBookOf(context: ModelContext, book: BookModel) -> BookModel? {
        //os_log("🍋 DBAudio::nextOf [\(audio.order)] \(audio.title)")
        let order = 1
        let url = book.url
        var descriptor = FetchDescriptor<BookModel>()
        descriptor.sortBy.append(.init(\.order, order: .forward))
        descriptor.fetchLimit = 1
        descriptor.predicate = #Predicate {
            $0.order >= order && $0.url != url
        }

        do {
            let result = try context.fetch(descriptor)
            let next = result.first ?? Self.firstBook(context: context)
            //os_log("🍋 DBAudio::nextOf [\(audio.order)] \(audio.title) -> [\(next?.order ?? -1)] \(next?.title ?? "-")")
            return next
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        return nil
    }
}

// MARK: Cover

extension BookDB {
    func getCover(_ bookURL: URL) async -> Image? {
//        guard let book = self.findBook(bookURL) else {
//            return nil
//        }
//        
//        if let image = await book.getBookCoverFromDB() {
//            return image
//        }
//        
//        if let parent = self.findBook(bookURL.deletingLastPathComponent()) {
//            return await self.getCover(parent.url)
//        }
        
        return nil
    }
}

// MARK: Descriptor

extension BookModel {
    static var descriptorOfShouldUpdateCover: FetchDescriptor<BookModel> {
        FetchDescriptor<BookModel>(predicate: #Predicate<BookModel> {
            $0.hasGetCover == false
        })
    }

    static var descriptorOfFolder: FetchDescriptor<BookModel> {
        FetchDescriptor<BookModel>(predicate: #Predicate<BookModel> {
            $0.isCollection == true
        })
    }
}

#if os(macOS)
    #Preview("App - Large") {
        ContentView()
    .inRootView()
            .frame(width: 600, height: 1000)
    }

    #Preview("App - Small") {
        ContentView()
    .inRootView()
            .frame(width: 500, height: 800)
    }
#endif

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
    .inRootView()
    }
#endif
