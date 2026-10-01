import CisumUIComponents
import LumiUI
import SwiftUI

/// 打开当前 说明书 —— 章节式文档。
struct OpenButtonPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Open Current", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Provides an Open Current entry in the toolbar to quickly locate the current file")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Open File: shows the current file in the file manager.", bundle: .module)),
                .init(String(localized: "Quick Jump: locates the current media with one click.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Click the Open Current button in the toolbar.", bundle: .module)),
                .init(String(localized: "Reveals the current playing file in the file manager.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Requires content that is currently playing.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
