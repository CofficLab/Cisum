import Foundation
import SwiftUI

/// SwiftUI View 扩展，提供便捷的音频喜欢状态事件监听
extension View {
    /// 监听音频喜欢状态变化事件
    /// - Parameter action: 音频喜欢状态变化时执行的操作，参数为 (audioId: String, url: URL?, liked: Bool)
    /// - Returns: 添加了监听器的视图
    func onAudioLikeStatusChanged(perform action: @escaping (String, URL?, Bool) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .AudioLikeStatusChanged)) { notification in
            guard let userInfo = notification.userInfo,
                  let audioId = userInfo["audioId"] as? String,
                  let liked = userInfo["liked"] as? Bool else { return }

            let url = userInfo["url"] as? URL
            action(audioId, url, liked)
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
