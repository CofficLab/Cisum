import Foundation
import SwiftUI

/// SwiftUI View 扩展，提供便捷的书籍数据库事件监听
extension View {
    /// 监听数据库同步完成事件
    /// - Parameter action: 同步完成时执行的操作
    /// - Returns: 添加了监听器的视图
    func onBookDBSynced(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .bookDBSynced), perform: action)
    }

    /// 监听数据库同步开始事件
    /// - Parameter action: 同步开始时执行的操作
    /// - Returns: 添加了监听器的视图
    func onBookDBSyncing(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .bookDBSyncing), perform: action)
    }

    /// 监听数据库更新事件
    /// - Parameter action: 数据库更新时执行的操作
    /// - Returns: 添加了监听器的视图
    func onBookDBUpdated(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .bookDBUpdated), perform: action)
    }

    /// 监听数据库删除事件
    /// - Parameter action: 数据库删除时执行的操作
    /// - Returns: 添加了监听器的视图
    func onBookDBDeleted(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .bookDBDeleted), perform: action)
    }

    /// 监听数据库排序开始事件
    /// - Parameter action: 数据库排序开始时执行的操作
    /// - Returns: 添加了监听器的视图
    func onBookDBSorting(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .bookDBSorting), perform: action)
    }

    /// 监听数据库排序完成事件
    /// - Parameter action: 数据库排序完成时执行的操作
    /// - Returns: 添加了监听器的视图
    func onBookDBSortDone(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .bookDBSortDone), perform: action)
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
