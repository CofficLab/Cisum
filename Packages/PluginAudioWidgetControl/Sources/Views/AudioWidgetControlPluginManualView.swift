import CisumUIComponents
import LumiUI
import SwiftUI

/// 小组件控制 说明书 —— 章节式文档。
struct AudioWidgetControlPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Widget Control", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Control music playback via desktop widgets")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Widget: shows playback state in the desktop widget.", bundle: .module)),
                .init(String(localized: "Quick Controls: play / pause directly from the widget.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Add the Cisum playback widget in the system widget gallery.", bundle: .module)),
                .init(String(localized: "Controls playback via the widget.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Requires the system to support desktop widgets.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
