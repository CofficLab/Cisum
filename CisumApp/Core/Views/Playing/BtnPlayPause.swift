import MagicKit
import MagicPlayMan
import SwiftUI

/// 播放/暂停按钮
struct PlayPauseButton: View {
    @EnvironmentObject var man: PlayMan
    @Environment(\.demoMode) var isDemoMode

    private let size: CGFloat = 32

    var body: some View {
        Group {
            if man.state == .playing {
                pauseButton
            } else {
                playButton
            }
        }
        .hoverScale(105)
        .shadowSm()
    }

    private var playButton: some View {
        Image.playFill
            .font(.system(size: self.size * 0.6))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .inCard(.ultraThinMaterial)
            .roundedFull()
            .inButtonWithAction {
                man.playCurrent(reason: "PlayPauseButton")
            }
    }

    private var pauseButton: some View {
        Image.pauseFill
            .font(.system(size: self.size * 0.6))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .inCard(.ultraThinMaterial)
            .roundedFull()
            .inButtonWithAction {
                man.pause(reason: "PlayPauseButton")
            }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
