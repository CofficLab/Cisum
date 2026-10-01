import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

/// 播放器底部控制按钮组：更多 / 上一曲 / 播放暂停 / 下一曲 / 播放模式。
struct ControlButtonsView: View {
    @ObservedObject private var viewModel: ControlButtonsViewModel
    let toggleDBView: @MainActor () -> Void

    init(viewModel: ControlButtonsViewModel, toggleDBView: @escaping @MainActor () -> Void) {
        self.viewModel = viewModel
        self.toggleDBView = toggleDBView
    }

    var body: some View {
        GeometryReader { geometry in
            let buttonSize = CisumPlayerLayout.controlButtonSize(
                width: geometry.size.width,
                areaHeight: geometry.size.height
            )

            HStack(spacing: CisumPlayerLayout.controlButtonSpacing) {
                AppCircularIconButton(
                    systemImage: "ellipsis",
                    accessibilityLabel: "More",
                    size: buttonSize,
                    action: toggleDBView
                )
                AppCircularIconButton(
                    systemImage: "backward.end.fill",
                    accessibilityLabel: "Previous",
                    size: buttonSize,
                    action: viewModel.previous
                )
                AppCircularIconButton(
                    systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill",
                    accessibilityLabel: viewModel.isPlaying ? "Pause" : "Play",
                    size: buttonSize,
                    isActive: viewModel.isPlaying,
                    action: viewModel.toggle
                )
                AppCircularIconButton(
                    systemImage: "forward.end.fill",
                    accessibilityLabel: "Next",
                    size: buttonSize,
                    action: viewModel.next
                )
                AppCircularIconButton(
                    systemImage: playModeIconName,
                    accessibilityLabel: "Playback mode",
                    size: buttonSize,
                    isActive: viewModel.playMode != .sequence,
                    action: viewModel.togglePlayMode
                )
            }
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
    }

    private let bottomPadding = CisumPlayerLayout.controlButtonBottomPadding

    private var playModeIconName: String {
        switch viewModel.playMode {
        case .sequence: "music.note.list"
        case .loop: "repeat.1"
        case .shuffle: "shuffle"
        case .repeatAll: "repeat"
        }
    }
}
