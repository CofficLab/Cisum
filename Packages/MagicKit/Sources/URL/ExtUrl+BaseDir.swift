import Foundation

public extension URL {
    /// 用户的下载目录
    static var downloads: URL {
        get throws {
            try FileManager.default.url(for: .downloadsDirectory,
                                      in: .userDomainMask,
                                      appropriateFor: nil,
                                      create: true)
        }
    }
    
    /// 用户的文档目录
    static var documents: URL {
        get throws {
            try FileManager.default.url(for: .documentDirectory,
                                      in: .userDomainMask,
                                      appropriateFor: nil,
                                      create: true)
        }
    }
    
    /// 应用的缓存目录
    static var caches: URL {
        get throws {
            try FileManager.default.url(for: .cachesDirectory,
                                      in: .userDomainMask,
                                      appropriateFor: nil,
                                      create: true)
        }
    }
    
    /// 应用的临时目录
    static var temp: URL {
        FileManager.default.temporaryDirectory
    }
    
    /// 应用的资源目录
    static var applicationSupport: URL {
        get throws {
            try FileManager.default.url(for: .applicationSupportDirectory,
                                      in: .userDomainMask,
                                      appropriateFor: nil,
                                      create: true)
        }
    }
    
    /// 应用专属的 Application Support 目录
    static var appSpecificSupport: URL {
        get throws {
            try applicationSupport.appendingPathComponent(MagicApp.getBundleIdentifier())
        }
    }
    
    /// 应用的沙盒容器目录
    static var container: URL {
        get throws {
            try documents.deletingLastPathComponent()
        }
    }
    
    /// 应用的 iCloud 容器目录
    static var cloudContainer: URL? {
        guard MagicApp.isICloudAvailable() else { return nil }
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)
    }
    
    /// 应用在 iCloud 中的 Documents 目录
    static var cloudDocuments: URL? {
        cloudContainer?.appendingPathComponent("Documents")
    }
    
    /// 应用的数据库目录
    static var database: URL {
        get throws {
            let dbDirectory = try appSpecificSupport.appendingPathComponent("Database", isDirectory: true)
            try FileManager.default.createDirectory(
                at: dbDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return dbDirectory
        }
    }
    
    /// 获取特定数据库文件的路径
    /// - Parameter filename: 数据库文件名（例如："app.db"）
    /// - Returns: 数据库文件的完整 URL
    static func databasePath(filename: String) throws -> URL {
        try database.appendingPathComponent(filename)
    }
}
