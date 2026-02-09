import Foundation
import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    /// iCloud账户状态变化通知（登录/登出iCloud账户）
    static let cloudAccountStateChanged = NSUbiquitousKeyValueStore.didChangeExternallyNotification
}

// MARK: - NotificationCenter Extensions

/// NotificationCenter 扩展，提供便捷的云服务事件发送方法
extension NotificationCenter {
    /// 发送iCloud账户状态变化事件
    static func postCloudAccountStateChanged() {
        NotificationCenter.default.post(name: .cloudAccountStateChanged, object: nil)
    }
}

// MARK: - View Extensions

/// SwiftUI View 扩展，提供便捷的云服务事件监听
extension View {
    /// 监听iCloud账户状态变化
    /// 当用户登录或登出iCloud账户时触发
    /// - Parameter action: iCloud账户状态变化时执行的操作，接收Notification参数
    func onCloudAccountStateChanged(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .cloudAccountStateChanged)) { notification in
            action(notification)
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
