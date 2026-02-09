import Foundation
import MagicKit
import OSLog
import SwiftUI

/**
 * BookModel 的 DTO 转换扩展
 * 
 * 用途：提供 BookModel 到 BookDTO 的转换方法
 */
extension BookModel {
    /// 转换为数据传输对象
    /// - Returns: BookDTO 实例
    func toDTO() -> BookDTO {
        return BookDTO(
            url: self.url,
            bookTitle: self.bookTitle,
            childCount: self.childCount,
            isCollection: self.isCollection,
            order: self.order
        )
    }
}

/**
 * BookModel 数组的批量转换扩展
 */
extension Array where Element == BookModel {
    /// 批量转换为 DTO 数组
    /// - Returns: BookDTO 数组
    func toDTOs() -> [BookDTO] {
        return self.map { $0.toDTO() }
    }
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

