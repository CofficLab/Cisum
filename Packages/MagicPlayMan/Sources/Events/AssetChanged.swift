import Combine
import Foundation
import SwiftUI
import CisumUIComponents
import LumiUI
import MagicKit

/// 播放资源变更事件
/// 当播放的资源发生变化时触发
extension Notification.Name {
    /// 播放资源变更通知名称
    public static let playManAssetChanged = Notification.Name("PlayManAssetChanged")
}

@MainActor
extension MagicPlayMan {
    /// 发送播放资源变更通知
    /// - Parameter asset: 当前播放资源URL
    func sendAssetChanged(asset: URL?) {
        let userInfo: [String: Any] = [
            "asset": asset as Any,
        ]

        NotificationCenter.default.post(
            name: .playManAssetChanged,
            object: self,
            userInfo: userInfo
        )
    }
}

extension NotificationCenter {
    /// 监听 PlayMan 播放资源变更通知
    /// - Parameters:
    ///   - object: PlayMan 实例
    ///   - handler: 处理闭包，参数为 asset: URL?
    /// - Returns: 观察者令牌
    func observePlayManAssetChanged(
        for object: MagicPlayMan? = nil,
        handler: @escaping (URL?) -> Void
    ) -> AnyCancellable {
        publisher(for: .playManAssetChanged, object: object)
            .map { notification -> URL? in
                notification.userInfo?["asset"] as? URL
            }
            .sink(receiveValue: handler)
    }
}

@available(iOS 14.0, macOS 11.0, *)
public extension View {
    /// 监听播放资源变更通知
    /// - Parameter handler: 处理闭包，参数为 asset: URL?
    /// - Returns: 支持链式调用的View
    func onPlayManAssetChanged(
        _ handler: @escaping (URL?) -> Void
    ) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: .playManAssetChanged),
            perform: { notification in
                let asset = notification.userInfo?["asset"] as? URL
                handler(asset)
            }
        )
    }
}

