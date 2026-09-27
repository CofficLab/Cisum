import CisumUIComponents
import LumiUI
import SwiftUI

/// 外观设置 说明书 —— 章节式文档。
struct ThemeSettingsPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Appearance Settings", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Provides theme selection and appearance settings in the settings window")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Theme Selection: choose an appearance from all themes.", bundle: .module)),
                .init(String(localized: "Dark Mode: toggles between light and dark appearance.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Opens Appearance in the Settings window.", bundle: .module)),
                .init(String(localized: "Pick a theme you like.", bundle: .module)),
                .init(String(localized: "Switches between light and dark modes as needed.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "The theme applies immediately and persists.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
