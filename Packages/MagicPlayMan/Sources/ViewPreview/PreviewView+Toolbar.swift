import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

extension MagicPlayManPreviewView {
    /// 顶部工具栏
    var toolbarView: some View {
        HStack {
            leadingToolbarItems
            Spacer()
            trailingToolbarItems
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    /// 左侧工具栏项
    var leadingToolbarItems: some View {
        HStack {
            playMan.makeMediaPickerButton()
        }
    }

    /// 右侧工具栏项
    var trailingToolbarItems: some View {
        HStack {
            playMan.makePlayPauseButtonView()
            playMan.makePlayModeButtonView()
            playMan.makeSubscribersButtonView()
            playMan.makeLikeButtonView()
        }
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayManPreviewView()
        .frame(width: 600, height: 700)
}
