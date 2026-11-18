import LumiUI
import MagicKit
import SwiftUI

/// 播放器底部控制按钮组：更多 / 上一曲 / 播放暂停 / 下一曲 / 播放模式。
struct ControlButtonsView: View {
    @ObservedObject private var viewModel: ControlButtonsViewModel
    @Environment(\.toastWindowID) private var windowID
    let toggleDBView: @MainActor () -> Void

    init(viewModel: ControlButtonsViewModel, toggleDBView: @escaping @MainActor () -> Void) {
        self.viewModel = viewModel
        self.toggleDBView = toggleDBView
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = AppResponsivePlayerLayoutMetrics.shared
            let buttonSize = Self.controlButtonSize(
                width: geometry.size.width,
                areaHeight: geometry.size.height,
                metrics: metrics
            )

            HStack(spacing: metrics.controlButtonSpacing) {
                // 「⋯」：展开/收起音乐仓库视图。仓库为空时它自己带上引导气泡。
                MoreButtonGuidanceView(
                    size: buttonSize,
                    showsGuidance: viewModel.shouldShowRepositoryGuidance,
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
                // 下载/加载期间禁用：否则点击会被状态机静默忽略（点了没反应）。
                .disabled(viewModel.isBusy)
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
        .onAppear { viewModel.setSourceWindowID(windowID) }
        .onChange(of: windowID) { _, newValue in
            viewModel.setSourceWindowID(newValue)
        }
    }

    private let bottomPadding = AppResponsivePlayerLayoutMetrics.shared.controlButtonBottomPadding

    /// visionOS 的注视 / 眼动瞄准目标需要更大直径（HIG 建议 ≥60pt），
    /// 桌面默认值在 visionOS 上渲染出来只有 36–44pt。预留行高一侧
    /// （ProviderControlView.ControlView.buttonHeight）用同一数值放大，
    /// 两处必须保持一致，按钮才不会被行高截断。
    private static let visionOSButtonFloor: CGFloat = 60

    private static func controlButtonSize(
        width: CGFloat,
        areaHeight: CGFloat,
        metrics: AppResponsivePlayerLayoutMetrics
    ) -> CGFloat {
        let size = metrics.controlButtonSize(width: width, areaHeight: areaHeight)
        #if os(visionOS)
        let widthLimited = max(0, (width - metrics.controlButtonSpacing * 4) / 5)
        return min(max(size, visionOSButtonFloor), widthLimited)
        #else
        return size
        #endif
    }

    private var playModeIconName: String {
        switch viewModel.playMode {
        case .sequence: "music.note.list"
        case .loop: "repeat.1"
        case .shuffle: "shuffle"
        case .repeatAll: "repeat"
        }
    }
}
