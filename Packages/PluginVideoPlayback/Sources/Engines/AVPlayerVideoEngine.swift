import AVFoundation
import AVKit
import Combine
import Foundation
import ProviderVideo
import SwiftUI
#if !os(macOS)
import UIKit
#endif

/// 基于系统 `AVPlayer` 的播放引擎。
///
/// 作为兜底引擎存在：系统能解的格式（mp4 / mov / hvc1 编码的 HEVC）走它，
/// 遇到 mpv 能解但系统解不了的容器（mkv / webm / hev1 标记的 HEVC）再切到
/// mpv 引擎。
@MainActor
final class AVPlayerVideoEngine: NSObject, VideoEngine {
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?

    private(set) var state: VideoPlaybackState = .idle
    private(set) var currentURL: URL?
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var rate: Float = 1
    var onEvent: ((VideoPlaybackEvent) -> Void)?

    override init() {
        super.init()
        installTimeObserver()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func load(_ url: URL, startTime: TimeInterval?) {
        stop()
        currentURL = url
        state = .loading
        emit(.stateChanged(.loading))
        emit(.assetChanged(url))

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.rate = rate

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    if let startTime, startTime > 0 {
                        self.player.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
                    }
                    self.player.play()
                    self.state = .playing
                    self.emit(.stateChanged(.playing))
                case .failed:
                    let message = item.error?.localizedDescription ?? "Playback failed"
                    self.state = .failed(message)
                    self.emit(.stateChanged(.failed(message)))
                default:
                    break
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, let url = self.currentURL else { return }
                self.state = .finished
                self.emit(.stateChanged(.finished))
                self.emit(.didFinish(url))
            }
        }
    }

    func play() {
        player.play()
        state = .playing
        emit(.stateChanged(.playing))
    }

    func pause() {
        player.pause()
        state = .paused
        emit(.stateChanged(.paused))
    }

    func seek(to time: TimeInterval) {
        player.seek(to: CMTime(seconds: max(time, 0), preferredTimescale: 600))
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        currentURL = nil
        currentTime = 0
        duration = 0
        state = .idle
        emit(.stateChanged(.idle))
        emit(.assetChanged(nil))
    }

    func setRate(_ rate: Float) {
        self.rate = rate
        if state == .playing {
            player.rate = rate
        }
        emit(.rateChanged(rate))
    }

    func makeView() -> AnyView {
        AnyView(SystemVideoPlayerView(player: player))
    }

    // MARK: - Time observer

    private func installTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let current = time.seconds.isFinite ? time.seconds : 0
                self.currentTime = current
                let duration = self.player.currentItem?.duration.seconds ?? 0
                self.duration = duration.isFinite ? duration : 0
                let progress = self.duration > 0 ? min(max(current / self.duration, 0), 1) : 0
                self.emit(.timeChanged(currentTime: current, duration: self.duration, progress: progress))
            }
        }
    }

    private func emit(_ event: VideoPlaybackEvent) {
        onEvent?(event)
    }
}

#if os(macOS)
private struct SystemVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = player
    }
}
#else
private struct SystemVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> SystemPlayerLayerView {
        let view = SystemPlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ view: SystemPlayerLayerView, context: Context) {
        view.playerLayer.player = player
    }
}

private final class SystemPlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
#endif
