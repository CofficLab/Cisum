import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

/// 播放模式按钮视图
///
/// 这是一个自观察的按钮视图，会自动监听 MagicPlayMan 的播放模式状态变化。
/// 根据当前播放模式显示相应的图标和样式，支持循环、随机等播放模式切换。
///
/// ## 特性
/// - 自动响应播放模式状态变化
/// - 动态图标和样式切换
/// - 支持自定义按钮尺寸
///
/// ## 使用示例
/// ```swift
/// PlayModeButtonView(man: playMan, size: 28)
/// ```
///
/// - Parameters:
///   - man: MagicPlayMan 实例，用于监听播放模式状态和触发模式切换
///   - size: 按钮尺寸，默认为 28
struct PlayModeButtonView: View {
    @ObservedObject var man: MagicPlayMan
    let size: CGFloat

    @Environment(\.localization) private var loc

    var body: some View {
        Button(action: man.togglePlayMode) {
            Image(systemName: man.playMode.iconName)
                .foregroundStyle(man.playMode != .sequence ? .primary : .secondary)
                .frame(width: size, height: size)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(modeDescription)
        .help(modeDescription)
    }

    private var modeDescription: String {
        switch man.playMode {
        case .sequence:
            return loc.sequentialPlay
        case .loop:
            return loc.singleTrackLoop
        case .shuffle:
            return loc.shufflePlay
        case .repeatAll:
            return loc.repeatAll
        }
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
        .frame(height: 600)
}
