import LumiUI
import SwiftUI

/// 有声书场景的播放控制按钮组。
struct BookControlButtonsView: View {
    @ObservedObject private var viewModel: BookControlViewModel
    @Environment(\.toastWindowID) private var windowID
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
                .disabled(viewModel.isLoading)
                AppCircularIconButton(
                    systemImage: "forward.end.fill",
                    accessibilityLabel: "Next chapter",
                    size: buttonSize,
                    action: viewModel.next
                )
            }
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .onAppear { viewModel.setSourceWindowID(windowID) }
        .onChange(of: windowID) { _, newValue in
            viewModel.setSourceWindowID(newValue)
        }
    }

    private let buttonCount: CGFloat = 4
    private let buttonMaximumSize: CGFloat = 72
    private let buttonSpacing: CGFloat = 12
    private let bottomPadding: CGFloat = 20

    private func buttonSize(for size: CGSize) -> CGFloat {
        let availableWidth = size.width - buttonSpacing * (buttonCount - 1)
        let availableHeight = size.height - bottomPadding
        let widthLimited = max(0, availableWidth / buttonCount)
        let diameter = max(0, min(buttonMaximumSize, widthLimited, availableHeight))
        #if os(visionOS)
        // 与音乐场景 ControlButtonsView 一致：visionOS 注视瞄准下限 60pt，
        // 超出宽度预算时按宽度收缩，避免按钮溢出行宽。
        return min(max(diameter, Self.visionOSButtonFloor), widthLimited)
        #else
        return diameter
        #endif
    }

    /// visionOS 注视 / 眼动瞄准目标的最小直径（HIG 建议 ≥60pt）。
    private static let visionOSButtonFloor: CGFloat = 60
}
