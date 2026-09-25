import CisumUIComponents
import SwiftUI

/// 播放封面 说明书 —— 章节式文档。
struct PlaybackHeroPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Playback Cover", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Provides the cover and title view for the player control area, automatically showing a cover or video frame based on the current media.")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Cover Display: shows the cover for audio and the video frame for video.", bundle: .module)),
                .init(String(localized: "Title Display: shows the title of the current track.", bundle: .module)),
                .init(String(localized: "Adaptive layout: shows only the title when the right cover column is hidden or space is tight.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "For audio, the cover area shows the matching cover and title.", bundle: .module)),
                .init(String(localized: "For video, the cover area shows the video playback frame.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "This plugin is a system-level capability that is always enabled and cannot be disabled.", bundle: .module)),
                .init(String(localized: "The cover area is injected into the player control area via ControlViewProviding.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}