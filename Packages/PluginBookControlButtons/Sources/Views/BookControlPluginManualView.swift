import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书控制 说明书 —— 章节式文档。
struct BookControlPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Audiobook Controls", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Control play, pause, and chapter navigation for the current audiobook")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Play / Pause: one-click toggle of the playback state.", bundle: .module)),
                .init(String(localized: "Previous Chapter: switches to the previous chapter.", bundle: .module)),
                .init(String(localized: "Next Chapter: switches to the next chapter.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Click the play / pause button in the player area.", bundle: .module)),
                .init(String(localized: "Click Previous Chapter / Next Chapter to switch chapters.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Requires an audiobook that is currently playing.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
