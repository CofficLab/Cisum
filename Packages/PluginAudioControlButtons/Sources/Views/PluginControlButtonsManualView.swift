import CisumUIComponents
import SwiftUI

/// 播放控制按钮 说明书 —— 章节式文档。
struct PluginControlButtonsManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Playback Control Buttons", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Provides the control button group at the bottom of the player for quickly switching tracks, playing/pausing, and changing play modes.")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Track Switching: quickly switch between previous and next tracks.", bundle: .module)),
                .init(String(localized: "Playback Control: plays and pauses the current track.", bundle: .module)),
                .init(String(localized: "Play Mode: switches between sequential, repeat, and other modes.", bundle: .module)),
                .init(String(localized: "More: show or hide the content view of the root view.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Click Previous or Next to switch tracks.", bundle: .module)),
                .init(String(localized: "Click the center button to play or pause the current track.", bundle: .module)),
                .init(String(localized: "Click the rightmost button to cycle through play modes.", bundle: .module)),
                .init(String(localized: "Click the More button to show or hide the content view.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "This plugin is a system-level capability that is always enabled and cannot be disabled.", bundle: .module)),
                .init(String(localized: "The button group is injected into the player control area via ControlViewProviding.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}