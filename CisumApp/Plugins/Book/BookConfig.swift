import Foundation
import SwiftUI
import SwiftData

struct BookConfig {
    @MainActor static func getDBUrl() throws -> URL {
        try Config.getDBRootDir()
            .appendingPathComponent("books_db")
            .appendingPathComponent("books.db")
    }
    
    @MainActor static func getCoverFolderUrl() throws -> URL {
         try Config.getDBRootDir()
            .appendingPathComponent("books_cover")
    }
 
    @MainActor static func getContainer() throws -> ModelContainer {
        let url = try getDBUrl()

        let schema = Schema([
            BookModel.self,
            BookState.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}
