import CisumUIComponents
import CisumKernel
import MagicKit
import ProviderDocsView
import SwiftUI

/// 在窗口右上角（工具栏 trailing）提供「设置」按钮的插件（macOS）。
///
/// 通过 `SuperPlugin.addToolBarButtons()` 把按钮贡献到主窗口工具栏，
/// 点击后用 SwiftUI `openWindow` 打开设置窗口 —— 与菜单栏「设置…」（⌘,）
/// 共用同一窗口入口。
public actor SettingsButtonPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = SettingsButtonPlugin()
    public static let metadata = PluginMetadata(
        displayName: String(localized: "Settings", bundle: .module),
        description: SettingsButtonPluginInfo.description,
        iconName: SettingsButtonPluginInfo.iconName,
        policy: .alwaysOn,
        category: .settings,
    )

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { SettingsButtonPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { SettingsButtonPluginManualView() })
        }
    }

    #if os(macOS)
    @MainActor
    public func addToolBarButtons() -> [(id: String, view: AnyView)] {
        [(id: SettingsButtonPluginInfo.toolbarItemId, view: AnyView(SettingsButtonView()))]
    }
    #endif
}
