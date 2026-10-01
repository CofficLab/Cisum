import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

/// 上一曲按钮视图
///
/// 这是一个自观察的按钮视图，会自动监听 MagicPlayMan 的状态变化。
/// 根据导航订阅者状态智能管理按钮的可用性。
///
/// ## 特性
/// - 自动响应状态变化
/// - 智能禁用状态管理（无媒体、无导航订阅者等）
/// - 支持自定义按钮尺寸
///
/// ## 使用示例
/// ```swift
/// PreviousButtonView(man: playMan, size: 28)
/// ```
///
/// - Parameters:
///   - man: MagicPlayMan 实例，用于监听状态和触发上一曲操作
///   - size: 按钮尺寸，默认为 28
struct PreviousButtonView: View {
    @ObservedObject var man: MagicPlayMan
    let size: CGFloat

    @Environment(\.localization) private var loc

    /// 计算按钮的禁用原因
    ///
    /// 根据当前状态返回相应的禁用提示信息：
    /// - 无媒体加载时：显示本地化的 "No media loaded"
    /// - 无导航订阅者时：显示相应提示
    var disabledReason: String? {
        if !man.hasAsset {
            return loc.noMediaLoaded
        } else if !man.events.hasNavigationSubscribers {
            return "No navigation handler registered"
        }
        return nil
    }

    var body: some View {
        Button(action: man.previous) {
        Image(systemName: PlaybackSymbol.backwardEndFill)
                .frame(width: size, height: size)
        }
        .disabled(disabledReason != nil)
        .buttonStyle(.borderless)
        .accessibilityLabel(loc.previousTrack)
        .help(disabledReason ?? loc.previousTrack)
    }
}

// MARK: - Preview

#Preview("PreviousButton") {
    MagicPlayMan(locale: .current)
        .makePreviousButtonView()
        .frame(height: 500)
        .frame(width: 500)
}

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
        .frame(height: 600)
}
