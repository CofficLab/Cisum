import ProviderVideo
import SwiftUI

struct VideoPlayerHeroView: View {
    @ObservedObject var viewModel: VideoLibraryViewModel

    var body: some View {
        GeometryReader { geometry in
            let playerSize = VideoPlayerLayoutPolicy.playerSize(in: geometry.size)

            ZStack {
                if viewModel.playback.hasAsset {
                    viewModel.playback.makePlayerView()
                } else {
                    placeholder
                }
            }
            .frame(width: playerSize.width, height: playerSize.height)
            .background(viewModel.playback.hasAsset ? Color.black.opacity(0.85) : Color.secondary.opacity(0.08))
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("cisum.video.hero")
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text(String(localized: "Select a video to start playing", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }
}
