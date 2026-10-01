import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

/// 快进按钮视图
///
/// 这是一个自观察的按钮视图，会自动监听 MagicPlayMan 的播放状态变化。
/// 提供快进功能，允许用户快速前进播放进度。
///
/// ## 特性
/// - 自动响应播放状态变化
/// - 智能禁用状态管理（无媒体、加载中等）
/// - 支持自定义按钮尺寸
/// - 默认快进 10 秒
///
/// ## 使用示例
/// ```swift
/// ForwardButtonView(man: playMan, size: 28)
/// ```
///
/// - Parameters:
///   - man: MagicPlayMan 实例，用于监听播放状态和触发快进操作
///   - size: 按钮尺寸，默认为 28
struct ForwardButtonView: View {
    @ObservedObject var man: MagicPlayMan
    let size: CGFloat

    @Environment(\.localization) private var loc

    var disabledReason: String? {
        if !man.hasAsset {
            return loc.noMediaLoaded
        } else if man.state.isLoading {
            return loc.loadingWithDots
        }
        return nil
    }

    var body: some View {
        Button(action: { man.skipForward() }) {
        Image(systemName: PlaybackSymbol.goForwardTen)
                .frame(width: size, height: size)
        }
        .disabled(disabledReason != nil)
        .buttonStyle(.borderless)
        .accessibilityLabel(loc.forwardTenSeconds)
        .help(disabledReason ?? loc.forwardTenSeconds)
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan
        .getPreviewView()
        .frame(height: 600)
}
