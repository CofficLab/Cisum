import Combine
import Foundation
import SwiftUI
import CisumUIComponents
import LumiUI
import MagicKit

/// 缓冲状态变更事件
/// 当播放缓冲状态发生变化时触发
extension Notification.Name {
    /// 缓冲状态变更通知名称
    public static let playManBufferingStateChanged = Notification.Name("PlayManBufferingStateChanged")
}

@MainActor
extension MagicPlayMan {
    /// 发送缓冲状态变更通知
    /// - Parameter isBuffering: 是否正在缓冲
    func sendBufferingStateChanged(isBuffering: Bool) {
        let userInfo: [String: Any] = [
            "isBuffering": isBuffering,
        ]

        NotificationCenter.default.post(
            name: .playManBufferingStateChanged,
            object: self,
            userInfo: userInfo
        )
    }
}

@available(iOS 14.0, macOS 11.0, *)
public extension View {
    /// 监听缓冲状态变更通知
    /// - Parameter handler: 处理闭包，参数为 isBuffering: Bool
    /// - Returns: 支持链式调用的View
    func onPlayManBufferingStateChanged(
        _ handler: @escaping (Bool) -> Void
    ) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: .playManBufferingStateChanged),
            perform: { notification in
                let isBuffering = notification.userInfo?["isBuffering"] as? Bool ?? false
                handler(isBuffering)
            }
        )
    }
}

