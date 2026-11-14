import Foundation

private struct SuperEventNotificationPayload: @unchecked Sendable {
    let name: Notification.Name
    let object: Any?
    let userInfo: [AnyHashable: Any]?
}

/// 提供简化的通知中心事件发送功能的协议
///
/// `SuperEvent` 协议为通知中心（NotificationCenter）提供了便捷的访问方式和事件发送功能。
/// 通过实现此协议，可以更简单地在应用程序中发送通知。
///
/// ## 使用示例:
/// ```swift
/// class MessageHandler: SuperEvent {
///     func sendMessage(_ message: String) {
///         // 在主线程发送通知
///         emit(.newMessage, object: nil, userInfo: ["message": message])
///     }
/// }
///
/// // 监听通知
/// NotificationCenter.default.addObserver(forName: .newMessage, object: nil, queue: .main) { notification in
///     if let message = notification.userInfo?["message"] as? String {
///         print("收到新消息：\(message)")
///     }
/// }
/// ```
@preconcurrency
public protocol SuperEvent {
}

public extension SuperEvent {
    /// 获取默认通知中心实例（完整名称）
    var notification: NotificationCenter {
        NotificationCenter.default
    }

    /// 获取默认通知中心实例（简写）
    var nc: NotificationCenter { NotificationCenter.default }

    /// 在主线程异步发送通知
    /// - Parameters:
    ///   - name: 通知名称
    ///   - object: 发送通知的对象（可选）
    ///   - userInfo: 随通知一起发送的用户信息字典（可选）
    nonisolated func emit(_ name: Notification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        let nc = self.nc
        if Thread.isMainThread {
            nc.post(name: name, object: object, userInfo: userInfo)
        } else {
            let payload = SuperEventNotificationPayload(name: name, object: object, userInfo: userInfo)
            DispatchQueue.main.async {
                nc.post(name: payload.name, object: payload.object, userInfo: payload.userInfo)
            }
        }
    }

    /// 在主线程异步发送通知（命名参数版本）
    /// - Parameters:
    ///   - name: 通知名称
    ///   - object: 发送通知的对象（可选）
    ///   - userInfo: 随通知一起发送的用户信息字典（可选）
    nonisolated func emit(name: Notification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        self.emit(name, object: object, userInfo: userInfo)
    }
}
