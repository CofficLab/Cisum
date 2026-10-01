#if os(macOS)
import FactoryCisum
import SwiftUI

/// macOS 应用入口：只做场景组装，窗口内容由 Factory 提供。
///
/// 主窗口与设置窗口共享同一内核（`FactoryCisum.createMainKernel` 幂等）。
struct CisumMacApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup(AppBootstrap.appName, id: AppBootstrap.mainWindowID) {
            FactoryCisum.makeMainWindow(configuration: CisumAppAssembly.configuration)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(
            width: AppBootstrap.defaultWindowSize.width,
            height: AppBootstrap.defaultWindowSize.height
        )
        .commands {
            // 命令装配集中在 Factory 包内（CisumAppCommands，含「设置…」⌘,）。
            FactoryCisum.makeCommands()
        }

        // 与 Lumi 使用相同的普通 Window Scene，避免 macOS Settings 容器
        // 额外注入边距/安全区域，导致共享设置视图被裁切。
        Window("设置", id: AppBootstrap.settingsWindowID) {
            FactoryCisum.makeSettingsWindow(configuration: CisumAppAssembly.configuration)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(
            width: AppBootstrap.defaultSettingsWindowSize.width,
            height: AppBootstrap.defaultSettingsWindowSize.height
        )
    }
}
#endif
