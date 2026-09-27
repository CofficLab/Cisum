import CisumUIComponents
import LumiUI
import SwiftUI

/// 星云 说明书 —— 章节式文档。
struct ThemeNebulaPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Nebula", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("A dreamy nebula-colored theme")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Theme Appearance: the overall palette and texture of the Nebula theme.", bundle: .module)),
                .init(String(localized: "Light/Dark Adaptation: adapts to the system light/dark mode.", bundle: .module)),
                .init(String(localized: "Instant Switching: applies immediately, no relaunch needed.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Select 「{display}」 under Settings → Appearance.", bundle: .module)),
                .init(String(localized: "The theme applies to the entire app interface immediately.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Theme settings persist and are kept after relaunch.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
