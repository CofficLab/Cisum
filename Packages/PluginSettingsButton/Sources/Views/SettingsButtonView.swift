// 系统工具栏会自动加样式，所以用原生 Button 最好，不要用自定义按钮组件。

import CisumUIComponents
import SwiftUI

/// 工具栏「设置」按钮：点击打开设置窗口。
///
/// 与菜单栏「设置…」（⌘,）共用同一个窗口入口（`openWindow(id:)`）。
/// 窗口已打开时再次点击会激活并前置该窗口。
public struct SettingsButtonView: View {
    @Environment(\.openWindow) private var openWindow

    nonisolated static let title = String(localized: "Settings", bundle: .module)

    public init() {}

    public var body: some View {
        Button {
            openWindow(id: SettingsButtonPluginInfo.settingsWindowID)
        } label: {
            Label(Self.title, systemImage: SettingsButtonPluginInfo.iconName)
        }
        .help(Text(String(localized: "Open Settings", bundle: .module)))
        .accessibilityLabel(Text(Self.title))
        .accessibilityIdentifier("cisum.settings.button")
    }
}
