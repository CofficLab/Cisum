import Foundation
import SwiftUI

/// 音频插件的所有通知名称
extension Notification.Name {
    // MARK: - 音频数据同步相关

    /// 音频列表更新通知
    static let AudiosUpdatedNotification = Notification.Name("AudiosUpdatedNotification")

    /// 单个音频更新通知
    static let AudioUpdatedNotification = Notification.Name("AudioUpdatedNotification")

    /// 同步开始通知
    static let SyncingNotification = Notification.Name("SyncingNotification")

    /// 数据库同步开始
    static let dbSyncing = Notification.Name("dbSyncing")

    /// 数据库同步完成
    static let dbSynced = Notification.Name("dbSynced")

    /// 数据库更新
    static let dbUpdated = Notification.Name("dbUpdated")

    /// 文件系统同步完成
    static let fileSystemSynced = Notification.Name("fileSystemSynced")

    /// 文件系统删除完成
    static let fileSystemDeleted = Notification.Name("fileSystemDeleted")

    // MARK: - 音频文件操作相关

    /// 单个URL删除通知
    static let URLDeletedNotification = Notification.Name("URLDeletedNotification")

    /// 多个URL删除通知
    static let URLsDeletedNotification = Notification.Name("URLsDeletedNotification")

    /// 数据库删除操作
    static let dbDeleted = Notification.Name("dbDeleted")

    /// 文件复制操作
    static let CopyFiles = Notification.Name("CopyFiles")

    // MARK: - 音频排序相关

    /// 数据库排序开始
    static let DBSorting = Notification.Name("DBSorting")

    /// 数据库排序完成
    static let DBSortDone = Notification.Name("DBSortDone")

    // MARK: - 下载进度相关

    /// 音频下载进度
    static let audioDownloadProgress = Notification.Name("audioDownloadProgress")
}

/// SwiftUI View 扩展，提供便捷的音频数据库同步事件监听
extension View {
    /// 监听数据库同步完成事件
    /// - Parameter action: 同步完成时执行的操作
    /// - Returns: 添加了监听器的视图
    func onDBSynced(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .dbSynced), perform: action)
    }

    /// 监听数据库同步开始事件
    /// - Parameter action: 同步开始时执行的操作
    /// - Returns: 添加了监听器的视图
    func onDBSyncing(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .dbSyncing), perform: action)
    }

    /// 监听数据库更新事件
    /// - Parameter action: 数据库更新时执行的操作
    /// - Returns: 添加了监听器的视图
    func onDBUpdated(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .dbUpdated), perform: action)
    }

    /// 监听音频列表更新事件
    /// - Parameter action: 音频列表更新时执行的操作
    /// - Returns: 添加了监听器的视图
    func onAudiosUpdated(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .AudiosUpdatedNotification)) { _ in
            action()
        }
    }

    /// 监听单个音频更新事件
    /// - Parameter action: 单个音频更新时执行的操作
    /// - Returns: 添加了监听器的视图
    func onAudioUpdated(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .AudioUpdatedNotification)) { _ in
            action()
        }
    }

    /// 监听数据库删除事件
    /// - Parameter action: 数据库删除时执行的操作
    /// - Returns: 添加了监听器的视图
    func onDBDeleted(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .dbDeleted), perform: action)
    }

    /// 监听文件复制事件
    /// - Parameter action: 文件复制时执行的操作
    /// - Returns: 添加了监听器的视图
    func onCopyFiles(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .CopyFiles), perform: action)
    }

    /// 监听数据库排序开始事件
    /// - Parameter action: 数据库排序开始时执行的操作
    /// - Returns: 添加了监听器的视图
    func onDBSorting(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .DBSorting), perform: action)
    }

    /// 监听数据库排序完成事件
    /// - Parameter action: 数据库排序完成时执行的操作
    /// - Returns: 添加了监听器的视图
    func onDBSortDone(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .DBSortDone), perform: action)
    }

    /// 监听音频下载进度事件
    /// - Parameter action: 音频下载进度更新时执行的操作
    /// - Returns: 添加了监听器的视图
    func onAudioDownloadProgress(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .audioDownloadProgress)) { _ in
            action()
        }
    }

    /// 监听音频下载进度事件（带进度信息）
    /// - Parameter action: 接收进度信息的操作，参数为 (url: URL, progress: Double)
    /// - Returns: 添加了监听器的视图
    func onAudioDownloadProgress(perform action: @escaping (URL, Double) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .audioDownloadProgress)) { notification in
            guard
                let eventURL = notification.userInfo?["url"] as? URL,
                let progress = notification.userInfo?["progress"] as? Double
            else { return }

            action(eventURL, progress)
        }
    }

    /// 监听文件系统同步完成事件
    /// - Parameter action: 文件系统同步完成时执行的操作
    /// - Returns: 添加了监听器的视图
    func onFileSystemSynced(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .fileSystemSynced)) { _ in
            action()
        }
    }

    /// 监听文件系统删除完成事件
    /// - Parameter action: 文件系统删除完成时执行的操作
    /// - Returns: 添加了监听器的视图
    func onFileSystemDeleted(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .fileSystemDeleted)) { _ in
            action()
        }
    }
}

/// NotificationCenter 扩展，提供便捷的音频事件发送方法
extension NotificationCenter {
    /// 发送数据库同步开始事件
    static func postDBSyncing() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dbSyncing, object: nil)
        }
    }

    /// 发送数据库同步完成事件
    static func postDBSynced() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dbSynced, object: nil)
        }
    }

    /// 发送数据库更新完成事件
    static func postDBUpdated() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dbUpdated, object: nil)
        }
    }

    /// 发送文件系统同步完成事件
    static func postFileSystemSynced() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .fileSystemSynced, object: nil)
        }
    }

    /// 发送文件系统删除完成事件
    static func postFileSystemDeleted() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .fileSystemDeleted, object: nil)
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
