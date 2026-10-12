import Combine
import Foundation
import SwiftUI
import CisumUIComponents
import LumiUI
import MagicKit

/// 播放状态变更事件
/// 当播放/暂停状态发生变化时触发
extension Notification.Name {
    /// 播放状态变更通知名称
    public static let playManStateChanged = Notification.Name("PlayManStateChanged")
}

@MainActor
extension MagicPlayMan {
    /// 发送播放状态变更通知
    /// - Parameter isPlaying: 是否正在播放
    func sendStateChanged(isPlaying: Bool) {
        let userInfo: [String: Any] = [
            "isPlaying": isPlaying,
        ]

        NotificationCenter.default.post(
            name: .playManStateChanged,
            object: self,
            userInfo: userInfo
        )
    }
}

extension NotificationCenter {
    /// 监听 PlayMan 播放状态变更通知
    /// - Parameters:
    ///   - object: PlayMan 实例
    ///   - handler: 处理闭包，参数为 isPlaying: Bool
    /// - Returns: 观察者令牌
    func observePlayManStateChanged(
        for object: MagicPlayMan? = nil,
        handler: @escaping (Bool) -> Void
    ) -> AnyCancellable {
        publisher(for: .playManStateChanged, object: object)
            .map { notification -> Bool in
                notification.userInfo?["isPlaying"] as? Bool ?? false
            }
            .sink(receiveValue: handler)
    }
}

@available(iOS 14.0, macOS 11.0, *)
public extension View {
    /// 监听播放状态变更通知
    /// - Parameter handler: 处理闭包，参数为 isPlaying: Bool
    /// - Returns: 支持链式调用的View
    func onPlayManStateChanged(
        _ handler: @escaping (Bool) -> Void
    ) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: .playManStateChanged),
            perform: { notification in
                let isPlaying = notification.userInfo?["isPlaying"] as? Bool ?? false
                handler(isPlaying)
            }
        )
    }
}

