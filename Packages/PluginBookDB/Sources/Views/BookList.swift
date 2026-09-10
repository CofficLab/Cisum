import CisumUIComponents
import OSLog
import ProviderBook
import ProviderBook
import SwiftUI

struct BookList: View, SuperLog, SuperThread {
    nonisolated static let emoji = "📖"

    @Environment(\.bookDBViewDependencies) private var dependencies

    @State private var books: [BookDTO] = []

    private var displayableBooks: [BookDTO] { books }

    var total: Int { displayableBooks.count }
    var showTips: Bool {
        false
    }

    var body: some View {
        return List(displayableBooks) { item in
            BookTile(url: item.url, title: item.bookTitle, childCount: item.childCount)
        }
        .task {
            books = await dependencies.bookProvider?.books(reason: "BookList") ?? []
        }
    }
}

// MARK: - Action

extension BookList {
}

// MARK: - Event Handler

extension BookList {
}

// MARK: - Preview

#if os(macOS)

#endif
