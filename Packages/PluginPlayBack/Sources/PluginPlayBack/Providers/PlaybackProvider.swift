import Combine
import Foundation
import MagicKit
import MagicPlayMan
import ProviderPlayback
import SwiftUI
import os

/// `PlaybackProviding` 的具体实现。
///
/// 这是 PluginPlayBack 的内部适配层：底层播放器的事件在这里转换为 Provider
/// 事件，再由各功能插件自己的 Observer 消费。ProviderPlayback 不知道本类型。
@MainActor
public final class PlaybackProvider: PlaybackProviding, PlaybackMediaProviding, SuperLog {
    nonisolated public static let verbose = false
    nonisolated public static let logger = Logger(subsystem: "com.coffic.cisum", category: "plugin.playback")

    private let playback: MagicPlayMan
    private let observers = PlaybackObserverStore<PlaybackProvidingEvent>()
    private var cancellables: Set<AnyCancellable> = []
    private let navigationSubscriberID: UUID

    public init(playback: MagicPlayMan) {
        self.playback = playback
        navigationSubscriberID = playback.events.addNavigationSubscriber(name: "PluginPlayBack.Provider")
        installEngineObservers()
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化播放 Provider")
        }
    }

    /// 解除底层播放器事件订阅。由插件生命周期显式调用，避免在非隔离的
    /// `deinit` 中访问主线程隔离的 `MagicPlayMan`。
    public func shutdown() {
        cancellables.removeAll()
        playback.events.removeNavigationSubscriber(id: navigationSubscriberID)
    }

    // MARK: - PlaybackProviding data

    public var state: PlaybackStatus { playback.state.providerStatus }
    public var currentURL: URL? { playback.currentURL }
    public var currentTime: TimeInterval { playback.currentTime }
    public var duration: TimeInterval { playback.duration }
    public var progress: Double { playback.progress }
    public var playMode: PlaybackMode { playback.playMode.providerMode }
    public var likedAssets: Set<URL> { playback.likedAssets }
    public var isPlaying: Bool { playback.state.isPlaying }
    public var hasAsset: Bool { playback.hasAsset }

    // MARK: - PlaybackProviding actions

    public func play(_ url: URL) async {
        if Self.verbose {
            Self.logger.info("\(Self.t)🚀 play: \(url.lastPathComponent)")
        }
        await playback.play(url, reason: "PlaybackProvider.play")
    }

    public func play(_ url: URL, startTime: TimeInterval?) async {
        if Self.verbose {
            Self.logger.info("\(Self.t)🚀 play from \(startTime ?? 0)s: \(url.lastPathComponent)")
        }
        await playback.play(
            url,
            autoPlay: false,
            startTime: startTime,
            reason: "PlaybackProvider.playFromTime"
        )
    }

    public func pause() {
        if Self.verbose {
            let asset = playback.currentURL?.lastPathComponent ?? "nil"
            Self.logger.info("\(Self.t)⏸️ pause; asset=\(asset)")
        }
        playback.pause(reason: "PlaybackProvider.pause")
    }

    public func toggle() {
        if Self.verbose {
            let asset = playback.currentURL?.lastPathComponent ?? "nil"
            let state = String(describing: playback.state)
            let isPlaying = playback.state.isPlaying
            Self.logger.info("\(Self.t)⏯️ toggle; asset=\(asset), isPlaying=\(isPlaying), state=\(state)")
        }
        playback.toggle(reason: "PlaybackProvider.toggle")
    }
    public func seek(toProgress progress: Double) {
        let normalizedProgress = min(max(progress, 0), 1)
        playback.seek(
            time: duration * normalizedProgress,
            reason: "PlaybackProvider.seekProgress"
        )
    }
    public func seek(toTime time: TimeInterval) {
        playback.seek(time: time, reason: "PlaybackProvider.seekTime")
    }
    public func next() {
        if Self.verbose {
            Self.logger.info("\(Self.t)➡️ next")
        }
        playback.next()
    }
    public func previous() {
        if Self.verbose {
            Self.logger.info("\(Self.t)⬅️ previous")
        }
        playback.previous()
    }
    public func setPlayMode(_ mode: PlaybackMode) {
        if Self.verbose {
            Self.logger.info("\(Self.t)🔁 setPlayMode: \(mode.rawValue)")
        }
        playback.changePlayMode(MagicPlayMode(rawValue: mode.rawValue) ?? .sequence)
    }
    public func toggleCurrentLike() { playback.toggleLike() }
    public func reset() async {
        if Self.verbose {
            Self.logger.info("\(Self.t)🔄 reset")
        }
        await playback.reset(reason: "PlaybackProvider.reset")
    }
    public func togglePlayMode() {
        if Self.verbose {
            let mode = playback.playMode.rawValue
            Self.logger.info("\(Self.t)🔁 togglePlayMode; current=\(mode)")
        }
        playback.togglePlayMode()
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (PlaybackProvidingEvent) -> Void
    ) -> any PlaybackProvidingObserverHandle {
        observers.add(callback)
    }

    // MARK: - PlaybackMediaProviding

    public func makeMediaView() -> AnyView {
        AnyView(playback.makeHeroView(verbose: false, avatarShape: .roundedRectangle(cornerRadius: 8)))
    }

    public func localizedStateText(for state: PlaybackStatus) -> String {
        state.magicPlayState.localizedStateText(localization: playback.localization)
    }

    // MARK: - Engine event bridge

    private func installEngineObservers() {
        playback.events.onStateChanged
            .sink { [weak self] state in self?.send(.stateChanged(state.providerStatus)) }
            .store(in: &cancellables)

        playback.events.onCurrentURLChanged
            .sink { [weak self] url in self?.send(.assetChanged(url)) }
            .store(in: &cancellables)

        playback.events.onPlayModeChanged
            .sink { [weak self] mode in self?.send(.playModeChanged(mode.providerMode)) }
            .store(in: &cancellables)

        playback.events.onLikeStatusChanged
            .sink { [weak self] event in
                self?.send(.likeStatusChanged(asset: event.asset, isLiked: event.isLiked))
                self?.send(.likedAssetsChanged(self?.playback.likedAssets ?? []))
            }
            .store(in: &cancellables)

        playback.events.onPreviousRequested
            .sink { [weak self] asset in self?.send(.previousRequested(asset)) }
            .store(in: &cancellables)

        playback.events.onNextRequested
            .sink { [weak self] asset in self?.send(.nextRequested(asset)) }
            .store(in: &cancellables)

        playback.events.onNavigationFailed
            .sink { [weak self] failure in self?.send(.navigationFailed(failure.providerFailure)) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .playManTimeUpdate, object: playback)
            .compactMap { notification -> (TimeInterval, Double)? in
                guard let currentTime = notification.userInfo?["currentTime"] as? TimeInterval,
                      let progress = notification.userInfo?["progress"] as? Double else { return nil }
                return (currentTime, progress)
            }
            .sink { [weak self] currentTime, progress in
                self?.send(.timeChanged(currentTime: currentTime, progress: progress))
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .playManDurationChanged, object: playback)
            .compactMap { $0.userInfo?["duration"] as? TimeInterval }
            .sink { [weak self] duration in self?.send(.durationChanged(duration)) }
            .store(in: &cancellables)
    }

    private func send(_ event: PlaybackProvidingEvent) {
        observers.send(event)
        observers.send(.snapshotChanged(snapshot))
    }
}

