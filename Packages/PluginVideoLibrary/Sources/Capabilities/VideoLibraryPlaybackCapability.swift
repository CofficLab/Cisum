import Foundation
import ProviderVideo
import SwiftUI

/// 视频库消费的播放能力。
@MainActor
final class VideoLibraryPlaybackCapability {
    private weak var playback: (any VideoPlaybackProviding)?

    init(playback: (any VideoPlaybackProviding)?) {
        self.playback = playback
    }

    var state: VideoPlaybackState { playback?.state ?? .idle }
    var currentURL: URL? { playback?.currentURL }
    var currentTime: TimeInterval { playback?.currentTime ?? 0 }
    var duration: TimeInterval { playback?.duration ?? 0 }
    var progress: Double { playback?.progress ?? 0 }
    var rate: Float { playback?.rate ?? 1 }
    var hasAsset: Bool { playback?.hasAsset ?? false }

    func play(_ url: URL, startTime: TimeInterval?) { playback?.play(url, startTime: startTime) }
    func pause() { playback?.pause() }
    func toggle() { playback?.toggle() }
    func stop() { playback?.stop() }
    func seek(to time: TimeInterval) { playback?.seek(toTime: time) }
    func setRate(_ rate: Float) { playback?.setRate(rate) }
    func makePlayerView() -> AnyView { playback?.makePlayerView() ?? AnyView(EmptyView()) }

    @discardableResult
    func addObserver(
        _ callback: @escaping (VideoPlaybackEvent) -> Void
    ) -> any VideoPlaybackObserverHandle {
        playback?.addObserver(callback) ?? NoopVideoPlaybackObserverHandle()
    }
}

/// 播放能力缺失时的空实现。
final class NoopVideoPlaybackObserverHandle: VideoPlaybackObserverHandle {
    func cancel() {}
}
