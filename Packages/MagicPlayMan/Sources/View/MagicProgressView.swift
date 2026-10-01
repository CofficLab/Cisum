import MagicKit
import SwiftUI

/// 播放进度条视图
///
/// 这是一个自观察的进度条视图，会自动监听 MagicPlayMan 的播放进度状态变化。
/// 提供播放进度显示和拖动控制功能，支持实时进度更新和用户交互。
///
/// ## 特性
/// - 自动响应播放进度状态变化
/// - 实时显示当前播放位置和总时长
/// - 支持拖动进度条调整播放位置
/// - 智能时间格式化显示
/// - 集成 MagicProgressBar 组件
///
/// ## 使用示例
/// ```swift
/// ProgressView(man: playMan)
/// ```
///
/// - Parameter man: MagicPlayMan 实例，用于监听播放进度状态和触发进度控制
struct MagicPlayProgressView: View, SuperLog {
    @ObservedObject var man: MagicPlayMan

    var body: some View {
        MagicProgressBar(
            currentTime: .init(
                get: { man.currentTime },
                set: { time in
                    man.seek(time: time, reason: self.className)
                }
            ),
            duration: man.duration,
            onSeek: { time in
                man.seek(time: time, reason: self.className)
            }
        )
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
        .frame(height: 600)
}
