import Foundation
import ProviderBook
import ProviderBookData
import SwiftData

enum BookDBViewBookStateLookup {
    static func findBookState(for bookURL: URL, in context: ModelContext) throws -> BookState? {
        let descriptor = BookState.descriptorOf(bookURL)
        if let state = try context.fetch(descriptor).first {
            return state
        }
        return try context.fetch(BookState.descriptorAll).first { state in
            BookState.representsSameBookURL(state.url, as: bookURL)
        }
    }
}
