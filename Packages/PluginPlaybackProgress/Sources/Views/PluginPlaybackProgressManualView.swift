import CisumUIComponents
import SwiftUI

/// 播放进度 说明书 —— 章节式文档。
struct PlaybackProgressPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Playback Progress", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Provides the progress bar view for the player control area, showing the current progress in real time and supporting drag to control the position.")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Progress Display: shows the current position and total duration in real time.", bundle: .module)),
                .init(String(localized: "Drag Control: drag the progress bar to adjust the position.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "The progress bar advances automatically while playing, showing the current progress.", bundle: .module)),
                .init(String(localized: "Click or drag the progress bar to jump to a target position.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "This plugin is a system-level capability that is always enabled and cannot be disabled.", bundle: .module)),
                .init(String(localized: "The progress bar is injected into the player control area via ControlViewProviding.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}