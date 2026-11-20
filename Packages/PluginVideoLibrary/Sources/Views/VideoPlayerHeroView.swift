import ProviderVideo
import SwiftUI

/// 视频播放主视图：播放器画面 + 标题信息。
struct VideoPlayerHeroView: View {
    @ObservedObject var viewModel: VideoLibraryViewModel

    var body: some View {
        ZStack {
            if viewModel.playback.hasAsset {
                viewModel.playback.makePlayerView()
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottomLeading) {
            if let item = viewModel.currentItem {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(10)
            }
        }
        .accessibilityIdentifier("cisum.video.hero")
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.6))
            Text(String(localized: "Select a video to start playing", bundle: .module))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
