import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书场景的播放控制按钮组。
struct BookControlButtonsView: View {
    @ObservedObject private var viewModel: BookControlViewModel
    let toggleDBView: @MainActor () -> Void

    init(
        viewModel: BookControlViewModel,
        toggleDBView: @escaping @MainActor () -> Void
    ) {
        self.viewModel = viewModel
        self.toggleDBView = toggleDBView
    }

    var body: some View {
        GeometryReader { geometry in
            let buttonSize = buttonSize(for: geometry.size)

            HStack(spacing: buttonSpacing) {
                AppCircularIconButton(
                    systemImage: "ellipsis",
                    accessibilityLabel: "More",
                    size: buttonSize,
                    action: toggleDBView
                )
                AppCircularIconButton(
                    systemImage: "backward.end.fill",
                    accessibilityLabel: "Previous chapter",
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
                    accessibilityLabel: "Next chapter",
                    size: buttonSize,
                    action: viewModel.next
                )
                AppCircularIconButton(
                    systemImage: viewModel.playMode.iconName,
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

    private let buttonCount: CGFloat = 5
    private let buttonMaximumSize: CGFloat = 72
    private let buttonSpacing: CGFloat = 12
    private let bottomPadding: CGFloat = 20

    private func buttonSize(for size: CGSize) -> CGFloat {
        let availableWidth = size.width - buttonSpacing * (buttonCount - 1)
        let availableHeight = size.height - bottomPadding
        return max(0, min(buttonMaximumSize, availableWidth / buttonCount, availableHeight))
    }
}
