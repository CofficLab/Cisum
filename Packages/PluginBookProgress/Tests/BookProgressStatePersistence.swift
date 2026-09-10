import Foundation
import ProviderBook
import ProviderBookData
import SwiftData

enum BookProgressStatePersistence {
    static func save(
        bookURL: URL,
        currentURL: URL?,
        time: TimeInterval?,
        container: ModelContainer
    ) throws {
        let context = ModelContext(container)
        let descriptor = BookState.descriptorOf(bookURL)

        let existingState = try context.fetch(descriptor).first
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
            let newState = BookState(url: bookURL, currentURL: currentURL, time: time ?? 0)
            context.insert(newState)
        }

        try context.save()
        NotificationCenter.postBookStateUpdated(bookURL: bookURL)
    }
}
