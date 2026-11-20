import Foundation
import MediaPlayer

/// 锁屏 / 控制中心的播放信息协调器。
///
/// 把当前视频的标题、时长、进度与播放状态同步到 `MPNowPlayingInfoCenter`，
/// 并接管控制中心的播放、暂停与跳转指令。
@MainActor
final class VideoNowPlayingCoordinator {
    /// 播放指令。
    var onPlay: (() -> Void)?
    /// 暂停指令。
    var onPause: (() -> Void)?
    /// 跳转指令（相对当前进度的秒数）。
    var onSeek: ((TimeInterval) -> Void)?

    private var currentTitle = ""
    private var lastUpdateAt: Date?
    private var isActive = false

    /// 同步播放信息。
    ///
    /// - Parameters:
    ///   - title: 当前视频标题。
    ///   - duration: 总时长（秒）。
    ///   - currentTime: 当前进度（秒）。
    ///   - rate: 播放倍速。
    ///   - isPlaying: 是否正在播放。
    func update(
        title: String,
        duration: TimeInterval,
        currentTime: TimeInterval,
        rate: Float,
        isPlaying: Bool
    ) {
        currentTitle = title

        guard duration > 0 else { return }
        let now = Date()
        if let lastUpdateAt, now.timeIntervalSince(lastUpdateAt) < 1, isActive {
            return
        }
        lastUpdateAt = now
        isActive = true

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(currentTime, 0),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
        ]
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = rate

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    /// 清除播放信息。
    func clear() {
        isActive = false
        lastUpdateAt = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    /// 安装控制中心指令。
    func activateCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.onPlay?()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.isPlaying {
                self.onPause?()
            } else {
                self.onPlay?()
            }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.onSeek?(15)
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.onSeek?(-15)
            return .success
        }
    }

    /// 当前是否处于播放中（由调用方在每次更新时同步）。
    private var isPlaying = false

    /// 同步播放 / 暂停状态。
    func setPlaying(_ playing: Bool) {
        isPlaying = playing
    }
}
