import LumiUI
import ProviderVideo
import SwiftUI

struct VideoPlayerRootOverlay: View {
    @ObservedObject var viewModel: VideoLibraryViewModel

    var body: some View {
        if viewModel.isPlayerPresented {
            VideoPlayerOverlay(viewModel: viewModel) {
                viewModel.dismissPlayer()
            }
            .transition(.opacity)
        }
    }
}

/// 沉浸式播放器：macOS 覆盖根布局，iOS / visionOS 使用全屏呈现。
///
/// 画面上只有两层：视频与悬浮控件。播放中鼠标静止一段时间后控件自动隐藏，
/// 移动鼠标即重新出现；macOS 另支持空格播放暂停、左右方向键快退快进、Esc 退出。
struct VideoPlayerOverlay: View {
    @ObservedObject var viewModel: VideoLibraryViewModel
    let onClose: () -> Void
    @State private var isChromeHidden = false
    @State private var autoHideTask: Task<Void, Never>?
    #if os(macOS)
    @FocusState private var isPlayerFocused: Bool
    #endif

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            playerArea

            // 视频视图自己不处理鼠标，这层透明层负责「点击画面」的语义。
            Color.white.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture(perform: handleSurfaceTap)

            chrome
            #if !os(iOS)
            if viewModel.isQueuePresented {
                queue
            }
            #endif
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.video.player")
        .onAppear(perform: scheduleAutoHide)
        .onChange(of: viewModel.isPlaying) { _, playing in
            if playing {
                scheduleAutoHide()
            } else {
                showChrome()
            }
        }
        .onDisappear {
            autoHideTask?.cancel()
        }
        #if os(iOS)
        .sheet(isPresented: $viewModel.isQueuePresented) {
            iosQueue
        }
        #elseif os(macOS)
        .focusable()
        .focusEffectDisabled()
        .focused($isPlayerFocused)
        .onAppear { isPlayerFocused = true }
        .onKeyPress(.space) {
            viewModel.togglePlayback()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.seekRelative(-10)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.seekRelative(10)
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
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

    private var chrome: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            controls
        }
        .opacity(isChromeHidden ? 0 : 1)
        .allowsHitTesting(!isChromeHidden)
        .animation(.easeOut(duration: 0.18), value: isChromeHidden)
        #if os(macOS)
        .onContinuousHover { phase in
            switch phase {
            case .active:
                scheduleAutoHide()
            case .ended:
                isChromeHidden = viewModel.isPlaying
            }
        }
        .onChange(of: isChromeHidden) { _, hidden in
            if hidden { NSCursor.setHiddenUntilMouseMoves(true) }
        }
        #endif
    }

    private func handleSurfaceTap() {
        if isChromeHidden {
            scheduleAutoHide()
        } else {
            viewModel.togglePlayback()
        }
    }

    private func scheduleAutoHide() {
        #if os(macOS)
        autoHideTask?.cancel()
        isChromeHidden = false
        autoHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled, viewModel.isPlaying else { return }
            isChromeHidden = true
        }
        #endif
    }

    private func showChrome() {
        autoHideTask?.cancel()
        isChromeHidden = false
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
            rateMenu
            Button {
                viewModel.isQueuePresented.toggle()
            } label: {
                Image(systemName: "list.bullet")
                    #if os(iOS)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    #endif
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel(String(localized: "Queue", bundle: .module))
            .accessibilityIdentifier("cisum.video.queue")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    #if os(iOS)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    #endif
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel(String(localized: "Close", bundle: .module))
            .accessibilityIdentifier("cisum.video.close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            VideoProgressView(viewModel: viewModel, isImmersive: true)

            HStack(spacing: 16) {
                Spacer(minLength: 0)
                AppCircularIconButton(
                    systemImage: "gobackward.10",
                    accessibilityLabel: "Skip Back 10 Seconds",
                    tint: .white,
                    size: 44,
                    action: { viewModel.seekRelative(-10) }
                )
                .accessibilityIdentifier("cisum.video.skipBack")
                .disabled(!viewModel.playback.hasAsset)
                AppCircularIconButton(
                    systemImage: "backward.end.fill",
                    accessibilityLabel: "Previous",
                    tint: .white,
                    size: 48,
                    action: { viewModel.playNeighbor(offset: -1) }
                )
                .disabled(!viewModel.playback.hasAsset)
                AppCircularIconButton(
                    systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill",
                    accessibilityLabel: viewModel.isPlaying ? "Pause" : "Play",
                    tint: .white,
                    size: 60,
                    isActive: viewModel.isPlaying,
                    action: viewModel.togglePlayback
                )
                .accessibilityIdentifier("cisum.video.playpause")
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
                    systemImage: "goforward.10",
                    accessibilityLabel: "Skip Forward 10 Seconds",
                    tint: .white,
                    size: 44,
                    action: { viewModel.seekRelative(10) }
                )
                .accessibilityIdentifier("cisum.video.skipForward")
                .disabled(!viewModel.playback.hasAsset)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
        )
    }

    private var rateMenu: some View {
        Menu {
            ForEach(VideoLibraryViewModel.rateOptions, id: \.self) { option in
                Button {
                    viewModel.setRate(option)
                } label: {
                    if abs(viewModel.rate - option) < 0.01 {
                        Label(rateTitle(option), systemImage: "checkmark")
                    } else {
                        Text(rateTitle(option))
                    }
                }
            }
        } label: {
            Text(rateTitle(viewModel.rate))
                .font(.callout.monospacedDigit().weight(.medium))
                #if os(iOS)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                #else
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.15), in: Capsule())
                #endif
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.white)
        .accessibilityLabel(String(localized: "Playback Speed", bundle: .module))
        .accessibilityIdentifier("cisum.video.rate")
        .disabled(!viewModel.playback.hasAsset)
    }

    // MARK: - Queue

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
                    .buttonStyle(.plain)
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
        .accessibilityIdentifier("cisum.video.queuePanel")
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

/// 播放状态提示（缓冲 / 失败），沉浸播放器与列表共用。
struct VideoPlaybackStatusView: View {
    let state: VideoPlaybackState
    var isImmersive = false

    var body: some View {
        switch state {
        case .loading:
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.large)
                if isImmersive {
                    Text(String(localized: "Loading…", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .accessibilityIdentifier("cisum.video.status.loading")
        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .foregroundStyle(isImmersive ? Color.white : Color.primary)
            .padding(16)
            .background(.black.opacity(isImmersive ? 0.55 : 0.0001), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier("cisum.video.status.failed")
        case .idle, .playing, .paused, .finished:
            EmptyView()
        }
    }
}
