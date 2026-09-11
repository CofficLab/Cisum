import Combine
import Foundation
import MagicPlayMan
import MagicKit
import ProviderPlayback

/// `PlaybackProviding` 的转发实现。
///
/// 该 Provider 将 `MagicPlayMan` 实例包装为内核可识别的 `PlaybackProviding` 协议。
/// 虽然 `MagicPlayMan` 已通过 extension 实现了 `PlaybackProviding`，但此包装器
/// 提供了更清晰的边界，方便未来扩展或替换底层播放引擎。
@MainActor
public final class PlaybackProvider: ObservableObject, PlaybackProviding, SuperLog {
    nonisolated public static let verbose = false

    private let playback: MagicPlayMan

    public init(playback: MagicPlayMan) {
        self.playback = playback
        print("\(Self.t)初始化播放 Provider")
    }

    // MARK: - PlaybackProviding 属性转发

    public var state: PlaybackState {
        playback.state
    }

    public var currentURL: URL? {
        playback.currentURL
    }

    public var currentTime: TimeInterval {
        playback.currentTime
    }

    public var duration: TimeInterval {
        playback.duration
    }

    public var progress: Double {
        playback.progress
    }

    public var playMode: MagicPlayMode {
        playback.playMode
    }

    public var likedAssets: Set<URL> {
        playback.likedAssets
    }

    public var isPlaying: Bool {
        playback.isPlaying
    }

    public var hasAsset: Bool {
        playback.hasAsset
    }

    // MARK: - PlaybackProviding 方法转发

    public func play(_ url: URL) async {
        print("\(Self.t)播放请求\(r(url.lastPathComponent))")
        await playback.play(url)
    }

    public func play(_ url: URL, startTime: TimeInterval?) async {
        print("\(Self.t)播放请求\(r(url.lastPathComponent))，起始时间: \(startTime ?? 0)")
        await playback.play(url, startTime: startTime)
    }

    public func pause() {
        print("\(Self.t)暂停播放")
        playback.pause()
    }

    public func toggle() {
        print("\(Self.t)切换播放/暂停")
        playback.toggle()
    }

    public func seek(toProgress progress: Double) {
        print("\(Self.t)跳转到进度\(r("\(progress)"))")
        playback.seek(toProgress: progress)
    }

    public func seek(toTime time: TimeInterval) {
        print("\(Self.t)跳转到时间\(r("\(time)"))")
        playback.seek(toTime: time)
    }

    public func next() {
        print("\(Self.t)下一首")
        playback.next()
    }

    public func previous() {
        print("\(Self.t)上一首")
        playback.previous()
    }

    public func setPlayMode(_ mode: MagicPlayMode) {
        print("\(Self.t)设置播放模式\(r("\(mode)"))")
        playback.setPlayMode(mode)
    }

    public func toggleCurrentLike() {
        print("\(Self.t)切换喜欢状态")
        playback.toggleCurrentLike()
    }

    public func reset() async {
        print("\(Self.t)重置播放器")
        await playback.reset()
    }

    public func togglePlayMode() {
        print("\(Self.t)切换播放模式")
        playback.togglePlayMode()
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (PlaybackProvidingEvent) -> Void
    ) -> any PlaybackProvidingObserverHandle {
        playback.addObserver(callback)
    }
}
