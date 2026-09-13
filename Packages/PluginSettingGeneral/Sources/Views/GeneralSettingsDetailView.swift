#if canImport(AppKit)
import AppKit
#endif
import CisumUIComponents
import ProviderDocsView
import SwiftUI

/// 通用设置详情视图 —— 设置窗口「通用」标签页。
///
/// 对齐 Lumi `GeneralSettingsDetailView` 的分组卡片形态：保留「应用信息」
/// 分组（DEBUG 下附加「调试」分组），新增「说明书」分组（打开说明书浏览器，
/// 浏览各插件贡献的说明书），删减了依赖 Lumi 特有能力的分组（官网 / 更新 /
/// 引导重放）。
///
/// 只依赖 `GeneralSettingsViewModel`；说明书条目由组装层注入。
struct GeneralSettingsDetailView: View {
    @ObservedObject private var viewModel: GeneralSettingsViewModel

    @State private var isShowingManuals = false

    init(viewModel: GeneralSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 16) {
                appInfoSection
                manualsSection
                #if DEBUG
                debugSection
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $isShowingManuals) {
            ManualsBrowserView(manuals: viewModel.manualEntries)
        }
    }

    // MARK: - 应用信息

    private var appInfoSection: some View {
        AppSettingSection(title: String(localized: "App Info", bundle: .module)) {
            settingRow(icon: "app", title: String(localized: "Name", bundle: .module), value: MagicApp.getAppName())
            settingRow(icon: "number", title: "Bundle ID", value: MagicApp.getBundleIdentifier())
            settingRow(icon: "info.circle", title: String(localized: "Version", bundle: .module), value: MagicApp.getVersion())
            settingRow(icon: "hammer", title: String(localized: "Build", bundle: .module), value: MagicApp.getBuildNumber())
        }
    }

    // MARK: - 说明书

    private var manualsSection: some View {
        AppSettingSection(title: String(localized: "Manual", bundle: .module)) {
            AppSettingRow(
                title: "Browse the manuals contributed by plugins",
                icon: "book",
                action: { isShowingManuals = true }
            ) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - 调试

    #if DEBUG
    private var debugSection: some View {
        AppSettingSection(title: "Debug") {
            AppSettingRow(
                title: "Open Data Directory",
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
