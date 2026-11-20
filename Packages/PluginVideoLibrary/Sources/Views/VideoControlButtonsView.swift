import LumiUI
import ProviderVideo
import SwiftUI

struct VideoControlButtonsView: View {
    @ObservedObject var viewModel: VideoLibraryViewModel
    let toggleDBView: @MainActor () -> Void

    init(viewModel: VideoLibraryViewModel, toggleDBView: @escaping @MainActor () -> Void) {
        self.viewModel = viewModel
        self.toggleDBView = toggleDBView
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = AppResponsivePlayerLayoutMetrics.shared
            let buttonSize = metrics.controlButtonSize(
                width: geometry.size.width,
                areaHeight: geometry.size.height
            )

            HStack(spacing: metrics.controlButtonSpacing) {
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
                    action: { viewModel.playNeighbor(offset: -1) }
                )
                .disabled(!viewModel.playback.hasAsset)
                AppCircularIconButton(
                    systemImage: isPlaying ? "pause.fill" : "play.fill",
                    accessibilityLabel: isPlaying ? "Pause" : "Play",
                    size: buttonSize,
                    isActive: isPlaying,
                    action: viewModel.togglePlayback
                )
                .disabled(!viewModel.playback.hasAsset || viewModel.playbackState == .loading)
                AppCircularIconButton(
                    systemImage: "forward.end.fill",
                    accessibilityLabel: "Next",
                    size: buttonSize,
                    action: { viewModel.playNeighbor(offset: 1) }
                )
                .disabled(!viewModel.playback.hasAsset)
                AppCircularIconButton(
                    systemImage: "speedometer",
                    accessibilityLabel: "Playback Speed",
                    size: buttonSize,
                    isActive: viewModel.rate != 1,
                    action: viewModel.cycleRate
                )
                .disabled(!viewModel.playback.hasAsset)
            }
            .padding(.bottom, metrics.controlButtonBottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cisum.video.controls")
    }

    private var isPlaying: Bool {
        viewModel.playbackState == .playing
    }
}
