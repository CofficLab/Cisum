import Combine
import Foundation
import SwiftUI
import CisumUIComponents
import LumiUI
import MagicKit

/// 播放时间更新事件
/// 当播放进度发生变化时触发
extension Notification.Name {
    /// 播放时间更新通知名称
    public static let playManTimeUpdate = Notification.Name("PlayManTimeUpdate")
}

@MainActor
extension MagicPlayMan {
    /// 发送时间更新通知
    /// - Parameters:
    ///   - currentTime: 当前播放时间
    ///   - progress: 播放进度 (0-1)
    func sendTimeUpdate(currentTime: TimeInterval, progress: Double) {
        let userInfo: [String: Any] = [
            "currentTime": MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(currentTime),
            "progress": MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(progress),
        ]

        NotificationCenter.default.post(
            name: .playManTimeUpdate,
            object: self,
            userInfo: userInfo
        )
    }
}

enum MagicPlayManTimeUpdatePolicy {
    static func normalizedPayload(from userInfo: [AnyHashable: Any]?) -> (TimeInterval, Double)? {
        guard let currentTime = userInfo?["currentTime"] as? TimeInterval,
              let progress = userInfo?["progress"] as? Double else {
            return nil
        }

        return (
            MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(currentTime),
            MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(progress)
        )
    }
}

extension NotificationCenter {
    /// 监听 PlayMan 时间更新通知
    /// - Parameters:
    ///   - object: PlayMan 实例
    ///   - handler: 处理闭包，参数为 (currentTime: TimeInterval, progress: Double)
    /// - Returns: 观察者令牌
    func observePlayManTimeUpdate(
        for object: MagicPlayMan? = nil,
        handler: @escaping (TimeInterval, Double) -> Void
    ) -> AnyCancellable {
        publisher(for: .playManTimeUpdate, object: object)
            .compactMap { MagicPlayManTimeUpdatePolicy.normalizedPayload(from: $0.userInfo) }
            .sink(receiveValue: handler)
    }
}

@available(iOS 14.0, macOS 11.0, *)
public extension View {
    /// 监听播放时间更新通知
    /// - Parameter handler: 处理闭包，参数为 (currentTime: TimeInterval, progress: Double)
    /// - Returns: 支持链式调用的View
    func onPlayManTimeUpdate(
        _ handler: @escaping (TimeInterval, Double) -> Void
    ) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: .playManTimeUpdate),
            perform: { notification in
                if let (currentTime, progress) = MagicPlayManTimeUpdatePolicy.normalizedPayload(from: notification.userInfo) {
                    handler(currentTime, progress)
                }
            }
        )
    }
}
