import CisumUIComponents
import LumiUI
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// 设置窗口侧边栏顶部的 Header：应用图标 + 名称 + 版本。
///
/// 对齐 Lumi `PluginSettingView/Views/HeaderView.swift`：使用 `AppSettingsSidebarHeader`
/// 统一排版；图标取当前 App 的 `.app` 图标（`NSApplication.applicationIconImage`），
/// 取不到时回退到主题色 `app.fill` 图标（与 Lumi 未注册 Logo 时的回退一致）。
/// Cisum 暂无 Lumi 的 `LogoProviding` 体系，故此处直接用系统 App 图标呈现。
struct SettingsHeaderView: View {
    @LumiTheme private var appTheme
    private let appInfo = AppBundleInfo()

    var body: some View {
        AppSettingsSidebarHeader(
            name: appInfo.name,
            version: appInfo.version,
            build: appInfo.build,
            topSpacing: 22,
            bottomSpacing: 8
        ) {
            HStack {
                Spacer()
                logoView
                    .frame(width: 64, height: 64)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var logoView: some View {
        #if os(macOS)
        if let appIcon = NSApplication.shared.applicationIconImage {
            Image(nsImage: appIcon)
                .resizable()
                .scaledToFit()
        } else {
            fallbackIcon
        }
        #else
        fallbackIcon
        #endif
    }

    private var fallbackIcon: some View {
        Image(systemName: "app.fill")
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(appTheme.primary)
    }
}
