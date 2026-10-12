import Foundation
import CisumUIComponents
import LumiUI
import MagicKit
import OSLog
import SwiftUI

public extension MagicPlayMan {
    /// 切换到下一个播放模式
    ///
    /// 播放模式按以下顺序循环切换：
    /// sequence -> single -> random -> sequence
    func togglePlayMode() {
        changePlayMode(self.playMode.next)
        if verbose {
            os_log("\(self.t)Playback mode changed to: \(self.playMode.displayName)")
        }
    }

    /// 获取当前播放模式的显示名称
    var playModeDisplayName: String {
        playMode.displayName
    }

    /// 获取当前播放模式的图标名称
    var playModeIcon: String {
        playMode.icon
    }
}

// MARK: - Preview

#Preview("MagicPlayMan - Large") {
    MagicPlayMan.getPreviewView()
        .frame(height: 1000)
}
