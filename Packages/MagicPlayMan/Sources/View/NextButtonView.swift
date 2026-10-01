import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

/// 下一曲按钮视图
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
/// NextButtonView(man: playMan, size: 28)
/// ```
///
/// - Parameters:
///   - man: MagicPlayMan 实例，用于监听状态和触发下一曲操作
///   - size: 按钮尺寸，默认为 28
struct NextButtonView: View {
    @ObservedObject var man: MagicPlayMan
    let size: CGFloat

    @Environment(\.localization) private var loc

    /// 计算按钮是否应该禁用
    var disabledReason: String? {
        if !man.hasAsset {
            return loc.noMediaLoaded
        } else if !man.events.hasNavigationSubscribers {
            return "No navigation handler registered"
        }
        return nil
    }

    var body: some View {
        Button(action: man.next) {
            Image(systemName: PlaybackSymbol.forwardEndFill)
                .frame(width: size, height: size)
        }
        .buttonStyle(.borderless)
        .disabled(disabledReason != nil)
        .accessibilityLabel(loc.nextTrack)
        .help(disabledReason ?? loc.nextTrack)
    }
}

// MARK: - Preview

#Preview("PreviousButton") {
    MagicPlayMan(locale: .current)
        .makeNextButtonView()
        .frame(height: 500)
        .frame(width: 500)
}

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
        .frame(height: 600)
}
