import CisumUIComponents
import LumiUI
import SwiftUI

/// 播放引擎 说明书 —— 章节式文档。
struct PluginPlayBackManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Playback Engine", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Provides a unified playback engine that controls audio playback and restores the last played file after relaunch.")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Playback Engine: drives audio decoding and playback control.", bundle: .module)),
                .init(String(localized: "State record: writes the current playing file to disk.", bundle: .module)),
                .init(String(localized: "Relaunch Resume: restores the last played file after relaunch.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Automatically used whenever music or audiobook content is played.", bundle: .module)),
                .init(String(localized: "After relaunch, automatically restores the last played file (loaded but not auto-played).", bundle: .module)),
                .init(String(localized: "When the playing file changes, the engine records the latest file for the next resume.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "This plugin is a system-level capability that is always enabled and cannot be disabled.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
