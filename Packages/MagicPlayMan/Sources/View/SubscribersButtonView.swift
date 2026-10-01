import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

/// 订阅者按钮视图
///
/// 这是一个自观察的按钮视图，会自动监听 MagicPlayMan 的订阅者状态变化。
/// 提供订阅者列表查看功能，通过弹窗展示当前注册的事件订阅者信息。
///
/// ## 特性
/// - 自动响应订阅者状态变化
/// - 弹窗式订阅者列表展示
/// - 支持自定义按钮尺寸
/// - 集成订阅者管理视图
///
/// ## 使用示例
/// ```swift
/// SubscribersButtonView(man: playMan, size: 28)
/// ```
///
/// - Parameters:
///   - man: MagicPlayMan 实例，用于监听订阅者状态和获取订阅者视图
///   - size: 按钮尺寸，默认为 28
struct SubscribersButtonView: View {
    @ObservedObject var man: MagicPlayMan
    let size: CGFloat

    @State private var isShowingPopover = false
    @Environment(\.localization) private var loc

    var body: some View {
        Button(action: { isShowingPopover.toggle() }) {
            Image(systemName: PlaybackSymbol.personGroup)
                .frame(width: size, height: size)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(loc.showEventSubscribers)
        .help(loc.showEventSubscribers)
        .popover(isPresented: $isShowingPopover) {
            man.makeSubscribersView()
                .frame(width: 400, height: 300)
        }
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
        .frame(height: 600)
}
