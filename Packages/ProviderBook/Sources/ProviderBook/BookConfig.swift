import Foundation
import ProviderBook
import SwiftUI
import SwiftData

public struct BookConfig {
    public static func getDBUrl(dbRootURL: URL) -> URL {
        dbRootURL
            .appendingPathComponent("books_db")
            .appendingPathComponent("books.db")
    }
    
    public static func getCoverFolderUrl(dbRootURL: URL) -> URL {
         dbRootURL
            .appendingPathComponent("books_cover")
    }
 
    public static func getContainer(dbRootURL: URL) throws -> ModelContainer {
        let url = getDBUrl(dbRootURL: dbRootURL)
        try url.deletingLastPathComponent().ensureDirectory()

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

extension URL {
    @discardableResult
    public func ensureDirectory() throws -> URL {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue {
            try FileManager.default.removeItem(at: self)
        } else if (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil {
            try FileManager.default.removeItem(at: self)
        }

        try FileManager.default.createDirectory(
            at: self,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return self
    }
}
