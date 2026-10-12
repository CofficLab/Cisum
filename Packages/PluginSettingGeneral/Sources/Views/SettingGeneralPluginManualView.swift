import CisumUIComponents
import LumiUI
import SwiftUI

/// 通用设置 说明书 —— 章节式文档。
struct SettingGeneralPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "General Settings", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Provides general settings such as app info and manuals in the Settings window.")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "App Info: shows basic info such as name and version.", bundle: .module)),
                .init(String(localized: "Manual: browse the manuals contributed by each plugin.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Opens the General tab in the Settings window.", bundle: .module)),
                .init(String(localized: "View the app info.", bundle: .module)),
                .init(String(localized: "Click Manual to browse each plugin's manual.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Manual content is contributed by each plugin.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
