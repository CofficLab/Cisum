import Combine
import Foundation
import SwiftUI
import CisumUIComponents
import LumiUI
import MagicKit

/// 播放时长变更事件
/// 当媒体总时长发生变化时触发
extension Notification.Name {
    /// 播放时长变更通知名称
    public static let playManDurationChanged = Notification.Name("PlayManDurationChanged")
}

@MainActor
extension MagicPlayMan {
    /// 发送时长变更通知
    /// - Parameter duration: 媒体总时长
    func sendDurationChanged(duration: TimeInterval) {
        let userInfo: [String: Any] = [
            "duration": MagicPlayManPlaybackTimePolicy.normalizedDuration(duration),
        ]

        NotificationCenter.default.post(
            name: .playManDurationChanged,
            object: self,
            userInfo: userInfo
        )
    }
}

extension NotificationCenter {
    /// 监听 PlayMan 时长变更通知
    /// - Parameters:
    ///   - object: PlayMan 实例
    ///   - handler: 处理闭包，参数为 duration: TimeInterval
    /// - Returns: 观察者令牌
    func observePlayManDurationChanged(
        for object: MagicPlayMan? = nil,
        handler: @escaping (TimeInterval) -> Void
    ) -> AnyCancellable {
        publisher(for: .playManDurationChanged, object: object)
            .map { notification -> TimeInterval in
                MagicPlayManPlaybackTimePolicy.normalizedDuration(
                    notification.userInfo?["duration"] as? TimeInterval ?? 0
                )
            }
            .sink(receiveValue: handler)
    }
}

@available(iOS 14.0, macOS 11.0, *)
public extension View {
    /// 监听播放时长变更通知
    /// - Parameter handler: 处理闭包，参数为 duration: TimeInterval
    /// - Returns: 支持链式调用的View
    func onPlayManDurationChanged(
        _ handler: @escaping (TimeInterval) -> Void
    ) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: .playManDurationChanged),
            perform: { notification in
                let duration = MagicPlayManPlaybackTimePolicy.normalizedDuration(
                    notification.userInfo?["duration"] as? TimeInterval ?? 0
                )
                handler(duration)
            }
        )
    }
}
