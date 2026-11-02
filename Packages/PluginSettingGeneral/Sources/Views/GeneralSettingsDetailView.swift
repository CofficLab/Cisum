#if canImport(AppKit)
import AppKit
#endif
import MagicKit
import LumiUI
import SwiftUI

/// 通用设置详情视图 —— 设置窗口「通用」标签页。
///
/// 对齐 Lumi `GeneralSettingsDetailView` 的分组卡片形态：保留「应用信息」
/// 分组（DEBUG 下附加「调试」分组）。
///
/// 只依赖 `GeneralSettingsViewModel`。
struct GeneralSettingsDetailView: View {
    @ObservedObject private var viewModel: GeneralSettingsViewModel

    init(viewModel: GeneralSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 16) {
                appInfoSection
                #if DEBUG
                debugSection
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 应用信息

    private var appInfoSection: some View {
        AppSettingSection(title: String(localized: "App Info", bundle: .module)) {
            settingRow(icon: "app", title: String(localized: "Name", bundle: .module), value: MagicApp.getAppName())
            settingRow(icon: "number", title: String(localized: "Bundle ID", bundle: .module), value: MagicApp.getBundleIdentifier())
            settingRow(icon: "info.circle", title: String(localized: "Version", bundle: .module), value: MagicApp.getVersion())
            settingRow(icon: "hammer", title: String(localized: "Build", bundle: .module), value: MagicApp.getBuildNumber())
        }
    }

    // MARK: - 调试

    #if DEBUG
    private var debugSection: some View {
        AppSettingSection(title: String(localized: "Debug", bundle: .module)) {
            AppSettingRow(
                title: String(localized: "Open Data Directory", bundle: .module),
                icon: "folder",
                action: { openDataDirectory() }
            ) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func openDataDirectory() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.cisum"
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(bundleID, isDirectory: true)
        guard let url = appSupport else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        #if canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }
    #endif

    // MARK: - 通用组件

    /// 只读信息行：图标 + 标题 + 右侧值（复用 `AppSettingRow`，与其余设置页一致）。
    private func settingRow(icon: String, title: String, value: String) -> some View {
        AppSettingRow(title: title, icon: icon) {
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
