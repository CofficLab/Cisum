import ProviderVideo
import SwiftUI

/// 视频播放控制按钮：上一个 / 播放暂停 / 下一个 / 倍速 / 收藏。
struct VideoControlButtonsView: View {
    @ObservedObject var viewModel: VideoLibraryViewModel

    var body: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.playNeighbor(offset: -1)
            } label: {
                Image(systemName: "backward.end.fill")
            }
            .accessibilityLabel(String(localized: "Previous", bundle: .module))

            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .accessibilityLabel(isPlaying ? String(localized: "Pause", bundle: .module) : String(localized: "Play", bundle: .module))

            Button {
                viewModel.playNeighbor(offset: 1)
            } label: {
                Image(systemName: "forward.end.fill")
            }
            .accessibilityLabel(String(localized: "Next", bundle: .module))

            Button {
                viewModel.cycleRate()
            } label: {
                Text(rateText)
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 38)
            }
            .accessibilityLabel(String(localized: "Playback Speed", bundle: .module))

            if let item = viewModel.currentItem {
                Button {
                    viewModel.toggleFavorite(item)
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(String(localized: "Favorites", bundle: .module))
            }
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("cisum.video.controls")
    }

    private var isPlaying: Bool {
        switch viewModel.playbackState {
        case .playing: return true
        default: return false
        }
    }

    private var rateText: String {
        let rate = viewModel.rate
        return rate == rate.rounded() ? "\(Int(rate))×" : "\(rate)×"
    }
}
