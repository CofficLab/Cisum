import Foundation
import SwiftUI
import SwiftData

public struct BookConfig {
    /// 获取数据库文件 URL（在新布局下直接使用插件目录）
    public static func getDBUrl(pluginDirectory: URL) -> URL {
        pluginDirectory.appendingPathComponent("books.db")
    }
    
    /// 获取封面文件夹 URL（在新布局下直接使用插件目录）
    public static func getCoverFolderUrl(pluginDirectory: URL) -> URL {
        pluginDirectory.appendingPathComponent("books_cover")
    }
    
    /// 旧版 API：从 databaseRoot 获取数据库 URL（已废弃，用于迁移）
    public static func getDBUrl(dbRootURL: URL) -> URL {
        dbRootURL
            .appendingPathComponent("books_db")
            .appendingPathComponent("books.db")
    }
    
    /// 旧版 API：从 databaseRoot 获取封面文件夹 URL（已废弃，用于迁移）
    public static func getCoverFolderUrl(dbRootURL: URL) -> URL {
         dbRootURL
            .appendingPathComponent("books_cover")
    }
 
    public static func getContainer(pluginDirectory: URL) throws -> ModelContainer {
        let url = getDBUrl(pluginDirectory: pluginDirectory)
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
    
    /// 旧版 API：从 databaseRoot 创建容器（已废弃，用于迁移）
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