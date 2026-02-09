import Foundation
import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    /// 存储位置更新通知
    static let storageLocationUpdated = Notification.Name("storageLocationUpdated")

    /// 存储位置重置通知
    static let storageLocationDidReset = Notification.Name("storageLocationDidReset")
}

// MARK: - NotificationCenter Extensions

/// NotificationCenter 扩展，提供便捷的存储事件发送方法
extension NotificationCenter {
    /// 发送存储位置更新事件
    static func postStorageLocationUpdated() {
        NotificationCenter.default.post(name: .storageLocationUpdated, object: nil)
    }

    /// 发送存储位置重置事件
    static func postStorageLocationDidReset() {
        NotificationCenter.default.post(name: .storageLocationDidReset, object: nil)
    }
}

// MARK: - View Extensions

/// SwiftUI View 扩展，提供便捷的存储相关事件监听
extension View {
    /// 监听存储位置变化
    /// - Parameter action: 当存储位置更新时执行的操作
    func onStorageLocationChanged(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .storageLocationUpdated)) { _ in
            action()
        }
    }

    /// 监听存储位置重置事件
    /// - Parameter action: 当存储位置重置时执行的操作
    func onStorageLocationDidReset(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .storageLocationDidReset)) { _ in
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
