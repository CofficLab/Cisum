import Combine
import Foundation
import SwiftUI
import CisumUIComponents
import LumiUI
import MagicKit

/// 下载进度变更事件
/// 当媒体下载进度发生变化时触发
extension Notification.Name {
    /// 下载进度变更通知名称
    public static let playManDownloadProgressChanged = Notification.Name("PlayManDownloadProgressChanged")
}

@MainActor
extension MagicPlayMan {
    /// 发送下载进度变更通知
    /// - Parameter progress: 下载进度 (0-1)
    func sendDownloadProgressChanged(progress: Double) {
        let userInfo: [String: Any] = [
            "downloadProgress": MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(progress),
        ]

        NotificationCenter.default.post(
            name: .playManDownloadProgressChanged,
            object: self,
            userInfo: userInfo
        )
    }
}

@available(iOS 14.0, macOS 11.0, *)
public extension View {
    /// 监听下载进度变更通知
    /// - Parameter handler: 处理闭包，参数为 progress: Double (0-1)
    /// - Returns: 支持链式调用的View
    func onPlayManDownloadProgressChanged(
        _ handler: @escaping (Double) -> Void
    ) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: .playManDownloadProgressChanged),
            perform: { notification in
                let progress = MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(
                    notification.userInfo?["downloadProgress"] as? Double ?? 0
                )
                handler(progress)
            }
        )
    }
}
