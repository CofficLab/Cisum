import ProviderVideo
import SwiftUI

/// 沉浸式播放器：画面 + 进度条 + 控制按钮 + 播放队列。
///
/// macOS 以覆盖层形式出现在视频库页面之上，iOS 以全屏 sheet 呈现；队列
/// 在 macOS 是右侧抽屉，在 iOS 是底部 sheet。
struct VideoPlayerOverlay: View {
    @ObservedObject var viewModel: VideoLibraryViewModel
    let onClose: () -> Void

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    @State private var isControlsVisible = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                playerArea
                controls
            }

            topBar

            if viewModel.isQueuePresented {
                queue
            }
        }
        .accessibilityIdentifier("cisum.video.player")
    }

    // MARK: - Player

    private var playerArea: some View {
        ZStack {
            if viewModel.playback.hasAsset {
                viewModel.playback.makePlayerView()
            } else {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topBar: some View {
        VStack {
            HStack(spacing: 12) {
                if let item = viewModel.currentItem {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(item.relativePath)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button {
                    viewModel.isQueuePresented.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
                .foregroundStyle(.white)
                .accessibilityLabel(String(localized: "Queue", bundle: .module))

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .foregroundStyle(.white)
                .accessibilityLabel(String(localized: "Close", bundle: .module))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
            )
            Spacer()
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : viewModel.progress },
                    set: { scrubValue = $0 }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing {
                        viewModel.seek(to: viewModel.duration * scrubValue)
                    }
                }
            )
            .tint(.white)
            .disabled(viewModel.duration <= 0)

            HStack {
                Text(timeText(viewModel.currentTime))
                Spacer()
                Text(timeText(viewModel.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.75))

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

                Menu {
                    ForEach(VideoLibraryViewModel.rateOptions, id: \.self) { rate in
                        Button {
                            viewModel.setRate(rate)
                        } label: {
                            if abs(Double(viewModel.rate) - Double(rate)) < 0.01 {
                                Label(rateTitle(rate), systemImage: "checkmark")
                            } else {
                                Text(rateTitle(rate))
                            }
                        }
                    }
                } label: {
                    Text(rateTitle(viewModel.rate))
                        .font(.caption.monospacedDigit())
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

                Spacer()
            }
            .font(.title3)
            .foregroundStyle(.white)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        )
    }

    private var isPlaying: Bool {
        viewModel.playbackState == .playing
    }

    // MARK: - Queue

    private var queue: some View {
        Group {
            #if os(iOS)
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Up Next", bundle: .module))
                        .font(.headline)
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(viewModel.playbackQueue) { item in
                                queueRow(item)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
                .padding(16)
                .background(Color.black.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .background(Color.black.opacity(0.4))
            #else
            VStack {
                HStack {
                    Text(String(localized: "Up Next", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        viewModel.isQueuePresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.playbackQueue) { item in
                            queueRow(item)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 14)
                }
            }
            .frame(width: 300)
            .background(Color.black.opacity(0.92))
            .transition(.move(edge: .trailing))
            #endif
        }
    }

    private func queueRow(_ item: VideoItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "film")
                .font(.caption)
                .frame(width: 64, height: 36)
                .background(Color.secondary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.play(item) }
    }

    // MARK: - Helpers

    private func rateTitle(_ rate: Float) -> String {
        rate == rate.rounded() ? "\(Int(rate))×" : "\(rate)×"
    }

    private func timeText(_ value: TimeInterval) -> String {
        guard value.isFinite, value > 0 else { return "0:00" }
        let total = Int(value.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
