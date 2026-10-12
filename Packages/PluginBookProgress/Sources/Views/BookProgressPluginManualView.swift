import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书进度 说明书 —— 章节式文档。
struct BookProgressPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Audiobook Progress", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Display and scrub audiobook progress, remembering the last listening position")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Progress Bar: shows the current playback position.", bundle: .module)),
                .init(String(localized: "Seek: drag to jump to any position.", bundle: .module)),
                .init(String(localized: "Remember Position: automatically remembers where you left off.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "View the current progress on the player page.", bundle: .module)),
                .init(String(localized: "Drag the progress bar to jump to a target position.", bundle: .module)),
                .init(String(localized: "Reopens to the last position automatically.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "The progress bar updates in real time while playing.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
