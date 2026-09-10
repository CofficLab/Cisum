import Foundation
import ProviderBook
import CisumUIComponents
import OSLog
import SwiftData
import SwiftUI

/**
 记录一本有声书的数据
 */
@Model
public class BookModel: SuperLog, Equatable {
    public static let emoji = "📖"
    @Transient public var db: BookRepo?

    @Attribute(.unique)
    public var url: URL
    
    public var currentURL: URL?
    public var isCollection: Bool = false
    public var parentBookURL: URL?
    public var bookTitle: String = ""
    public var childCount: Int = 0
    public var order: Int = 0
    public var coverData: Data?
    public var hasGetCover = false

    @Relationship(deleteRule: .noAction)
    public var parent: BookModel?

    @Relationship(deleteRule: .noAction, inverse: \BookModel.parent)
    public var childBooks: [BookModel]?

    public init(url: URL, currentURL: URL? = nil, order: Int = 0) {
        self.url = url
        self.currentURL = currentURL
        self.order = order
        self.bookTitle = self.url.title
        self.isCollection = BookLibraryItemSupport.isCollection(self.url)
        self.parentBookURL = self.url.getParent()
        self.childCount = Self.playableChildCount(for: self.url)
    }

    public func getParentURL() -> URL? {
        url.deletingLastPathComponent()
    }

    public func nextURL() -> URL? {
        url.getNextFile()
    }

    public func setDB(_ db: BookRepo?) {
        self.db = db
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: BookModel, rhs: BookModel) -> Bool {
        return lhs.url == rhs.url
    }

    static func playableChildCount(for url: URL) -> Int {
        BookLibraryItemSupport.playableChildCount(for: url)
    }
}

// MARK: Cover

extension BookModel {
    public func getBookCoverFromDB(verbose: Bool = false) async -> Image? {
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
    public static let descriptorIsFolder = FetchDescriptor(predicate: #Predicate<BookModel> { book in
        book.isCollection == true
    }, sortBy: [])

    public static let descriptorNotFolder = FetchDescriptor(predicate: #Predicate<BookModel> { book in
        book.isCollection == false
    }, sortBy: [])

    public static let descriptorAll = FetchDescriptor(predicate: #Predicate<BookModel> { _ in
        true
    }, sortBy: [])

    public static func descriptorOf(_ url: URL) -> FetchDescriptor<BookModel> {
        FetchDescriptor(predicate: #Predicate<BookModel> { s in
            s.url == url
        }, sortBy: [])
    }

    public static func descriptorOfParentBookURL(_ url: URL) -> FetchDescriptor<BookModel> {
        FetchDescriptor(predicate: #Predicate<BookModel> { s in
            s.parentBookURL == url
        }, sortBy: [])
    }

    public static func descriptorOfHasParentBookURL() -> FetchDescriptor<BookModel> {
        FetchDescriptor(predicate: #Predicate<BookModel> { s in
            s.parentBookURL != nil
        }, sortBy: [])
    }

    public static func descriptorOfNeedUpdateParent() -> FetchDescriptor<BookModel> {
        FetchDescriptor(predicate: #Predicate<BookModel> { s in
            s.parentBookURL != nil && s.parent == nil
        }, sortBy: [])
    }
}

public enum BookModelError: Error, LocalizedError {
    case deleteFailed
    case dbNotFound

    public var errorDescription: String? {
        switch self {
        case .deleteFailed:
            return "Delete failed"
        case .dbNotFound:
            return "BookModel: DB not found"
        }
    }
}
