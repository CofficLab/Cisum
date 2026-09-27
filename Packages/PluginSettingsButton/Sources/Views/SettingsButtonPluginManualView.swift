import CisumUIComponents
import LumiUI
import SwiftUI

/// 设置按钮 说明书 —— 章节式文档。
struct SettingsButtonPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Settings", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Opens the Settings window from the toolbar.")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Single entry to Settings: opens the Settings window from the toolbar.", bundle: .module)),
                .init(String(localized: "Toolbar shortcut: click the gear button in the upper-right corner of the window.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Click the gear button in the upper-right corner of the window.", bundle: .module)),
                .init(String(localized: "The Settings window opens; click again to bring it to the front.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
