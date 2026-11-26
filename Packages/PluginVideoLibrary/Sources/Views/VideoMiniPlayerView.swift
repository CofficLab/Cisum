import ProviderVideo
import SwiftUI

/// 迷你播放器：收起沉浸播放后固定在内容区右下角，保持播放不中断。
struct VideoMiniPlayerView: View {
    @ObservedObject var viewModel: VideoLibraryViewModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.presentPlayer()
            } label: {
                ZStack {
                    if let item = viewModel.currentItem {
                        VideoThumbnailView(url: item.url, size: CGSize(width: 160, height: 90), cornerRadius: 6)
                    } else {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.5), in: Circle())
                }
            }
            .buttonStyle(.plain)
            .frame(width: 92)
            .accessibilityLabel(String(localized: "Expand Player", bundle: .module))
            .accessibilityIdentifier("cisum.video.expand")

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentItem?.title ?? "")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                progressBar
                Text("\(VideoTimeFormatting.string(from: viewModel.currentTime)) / \(VideoTimeFormatting.string(from: viewModel.duration))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.playback.hasAsset || viewModel.playbackState == .loading)
            .accessibilityLabel(viewModel.isPlaying
                ? String(localized: "Pause", bundle: .module)
                : String(localized: "Play", bundle: .module))
            .accessibilityIdentifier("cisum.video.mini.toggle")

            Button {
                viewModel.stopPlayback()
            } label: {
                Image(systemName: "stop.fill")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "Stop", bundle: .module))
            .accessibilityIdentifier("cisum.video.mini.stop")
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .frame(width: 320)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.video.miniplayer")
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(2, proxy.size.width * min(max(viewModel.progress, 0), 1)))
            }
        }
        .frame(height: 3)
        .accessibilityElement()
        .accessibilityValue("\(Int(viewModel.progress * 100))%")
        .accessibilityIdentifier("cisum.video.progress")
    }
}
