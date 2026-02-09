import MagicKit
import OSLog
import SwiftData
import SwiftUI

struct BookList: View, SuperLog, SuperThread {
    nonisolated static let emoji = "📖"

    @EnvironmentObject var a: AppProvider
    @EnvironmentObject var messageManager: StateProvider

    @Query(
        filter: #Predicate<BookModel> { $0.isCollection == true },
        sort: \BookModel.order,
        animation: .default
    ) var books: [BookModel]

    var total: Int { books.count }
    var showTips: Bool {
        if a.isDropping {
            return true
        }

        return false
    }

    var body: some View {
//        os_log("\(self.t)开始渲染")
        return List(books) { item in
            BookTile(url: item.url, title: item.bookTitle, childCount: item.childCount)
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
    #Preview("App - Large") {
        ContentView()
    .inRootView()
            .frame(width: 600, height: 1000)
    }

    #Preview("App - Small") {
        ContentView()
    .inRootView()
            .frame(width: 600, height: 600)
    }
#endif

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
    .inRootView()
    }
#endif

