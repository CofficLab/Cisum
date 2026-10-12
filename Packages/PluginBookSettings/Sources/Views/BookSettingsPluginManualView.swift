import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书设置 说明书 —— 章节式文档。
struct BookSettingsPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Audiobook Settings", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Provides audiobook-related settings")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Playback Settings: configures audiobook playback preferences.", bundle: .module)),
                .init(String(localized: "Preferences: centrally manages audiobook settings.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Opens audiobook settings in the Settings window.", bundle: .module)),
                .init(String(localized: "Adjusts playback preferences as needed.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Settings take effect immediately and persist.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
