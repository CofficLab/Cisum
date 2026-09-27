import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

extension MagicPlayManPreviewView {
    /// 控制区域
    var controlsSection: some View {
        GroupBox {
            controlsView
        }
        .padding()
    }

    /// 控制视图
    private var controlsView: some View {
        VStack(spacing: 16) {
            playMan.makeProgressView()

            HStack(spacing: 16) {
                Spacer()

                playbackControls

                Spacer()
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    /// 播放控制按钮组
    private var playbackControls: some View {
        HStack(spacing: 16) {
            playMan.makePlayModeButtonView()
            playMan.makePreviousButtonView()
            playMan.makeRewindButtonView()
            playMan.makePlayPauseButtonView()
            playMan.makeForwardButtonView()
            playMan.makeNextButtonView()
        }.frame(height: 40)
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayManPreviewView()
        .frame(width: 600, height: 700)
}
