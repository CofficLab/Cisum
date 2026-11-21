#if os(macOS)
import Combine
import CisumMPVKit
import Foundation
import ProviderVideo
import SwiftUI

/// 基于 mpv 的播放引擎（仅 macOS）。
///
/// mpv 自带 FFmpeg，格式覆盖面比系统 AVPlayer 宽得多（mkv / webm / hev1
/// 标记的 HEVC 等），并可用 `hwdec=videotoolbox` 走硬解。
@MainActor
final class MPVVideoEngine: VideoEngine {
    private let player = MPVPlayer()
    private var cancellables: Set<AnyCancellable> = []

    private(set) var state: VideoPlaybackState = .idle
    private(set) var currentURL: URL?
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var rate: Float = 1
    var onEvent: ((VideoPlaybackEvent) -> Void)?

    init() {
        observePlayer()
    }

    func load(_ url: URL, startTime: TimeInterval?) {
        currentURL = url
        state = .loading
        emit(.stateChanged(.loading))
        emit(.assetChanged(url))

        player.play(url: url)

        // mpv 的 loadfile 是异步的：文件就绪后才会真正开始播放，
        // 因此起播位置要等状态变成 playing 之后再 seek。
        if let startTime, startTime > 0 {
            pendingStartTime = startTime
        }
    }

    private var pendingStartTime: TimeInterval?

    func play() {
        player.resume()
        state = .playing
        emit(.stateChanged(.playing))
    }

    func pause() {
        player.pause()
        state = .paused
        emit(.stateChanged(.paused))
    }

    func seek(to time: TimeInterval) {
        player.seek(to: time)
        currentTime = time
    }

    func stop() {
        player.stop()
        currentURL = nil
        currentTime = 0
        duration = 0
        pendingStartTime = nil
        state = .idle
        emit(.stateChanged(.idle))
        emit(.assetChanged(nil))
    }

    func setRate(_ rate: Float) {
        self.rate = rate
        player.playbackRate = Double(rate)
        emit(.rateChanged(rate))
    }

    func makeView() -> AnyView {
        AnyView(MPVVideoView(player: player))
    }

    // MARK: - Observation

    private func observePlayer() {
        player.$playerState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playerState in
                guard let self else { return }
                let mapped = Self.map(playerState)
                self.state = mapped
                self.emit(.stateChanged(mapped))

                if mapped == .playing, let startTime = self.pendingStartTime {
                    self.pendingStartTime = nil
                    self.player.seek(to: startTime)
                    self.currentTime = startTime
                }
                if case .finished = mapped, let url = self.currentURL {
                    self.emit(.didFinish(url))
                }
            }
            .store(in: &cancellables)

        player.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                guard let self else { return }
                self.currentTime = time
                let progress = self.duration > 0 ? min(max(time / self.duration, 0), 1) : 0
                self.emit(.timeChanged(currentTime: time, duration: self.duration, progress: progress))
            }
            .store(in: &cancellables)

        player.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                guard let self else { return }
                self.duration = duration
            }
            .store(in: &cancellables)
    }

    private static func map(_ state: MPVPlayerState) -> VideoPlaybackState {
        switch state {
        case .idle: .idle
        case .loading: .loading
        case .playing: .playing
        case .paused: .paused
        case .finished: .finished
        case .failed(let message): .failed(message)
        }
    }

    private func emit(_ event: VideoPlaybackEvent) {
        onEvent?(event)
    }
}
#endif
