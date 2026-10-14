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
            let buttonSize = AppResponsivePlayerLayoutMetrics.shared.controlButtonSize(
                width: geometry.size.width,
                areaHeight: geometry.size.height
            )

            HStack(spacing: AppResponsivePlayerLayoutMetrics.shared.controlButtonSpacing) {
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
                if let downloadProgress = viewModel.downloadProgress {
                    // 下载态：播放按钮位置改渲染进度环。
                    // 仍包在同一个 Button 里——下载期间点击依旧无效（下方 .disabled），
                    // 但保留按钮语义可让命中区域与无障碍树保持一致，
                    // 不会在下载开始时整个控件从按钮「变形」为纯图形。
                    Button(action: viewModel.toggle) {
                        ControlButtonsDownloadRing(
                            progress: Self.clamped(downloadProgress),
                            lineWidth: max(2, buttonSize * 0.06)
                        )
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Circle().fill(DesignTokens.Material.glassUltra))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Downloading")
                    // 下载/加载期间禁用：否则点击会被状态机静默忽略（点了没反应）。
                    .disabled(viewModel.isBusy)
                } else {
                    AppCircularIconButton(
                        systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill",
                        accessibilityLabel: viewModel.isPlaying ? "Pause" : "Play",
                        size: buttonSize,
                        isActive: viewModel.isPlaying,
                        action: viewModel.toggle
                    )
                    // 下载/加载期间禁用：否则点击会被状态机静默忽略（点了没反应）。
                    .disabled(viewModel.isBusy)
                }
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

    /// 把进度夹到 0...1。
    ///
    /// 引擎上报的百分比来自资源键快照，可能越界（负值、超过 1、或 NaN）。
    /// `Circle.trim` 越界会直接抛错导致崩溃，因此必须在渲染前夹取。
    private static func clamped(_ progress: Double) -> Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
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
