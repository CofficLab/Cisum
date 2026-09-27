import Foundation
import CisumUIComponents
import MagicKit
import LumiUI
import OSLog
import SwiftUI

/**
 * 书籍数据传输对象（DTO）
 * 
 * 用途：
 * - 在并发上下文之间安全传输书籍数据
 * - 将 SwiftData Model 转换为 Sendable 类型
 * - 解耦数据层和视图层
 * 
 * 使用场景：
 * - 从 BookDB actor 传输到 BookRepo
 * - 从 BookRepo 传输到视图层
 * - 跨线程数据传递
 */
public struct BookDTO: Identifiable, Sendable, Equatable {
    // MARK: - Properties
    
    /// 唯一标识符（使用 URL 作为 ID）
    public let id: URL
    
    /// 书籍文件 URL
    public let url: URL
    
    /// 书籍标题
    public let bookTitle: String
    
    /// 子文件数量
    public let childCount: Int
    
    /// 是否为集合（文件夹）
    public let isCollection: Bool
    
    /// 排序顺序
    public let order: Int
    
    // MARK: - Initialization
    
    /// 初始化书籍 DTO
    /// - Parameters:
    ///   - url: 书籍 URL
    ///   - bookTitle: 书籍标题
    ///   - childCount: 子文件数量
    ///   - isCollection: 是否为集合
    ///   - order: 排序顺序
    public init(
        url: URL,
        bookTitle: String,
        childCount: Int,
        isCollection: Bool,
        order: Int
    ) {
        self.id = url
        self.url = url
        self.bookTitle = bookTitle
        self.childCount = childCount
        self.isCollection = isCollection
        self.order = order
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: BookDTO, rhs: BookDTO) -> Bool {
        return lhs.url == rhs.url
    }
}

// MARK: - Computed Properties

extension BookDTO {
    /// 是否为单个书籍（非集合）
    public var isBook: Bool {
        !isCollection
    }
    
    /// 是否有子文件
    public var hasChildren: Bool {
        childCount > 0
    }
}

// MARK: - Helper Methods

extension BookDTO {
    /// 获取父目录 URL
    public func getParentURL() -> URL? {
        url.deletingLastPathComponent()
    }
    
    /// 获取下一个文件 URL
    public func getNextURL() -> URL? {
        url.getNextFile()
    }
    
    /// 获取所有子文件 URL
    public func getChildrenURLs() -> [URL] {
        url.getChildren()
    }
}
