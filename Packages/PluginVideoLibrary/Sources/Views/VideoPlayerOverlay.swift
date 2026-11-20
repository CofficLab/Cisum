import LumiUI
import ProviderVideo
import SwiftUI

/// 沉浸式播放器：macOS 覆盖根布局，iOS 使用全屏 sheet。
struct VideoPlayerOverlay: View {
    @ObservedObject var viewModel: VideoLibraryViewModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                playerArea
                controls
            }

            topBar

            #if !os(iOS)
            if viewModel.isQueuePresented {
                queue
            }
            #endif
        }
        .accessibilityIdentifier("cisum.video.player")
        #if os(iOS)
        .sheet(isPresented: $viewModel.isQueuePresented) {
            iosQueue
        }
        #else
        .onExitCommand(perform: onClose)
        #endif
    }

    private var playerArea: some View {
        ZStack {
            if viewModel.playback.hasAsset {
                viewModel.playback.makePlayerView()
            } else {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.6))
            }

            VideoPlaybackStatusView(state: viewModel.playbackState, isImmersive: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if let item = viewModel.currentItem {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            VideoProgressView(viewModel: viewModel, isImmersive: true)

            HStack(spacing: 18) {
                AppCircularIconButton(
                    systemImage: "backward.end.fill",
                    accessibilityLabel: "Previous",
                    tint: .white,
                    size: 48,
                    action: { viewModel.playNeighbor(offset: -1) }
                )
                .disabled(!viewModel.playback.hasAsset)
                AppCircularIconButton(
                    systemImage: isPlaying ? "pause.fill" : "play.fill",
                    accessibilityLabel: isPlaying ? "Pause" : "Play",
                    tint: .white,
                    size: 56,
                    isActive: isPlaying,
                    action: viewModel.togglePlayback
                )
                .disabled(!viewModel.playback.hasAsset || viewModel.playbackState == .loading)
                AppCircularIconButton(
                    systemImage: "forward.end.fill",
                    accessibilityLabel: "Next",
                    tint: .white,
                    size: 48,
                    action: { viewModel.playNeighbor(offset: 1) }
                )
                .disabled(!viewModel.playback.hasAsset)
                AppCircularIconButton(
                    systemImage: "speedometer",
                    accessibilityLabel: "Playback Speed",
                    tint: .white,
                    size: 48,
                    isActive: viewModel.rate != 1,
                    action: viewModel.cycleRate
                )
                .accessibilityValue(rateTitle(viewModel.rate))
                .disabled(!viewModel.playback.hasAsset)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.85))
    }

    private var isPlaying: Bool {
        viewModel.playbackState == .playing
    }

    #if !os(iOS)
    private var queue: some View {
        HStack {
            Spacer()
            VStack(spacing: 0) {
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
                    .accessibilityLabel(String(localized: "Close", bundle: .module))
                }
                .padding(14)

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
            .background(Color.black.opacity(0.94))
        }
        .background(Color.black.opacity(0.35))
        .transition(.move(edge: .trailing))
    }
    #endif

    #if os(iOS)
    private var iosQueue: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.playbackQueue) { item in
                        queueRow(item)
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "Up Next", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", bundle: .module)) {
                        viewModel.isQueuePresented = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
    #endif

    private func queueRow(_ item: VideoItem) -> some View {
        Button {
            viewModel.play(item)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.availability == .available ? "film" : "icloud")
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
                if viewModel.currentItem?.url == item.url {
                    Image(systemName: "waveform")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func rateTitle(_ rate: Float) -> String {
        rate == rate.rounded() ? "\(Int(rate))×" : "\(rate)×"
    }
}
