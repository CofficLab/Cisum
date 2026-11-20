import Combine
import Foundation
import ProviderVideo
import SwiftUI

/// `VideoPlaybackProviding` 的具体实现。
///
/// 引擎选择：
/// - macOS 走 mpv（格式覆盖最广，HEVC 走 VideoToolbox 硬解）；
/// - iOS 走系统 AVPlayer，遇到 AVPlayer 解不了的编码（`hev1` 标记的 HEVC）
///   再切到 VideoToolbox 自绘路径。
///
/// 引擎加载失败时自动降级到兜底引擎，保证「至少能出声/出画面」。
@MainActor
public final class VideoPlaybackProvider: VideoPlaybackProviding {
    private var engine: VideoEngine
    private var observers: [VideoPlaybackObserver] = []
    private var didFallback = false

    public init() {
        engine = Self.makePreferredEngine()
        engine.onEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    public var state: VideoPlaybackState { engine.state }
    public var currentURL: URL? { engine.currentURL }
    public var currentTime: TimeInterval { engine.currentTime }
    public var duration: TimeInterval { engine.duration }
    public var progress: Double {
        guard engine.duration > 0 else { return 0 }
        return min(max(engine.currentTime / engine.duration, 0), 1)
    }
    public var rate: Float { engine.rate }
    public var hasAsset: Bool { engine.currentURL != nil }

    public func play(_ url: URL, startTime: TimeInterval?) {
        didFallback = false
        engine.load(url, startTime: startTime)
    }

    public func pause() { engine.pause() }
    public func toggle() {
        switch engine.state {
        case .playing: engine.pause()
        default: engine.play()
        }
    }
    public func stop() { engine.stop() }
    public func seek(toTime time: TimeInterval) { engine.seek(to: time) }
    public func setRate(_ rate: Float) { engine.setRate(rate) }

    public func makePlayerView() -> AnyView {
        engine.makeView()
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (VideoPlaybackEvent) -> Void
    ) -> any VideoPlaybackObserverHandle {
        let observer = VideoPlaybackObserver(callback: callback)
        observers.append(observer)
        return observer
    }

    // MARK: - Engine handling

    private func handle(_ event: VideoPlaybackEvent) {
        if case .stateChanged(.failed) = event, !didFallback {
            didFallback = true
            fallbackToAVPlayer()
            return
        }
        notify(event)
    }

    /// 首选引擎失败时降级到系统播放器。
    private func fallbackToAVPlayer() {
        let current = engine.currentURL
        let fallback = AVPlayerVideoEngine()
        fallback.onEvent = { [weak self] event in
            self?.notify(event)
        }
        engine = fallback
        guard let current else { return }
        engine.load(current, startTime: nil)
        engine.play()
    }

    private func notify(_ event: VideoPlaybackEvent) {
        observers.removeAll { $0.isCancelled }
        for observer in observers {
            observer.invoke(event)
        }
    }

    private static func makePreferredEngine() -> VideoEngine {
        #if os(macOS)
        return MPVVideoEngine()
        #elseif os(iOS)
        return IOSHEVCVideoEngine()
        #else
        return AVPlayerVideoEngine()
        #endif
    }
}

/// 播放事件的观察句柄。
final class VideoPlaybackObserver: VideoPlaybackObserverHandle {
    private let callback: (VideoPlaybackEvent) -> Void
    private var cancelled = false

    init(callback: @escaping (VideoPlaybackEvent) -> Void) {
        self.callback = callback
    }

    var isCancelled: Bool { cancelled }

    func cancel() { cancelled = true }

    func invoke(_ event: VideoPlaybackEvent) {
        guard !cancelled else { return }
        callback(event)
    }
}
