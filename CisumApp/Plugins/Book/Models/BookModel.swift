import Foundation
import MagicKit
import OSLog
import SwiftData
import SwiftUI

/**
 记录一本有声书的数据
 */
@Model
class BookModel: SuperLog, Equatable {
    static let emoji = "📖"
    @Transient var db: BookRepo?

    @Attribute(.unique)
    var url: URL
    
    var currentURL: URL?
    var isCollection: Bool = false
    var parentBookURL: URL?
    var bookTitle: String = ""
    var childCount: Int = 0
    var order: Int = 0
    var coverData: Data?
    var hasGetCover = false

    @Relationship(deleteRule: .noAction)
    var parent: BookModel?

    @Relationship(deleteRule: .noAction, inverse: \BookModel.parent)
    var childBooks: [BookModel]?

    init(url: URL, currentURL: URL? = nil) {
        self.url = url
        self.currentURL = currentURL
        self.bookTitle = self.url.title
        self.isCollection = self.url.isFolder
        self.parentBookURL = self.url.getParent()
        self.childCount = self.url.getChildren().count
    }

    func getParentURL() -> URL? {
        url.deletingLastPathComponent()
    }

    func nextURL() -> URL? {
        url.getNextFile()
    }

    func setDB(_ db: BookRepo?) {
        self.db = db
    }
    
    // MARK: - Equatable
    
    static func == (lhs: BookModel, rhs: BookModel) -> Bool {
        return lhs.url == rhs.url
    }
}

// MARK: Cover

extension BookModel {
    func getBookCoverFromDB(verbose: Bool = false) async -> Image? {
        if verbose {
            os_log("\(self.t)GetBookCover for \(self.bookTitle)")
        }

        if let coverData = self.coverData {
            if verbose {
                os_log("  🎉 GetBookCover From Database")
            }

            #if canImport(UIKit)
                if let uiImage = UIImage(data: coverData) {
                    return Image(uiImage: uiImage)
                }
            #elseif canImport(AppKit)
                if let nsImage = NSImage(data: coverData) {
                    return Image(nsImage: nsImage)
                }
            #endif
        }

        return nil
    }
}

// MARK: Descriptor

extension BookModel {
    static let descriptorIsFolder = FetchDescriptor(predicate: #Predicate<BookModel> { book in
        book.isCollection == true
    }, sortBy: [])

    static let descriptorNotFolder = FetchDescriptor(predicate: #Predicate<BookModel> { book in
        book.isCollection == false
    }, sortBy: [])

    static let descriptorAll = FetchDescriptor(predicate: #Predicate<BookModel> { _ in
        true
    }, sortBy: [])

    static func descriptorOf(_ url: URL) -> FetchDescriptor<BookModel> {
        FetchDescriptor(predicate: #Predicate<BookModel> { s in
            s.url == url
        }, sortBy: [])
    }

    static func descriptorOfParentBookURL(_ url: URL) -> FetchDescriptor<BookModel> {
        FetchDescriptor(predicate: #Predicate<BookModel> { s in
            s.parentBookURL == url
        }, sortBy: [])
    }

    static func descriptorOfHasParentBookURL() -> FetchDescriptor<BookModel> {
        FetchDescriptor(predicate: #Predicate<BookModel> { s in
            s.parentBookURL != nil
        }, sortBy: [])
    }

    static func descriptorOfNeedUpdateParent() -> FetchDescriptor<BookModel> {
        FetchDescriptor(predicate: #Predicate<BookModel> { s in
            s.parentBookURL != nil && s.parent == nil
        }, sortBy: [])
    }
}

enum BookModelError: Error, LocalizedError {
    case deleteFailed
    case dbNotFound

    var errorDescription: String? {
        switch self {
        case .deleteFailed:
            return "Delete failed"
        case .dbNotFound:
            return "BookModel: DB not found"
        }
    }
}

#Preview("App") {
    ContentView()
    .inRootView()
        .frame(height: 800)
}
