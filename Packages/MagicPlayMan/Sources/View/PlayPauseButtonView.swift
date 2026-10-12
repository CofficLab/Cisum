import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

/// 播放/暂停按钮视图
///
/// 这是一个自观察的按钮视图，会自动监听 MagicPlayMan 的播放状态变化。
/// 根据当前状态显示播放图标或暂停图标，并自动更新禁用状态。
///
/// ## 特性
/// - 自动响应播放状态变化
/// - 智能禁用状态管理
/// - 支持自定义按钮尺寸
///
/// ## 使用示例
/// ```swift
/// PlayPauseButtonView(man: playMan, size: 28)
/// ```
///
/// - Parameters:
///   - man: MagicPlayMan 实例，用于监听播放状态和触发播放控制
///   - size: 按钮尺寸，默认为 28
struct PlayPauseButtonView: View, SuperLog {
    // 精简订阅：只订阅按钮所需的状态，避免不相关变化触发刷新
    @ObservedObject var man: MagicPlayMan
    let size: CGFloat
    @Environment(\.localization) private var loc

    private var disabledReason: String? {
        if !man.hasAsset || man.state.isDownloading || man.state.isLoading {
            return man.state.localizedStateText(localization: loc)
        }
        return nil
    }

    var body: some View {
        Button(action: {
            man.toggle(reason: self.className)
        }) {
            Image(systemName: man.state == .playing ? PlaybackSymbol.pauseFill : PlaybackSymbol.playFill)
                .frame(width: size, height: size)
        }
        .disabled(disabledReason != nil)
        .buttonStyle(.borderless)
        .accessibilityLabel(man.state == .playing ? loc.pause : loc.play)
        .help(disabledReason ?? (man.state == .playing ? loc.pause : loc.play))
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
        .frame(height: 600)
}
