import ProviderVideo
import SwiftUI

struct VideoPlayerHeroView: View {
    @ObservedObject var viewModel: VideoLibraryViewModel

    var body: some View {
        GeometryReader { geometry in
            let playerSize = VideoPlayerLayoutPolicy.playerSize(in: geometry.size)

            ZStack {
                if VideoPlayerLayoutPolicy.shouldRenderEmbeddedPlayer(
                    hasAsset: viewModel.playback.hasAsset,
                    isPlayerPresented: viewModel.isPlayerPresented
                ) {
                    viewModel.playback.makePlayerView()
                } else {
                    placeholder
                }
            }
            .frame(width: playerSize.width, height: playerSize.height)
            .background(viewModel.playback.hasAsset ? Color.black.opacity(0.85) : Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                VideoPlaybackStatusView(state: viewModel.playbackState, isImmersive: false)
            }
            .overlay(alignment: .bottomLeading) {
                if !viewModel.isPlayerPresented, let item = viewModel.currentItem {
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
            .overlay(alignment: .topTrailing) {
                if viewModel.playback.hasAsset && !viewModel.isPlayerPresented {
                    Button {
                        viewModel.presentPlayer()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.black.opacity(0.55), in: Circle())
                            #if os(iOS)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            #endif
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel(String(localized: "Enter Full Screen", bundle: .module))
                    .accessibilityIdentifier("cisum.video.expand")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.video.hero")
    }

    @ViewBuilder
    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 30))
                .foregroundStyle(viewModel.isPlayerPresented ? Color.white.opacity(0.65) : Color.secondary)
            if viewModel.isPlayerPresented, let item = viewModel.currentItem {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            } else {
                Text(String(localized: "Select a video to start playing", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }
}

struct VideoPlaybackStatusView: View {
    let state: VideoPlaybackState
    let isImmersive: Bool

    var body: some View {
        switch state {
        case .loading:
            VStack(spacing: 8) {
                ProgressView()
                    .tint(isImmersive ? .white : nil)
                Text(String(localized: "Loading…", bundle: .module))
                    .font(.caption)
            }
            .foregroundStyle(isImmersive ? Color.white : Color.secondary)
            .padding(12)
            .background(.black.opacity(isImmersive ? 0.45 : 0.25), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier("cisum.video.playback-loading")
        case .failed(let reason):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                Text(String(localized: "Playback Failed", bundle: .module))
                    .font(.headline)
                Text(reason)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .foregroundStyle(isImmersive ? Color.white : Color.secondary)
            .padding(16)
            .background(.black.opacity(isImmersive ? 0.65 : 0.35), in: RoundedRectangle(cornerRadius: 10))
            .padding(12)
            .accessibilityIdentifier("cisum.video.playback-error")
        case .idle, .playing, .paused, .finished:
            EmptyView()
        }
    }
}
