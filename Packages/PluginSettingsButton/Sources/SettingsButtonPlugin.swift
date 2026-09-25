import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import MagicKit
import SwiftUI

/// 在窗口右上角（工具栏 trailing）提供「设置」按钮的插件（macOS）。
///
/// 通过 `SuperPlugin.addToolBarButtons()` 把按钮贡献到主窗口工具栏，
/// 点击后用 SwiftUI `openWindow` 打开设置窗口 —— 与菜单栏「设置…」（⌘,）
/// 共用同一窗口入口。
@MainActor
public final class SettingsButtonPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: SettingsButtonPlugin.self)

    nonisolated static let verbose = false

    public static let shared = SettingsButtonPlugin()
    public let order = 9999
    public let iconName = SettingsButtonPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: SettingsButtonPlugin.self),
        name: String(localized: "Settings", bundle: .module),
        description: SettingsButtonPluginInfo.description,
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { SettingsButtonPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { SettingsButtonPluginManualView() })
        }
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            contrib.addToolBarButtons(self.addToolBarButtons())
        }
    }

    #if os(macOS)
    @MainActor
    public func addToolBarButtons() -> [(id: String, view: AnyView)] {
        [(id: SettingsButtonPluginInfo.toolbarItemId, view: AnyView(SettingsButtonView()))]
    }
    #endif
}