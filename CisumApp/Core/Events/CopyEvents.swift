import Foundation
import SwiftUI

/// 文件复制插件的所有通知名称
extension Notification.Name {
    // MARK: - 复制任务状态相关

    /// 复制任务数量变化通知
    /// userInfo: ["count": Int]
    static let copyTaskCountChanged = Notification.Name("copyTaskCountChanged")

    /// 复制任务开始通知
    /// userInfo: ["count": Int]
    static let copyTaskStarted = Notification.Name("copyTaskStarted")

    /// 复制任务完成通知
    /// userInfo: ["count": Int, "lastCount": Int]
    static let copyTaskFinished = Notification.Name("copyTaskFinished")
}

// MARK: - View Extensions

/// SwiftUI View 扩展，提供便捷的复制任务事件监听
extension View {
    /// 监听复制任务数量变化事件
    /// - Parameter action: 任务数量变化时执行的操作，参数为当前任务数量
    /// - Returns: 添加了监听器的视图
    func onCopyTaskCountChanged(perform action: @escaping (Int) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .copyTaskCountChanged)) { notification in
            guard let count = notification.userInfo?["count"] as? Int else { return }
            action(count)
        }
    }

    /// 监听复制任务开始事件
    /// - Parameter action: 任务开始时执行的操作，参数为任务数量
    /// - Returns: 添加了监听器的视图
    func onCopyTaskStarted(perform action: @escaping (Int) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .copyTaskStarted)) { notification in
            guard let count = notification.userInfo?["count"] as? Int else { return }
            action(count)
        }
    }

    /// 监听复制任务完成事件
    /// - Parameter action: 任务完成时执行的操作，参数为完成的任务数量
    /// - Returns: 添加了监听器的视图
    func onCopyTaskFinished(perform action: @escaping (Int) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .copyTaskFinished)) { notification in
            guard let lastCount = notification.userInfo?["lastCount"] as? Int else { return }
            action(lastCount)
        }
    }
}

// MARK: - NotificationCenter Extensions

/// NotificationCenter 扩展，提供便捷的复制任务事件发送方法
extension NotificationCenter {
    /// 发送复制任务数量变化事件
    /// - Parameter count: 当前任务数量
    static func postCopyTaskCountChanged(count: Int) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .copyTaskCountChanged, object: nil, userInfo: ["count": count])
        }
    }

    /// 发送复制任务开始事件
    /// - Parameter count: 任务数量
    static func postCopyTaskStarted(count: Int) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .copyTaskStarted, object: nil, userInfo: ["count": count])
        }
    }

    /// 发送复制任务完成事件
    /// - Parameters:
    ///   - count: 完成后的任务数量（通常为 0）
    ///   - lastCount: 完成前的任务数量
    static func postCopyTaskFinished(count: Int, lastCount: Int) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .copyTaskFinished, object: nil, userInfo: ["count": count, "lastCount": lastCount])
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
