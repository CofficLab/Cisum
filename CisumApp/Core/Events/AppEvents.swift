import Foundation
import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    /// 引导完成（应用引导/设置流程完成）
    static let guideDone = Notification.Name("guideDone")

    /// 应用将要隐藏
    static let applicationWillHide = Notification.Name("applicationWillHide")

    /// 应用已隐藏
    static let applicationDidHide = Notification.Name("applicationDidHide")

    /// 应用将要变为活动状态
    static let applicationWillBecomeActive = Notification.Name("applicationWillBecomeActive")

    /// 应用启动完成
    static let applicationDidFinishLaunching = Notification.Name("applicationDidFinishLaunching")

    /// 应用将要终止
    static let applicationWillTerminate = Notification.Name("applicationWillTerminate")

    /// 应用将要更新
    static let applicationWillUpdate = Notification.Name("applicationWillUpdate")

    /// 应用已成为活动状态
    static let applicationDidBecomeActive = Notification.Name("applicationDidBecomeActive")

    /// 应用将要失去活动状态
    static let applicationWillResignActive = Notification.Name("applicationWillResignActive")

    /// 应用已失去活动状态
    static let applicationDidResignActive = Notification.Name("applicationDidResignActive")

    /// 窗口已移动
    static let windowDidMove = Notification.Name("windowDidMove")

    /// 窗口已调整大小
    static let windowDidResize = Notification.Name("windowDidResize")
}

// MARK: - NotificationCenter Extensions

/// NotificationCenter 扩展，提供便捷的事件发送方法
extension NotificationCenter {
    /// 发送引导完成事件
    static func postGuideDone() {
        NotificationCenter.default.post(name: .guideDone, object: nil)
    }

    /// 发送应用将要隐藏事件
    static func postApplicationWillHide() {
        NotificationCenter.default.post(name: .applicationWillHide, object: nil)
    }

    /// 发送应用已隐藏事件
    static func postApplicationDidHide() {
        NotificationCenter.default.post(name: .applicationDidHide, object: nil)
    }

    /// 发送应用将要变为活动状态事件
    static func postApplicationWillBecomeActive() {
        NotificationCenter.default.post(name: .applicationWillBecomeActive, object: nil)
    }

    /// 发送应用启动完成事件
    static func postApplicationDidFinishLaunching() {
        NotificationCenter.default.post(name: .applicationDidFinishLaunching, object: nil)
    }

    /// 发送应用将要终止事件
    static func postApplicationWillTerminate() {
        NotificationCenter.default.post(name: .applicationWillTerminate, object: nil)
    }

    /// 发送应用将要更新事件
    static func postApplicationWillUpdate() {
        NotificationCenter.default.post(name: .applicationWillUpdate, object: nil)
    }

    /// 发送应用已成为活动状态事件
    static func postApplicationDidBecomeActive() {
        NotificationCenter.default.post(name: .applicationDidBecomeActive, object: nil)
    }

    /// 发送应用将要失去活动状态事件
    static func postApplicationWillResignActive() {
        NotificationCenter.default.post(name: .applicationWillResignActive, object: nil)
    }

    /// 发送应用已失去活动状态事件
    static func postApplicationDidResignActive() {
        NotificationCenter.default.post(name: .applicationDidResignActive, object: nil)
    }

    /// 发送窗口移动事件
    static func postWindowDidMove() {
        NotificationCenter.default.post(name: .windowDidMove, object: nil)
    }

    /// 发送窗口调整大小事件
    static func postWindowDidResize() {
        NotificationCenter.default.post(name: .windowDidResize, object: nil)
    }
}

// MARK: - View Extensions

/// SwiftUI View 扩展，提供便捷的应用生命周期事件监听
extension View {
    /// 监听引导完成事件
    /// - Parameter action: 引导完成时执行的操作
    /// - Returns: 添加了监听器的视图
    func onGuideDone(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .guideDone)) { _ in
            action()
        }
    }

    /// 监听应用将要隐藏事件
    /// - Parameter action: 应用将要隐藏时执行的操作
    /// - Returns: 添加了监听器的视图
    func onApplicationWillHide(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationWillHide)) { _ in
            action()
        }
    }

    /// 监听应用已隐藏事件
    /// - Parameter action: 应用已隐藏时执行的操作
    /// - Returns: 添加了监听器的视图
    func onApplicationDidHide(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationDidHide)) { _ in
            action()
        }
    }

    /// 监听应用将要变为活动状态事件
    /// - Parameter action: 应用将要变为活动状态时执行的操作
    /// - Returns: 添加了监听器的视图
    func onApplicationWillBecomeActive(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationWillBecomeActive)) { _ in
            action()
        }
    }

    /// 监听应用已成为活动状态事件
    /// - Parameter action: 应用已成为活动状态时执行的操作
    /// - Returns: 添加了监听器的视图
    func onApplicationDidBecomeActive(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationDidBecomeActive)) { _ in
            action()
        }
    }

    /// 监听应用将要终止事件
    /// - Parameter action: 应用将要终止时执行的操作
    /// - Returns: 添加了监听器的视图
    func onApplicationWillTerminate(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationWillTerminate)) { _ in
            action()
        }
    }

    /// 监听应用将要更新事件
    /// - Parameter action: 应用将要更新时执行的操作
    /// - Returns: 添加了监听器的视图
    func onApplicationWillUpdate(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationWillUpdate)) { _ in
            action()
        }
    }

    /// 监听应用将要失去活动状态事件
    /// - Parameter action: 应用将要失去活动状态时执行的操作
    /// - Returns: 添加了监听器的视图
    func onApplicationWillResignActive(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationWillResignActive)) { _ in
            action()
        }
    }

    /// 监听应用已失去活动状态事件
    /// - Parameter action: 应用已失去活动状态时执行的操作
    /// - Returns: 添加了监听器的视图
    func onApplicationDidResignActive(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationDidResignActive)) { _ in
            action()
        }
    }

    /// 监听窗口移动事件
    /// - Parameter action: 窗口移动时执行的操作
    /// - Returns: 添加了监听器的视图
    func onWindowDidMove(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .windowDidMove)) { _ in
            action()
        }
    }

    /// 监听窗口调整大小事件
    /// - Parameter action: 窗口调整大小时执行的操作
    /// - Returns: 添加了监听器的视图
    func onWindowDidResize(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .windowDidResize)) { _ in
            action()
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
