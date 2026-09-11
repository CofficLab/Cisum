import Combine
import MagicPlayMan
import ProviderPlayback

/// `PlaybackProviding` 的转发实现。
///
/// 该 Provider 将 `MagicPlayMan` 实例转发为内核可识别的 `PlaybackProviding` 协议，
/// 使插件能够以统一的方式向内核注册播放能力。
@MainActor
public final class PlaybackProvider: ObservableObject, PlaybackProviding {
    private let playback: MagicPlayMan

    public init(playback: MagicPlayMan) {
        self.playback = playback
    }

    public var currentURL: URL? {
        playback.currentURL
    }

    public var isPlaying: Bool {
        playback.isPlaying
    }

    public var state: PlaybackState {
        playback.state
    }

    public var currentTime: TimeInterval {
        playback.currentTime
    }

    public var duration: TimeInterval {
        playback.duration
    }

    public func play(_ url: URL, autoPlay: Bool) async throws {
        try await playback.play(url, autoPlay: autoPlay)
    }

    public func pause() {
        playback.pause()
    }

    public func resume() {
        playback.resume()
    }

    public func stop() {
        playback.stop()
    }

    public func seek(to time: TimeInterval) {
        playback.seek(to: time)
    }

    public func setVolume(_ volume: Float) {
        playback.setVolume(volume)
    }

    public func setRate(_ rate: Float) {
        playback.setRate(rate)
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (PlaybackProvidingEvent) -> Void
    ) -> any PlaybackProvidingObserverHandle {
        playback.addObserver(callback)
    }
}
