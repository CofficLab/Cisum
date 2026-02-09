import MagicKit
import MagicPlayMan
import SwiftUI

/// 播放模式按钮
struct PlayModeButton: View {
    @EnvironmentObject var man: PlayMan
    @Environment(\.demoMode) var isDemoMode

    private let size: CGFloat = 32

    var body: some View {
        Group {
            switch man.playMode {
            case .sequence:
                modeIcon(systemName: .iconMusicNoteList)
            case .repeatAll:
                modeIcon(systemName: .iconRepeatAll)
            case .loop:
                modeIcon(systemName: .iconRepeat1)
            case .shuffle:
                modeIcon(systemName: .iconShuffle)
            }
        }
        .hoverScale(105)
        .shadowSm()
    }

    private func modeIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: self.size * 0.6))
            .frame(width: size, height: size)
            .foregroundStyle(.secondary)
            .inCard(.ultraThinMaterial)
            .roundedFull()
            .inButtonWithAction {
                man.togglePlayMode()
            }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