private extension PlaybackState {
    var providerStatus: PlaybackStatus {
        switch self {
        case .idle: return .idle
        case .loading(let loading):
            return .loading(loading.providerStatus)
        case .willPlay: return .willPlay
        case .playing: return .playing
        case .paused: return .paused
        case .stopped: return .stopped
        case .failed(let error): return .failed(error.providerFailure)
        }
    }
}

private extension PlaybackState.LoadingState {
    var providerStatus: PlaybackStatus.LoadingStatus {
        switch self {
        case .connecting: return .connecting
        case .preparing: return .preparing
        case .buffering: return .buffering
        case .downloading(let progress): return .downloading(progress)
        }
    }
}

private extension PlaybackState.PlaybackError {
    var providerFailure: PlaybackFailure {
        switch self {
        case .noAsset: return .noAsset
        case .invalidAsset: return .invalidAsset
        case .networkError(let message): return .networkError(message)
        case .playbackError(let message): return .playbackError(message)
        case .unsupportedFormat(let ext): return .unsupportedFormat(ext)
        case .invalidURL(let url): return .invalidURL(url)
        }
    }
}

private extension PlaybackStatus {
    var magicPlayState: PlaybackState {
        switch self {
        case .idle: return .idle
        case .loading(let loading): return .loading(loading.magicPlayState)
        case .willPlay: return .willPlay
        case .playing: return .playing
        case .paused: return .paused
        case .stopped: return .stopped
        case .failed(let failure): return .failed(failure.magicPlayState)
        }
    }
}

private extension PlaybackStatus.LoadingStatus {
    var magicPlayState: PlaybackState.LoadingState {
        switch self {
        case .connecting: return .connecting
        case .preparing: return .preparing
        case .buffering: return .buffering
        case .downloading(let progress): return .downloading(progress)
        }
    }
}

private extension PlaybackFailure {
    var magicPlayState: PlaybackState.PlaybackError {
        switch self {
        case .noAsset: return .noAsset
        case .invalidAsset: return .invalidAsset
        case .networkError(let message): return .networkError(message)
        case .playbackError(let message): return .playbackError(message)
        case .unsupportedFormat(let ext): return .unsupportedFormat(ext)
        case .invalidURL(let url): return .invalidURL(url)
        }
    }
}

private extension MagicPlayMode {
    var providerMode: PlaybackMode {
        PlaybackMode(rawValue: rawValue) ?? .sequence
    }
}

private extension MagicPlayMan.PlaybackEvents.NavigationFailure {
    var providerFailure: PlaybackNavigationFailure {
        PlaybackNavigationFailure(
            direction: direction == .previous ? .previous : .next,
            reason: reason
        )
    }
}
