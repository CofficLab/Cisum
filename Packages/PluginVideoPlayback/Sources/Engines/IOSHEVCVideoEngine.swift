#if os(iOS)
import AVFoundation
import Combine
import Foundation
import HEVCDecoder
import ProviderVideo
import SwiftUI

/// iOS 专用播放引擎：AVAssetReader 解封装 + VideoToolbox 解码 +
/// `AVSampleBufferDisplayLayer` 自绘画面。
///
/// 系统 AVPlayer 不接受 `hev1` 标记的 HEVC 流（像素格式层报 -12785），
/// 也完全不支持 MKV。这条路径自己驱动解码，因此可以吃下 mpv 能吃的格式。
/// 引擎加载失败时由 `VideoPlaybackProvider` 降级回 AVPlayer。
@MainActor
final class IOSHEVCVideoEngine: VideoEngine {
    private let player = IOSHEVCPlayer()
    private var cancellables: Set<AnyCancellable> = []

    private(set) var state: VideoPlaybackState = .idle
    private(set) var currentURL: URL?
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var rate: Float = 1
    var onEvent: ((VideoPlaybackEvent) -> Void)?

    init() {
        player.onDecoderUnavailable = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.state = .failed(error.localizedDescription)
                self.emit(.stateChanged(.failed(error.localizedDescription)))
            }
        }
        observePlayer()
    }

    func load(_ url: URL, startTime: TimeInterval?) {
        stop()
        currentURL = url
        state = .loading
        emit(.stateChanged(.loading))
        emit(.assetChanged(url))
        if let startTime, startTime > 0 {
            player.seek(to: startTime)
        } else {
            player.play(url: url)
        }
    }

    func play() {
        guard let url = currentURL else { return }
        if player.playerState == .paused {
            player.resume()
        } else {
            player.play(url: url)
        }
    }

    func pause() {
        player.pause()
    }

    func seek(to time: TimeInterval) {
        player.seek(to: time)
    }

    func stop() {
        player.stop()
        currentURL = nil
        currentTime = 0
        duration = 0
        state = .idle
        emit(.stateChanged(.idle))
        emit(.assetChanged(nil))
    }

    func setRate(_ rate: Float) {
        self.rate = rate
        emit(.rateChanged(rate))
    }

    func makeView() -> AnyView {
        AnyView(IOSHEVCVideoLayerView(player: player))
    }

    // MARK: - Observation

    private func observePlayer() {
        player.$playerState
            .sink { [weak self] playerState in
                guard let self else { return }
                let mapped: VideoPlaybackState
                switch playerState {
                case .idle: mapped = .idle
                case .loading: mapped = .loading
                case .playing: mapped = .playing
                case .paused: mapped = .paused
                case .finished: mapped = .finished
                case .failed(let message): mapped = .failed(message)
                }
                self.state = mapped
                self.emit(.stateChanged(mapped))
            }
            .store(in: &cancellables)

        player.$currentTime
            .combineLatest(player.$duration)
            .sink { [weak self] current, duration in
                guard let self else { return }
                self.currentTime = current
                self.duration = duration
                let progress = duration > 0 ? min(max(current / duration, 0), 1) : 0
                self.emit(.timeChanged(currentTime: current, duration: duration, progress: progress))
            }
            .store(in: &cancellables)
    }

    private func emit(_ event: VideoPlaybackEvent) {
        onEvent?(event)
    }
}
#endif
