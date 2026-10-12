import CisumUIComponents
import LumiUI
import SwiftUI

/// 插件管理器说明书 —— 章节式文档（对齐 Lumi `PluginManagerManualView`）。
///
/// 在 设置 → 通用 → 说明书 中阅读。
struct PluginManagerManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Plugin Manager", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("This manual introduces the Plugin Manager page of Cisum: how to view registered plugins, search and filter by category, and enable or disable a plugin.")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Interface", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Header stats: shows the total number of configurable plugins and how many are enabled.", bundle: .module)),
                .init(String(localized: "Left list: searchable (name / identifier / description) and filterable by category.", bundle: .module)),
                .init(String(localized: "Right detail: shows the selected plugin's About page, including name, description, stage, and enable switch.", bundle: .module))
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Type a keyword in the search field and the list filters instantly.", bundle: .module)),
                .init(String(localized: "Click a category chip (e.g. Music Library, Theme) to switch filters; click All again to clear.", bundle: .module)),
                .init(String(localized: "Click a plugin in the list to show its About page on the right.", bundle: .module)),
                .init(String(localized: "Toggle the Enable switch in the top-right corner to enable or disable the plugin instantly.", bundle: .module))
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Always-on / disabled plugins are not configurable and do not appear in the list.", bundle: .module)),
                .init(String(localized: "Every plugin has an About page; plugins without a custom one show a default page based on metadata.", bundle: .module))
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
