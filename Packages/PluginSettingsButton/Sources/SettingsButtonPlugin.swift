import ProviderDocsView
import LumiUI
import KernelCore
import ProviderPlugin
import ProviderSettingView
import ProviderToolbar
import KitAppEvents
import MagicKit
import SwiftUI

/// 在窗口右上角提供「设置」按钮的插件。
///
/// - macOS：通过 `SuperPlugin.addToolBarButtons()` 把按钮贡献到主窗口工具栏，
///   点击后用 SwiftUI `openWindow` 打开设置窗口 —— 与菜单栏「设置…」（⌘,）
///   共用同一窗口入口。
/// - iOS：没有独立的设置窗口 Scene，改由 `IOSNavigationBarProviding` 贡献
///   一颗导航栏齿轮；点击后广播 `SettingViewNavigation.openSettingsNotification`，
///   由宿主（`IOSSettingsAppShell`）以 sheet 形式呈现设置页。
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
        #if os(iOS)
        kernel.resolveProvider((any IOSNavigationBarProviding).self)?
            .removeNavigationBarItems(ids: [SettingsButtonPluginInfo.navigationBarItemId])
        #endif
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        #if os(macOS)
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            contrib.addToolBarButtons(ownerPluginID: id, self.addToolBarButtons())
        }
        #elseif os(iOS)
        if let navigationBar = kernel.resolveProvider((any IOSNavigationBarProviding).self) {
            navigationBar.addNavigationBarItems([makeNavigationBarItem()])
        }
        #endif
    }

    #if os(macOS)
    @MainActor
    public func addToolBarButtons() -> [(id: String, view: AnyView)] {
        [(id: SettingsButtonPluginInfo.toolbarItemId, view: AnyView(SettingsButtonView()))]
    }
    #endif

    #if os(iOS)
    /// iOS 导航栏齿轮项。
    ///
    /// 挂在 `trailing` 位、order 靠后，保证它出现在导航栏右侧且不抢其他
    /// 贡献项的位置（对齐 BookletMaker 的 `SettingsToolbarPlugin`）。
    @MainActor
    public func makeNavigationBarItem() -> IOSNavigationBarItem {
        IOSNavigationBarItem(
            id: SettingsButtonPluginInfo.navigationBarItemId,
            title: String(localized: "Settings", bundle: .module),
            placement: .trailing,
            category: .global,
            ownerPluginID: id,
            order: 300
        ) {
            Button {
                NotificationCenter.default.post(
                    name: SettingViewNavigation.openSettingsNotification,
                    object: nil
                )
            } label: {
                Image(systemName: SettingsButtonPluginInfo.iconName)
            }
            .accessibilityLabel(String(localized: "Settings", bundle: .module))
            .accessibilityIdentifier("cisum.settings.button")
        }
    }
    #endif
}
