import Foundation
import OSLog

/// Data 类型的扩展，提供文件保存功能
extension Data {
    /// 将 Data 数据保存到指定的 URL 路径
    ///
    /// - Parameter url: 要保存数据的目标 URL 路径
    /// - Throws: 如果保存过程中发生错误，会抛出错误
    ///
    /// # 示例
    /// ```swift
    /// let data = "Hello".data(using: .utf8)!
    /// let url = URL(fileURLWithPath: "/path/to/file.txt")
    /// try data.save(url)
    /// ```
    public func save(_ url: URL) throws {        
        try self.write(to: url.createIfNotExist())
    }
}

