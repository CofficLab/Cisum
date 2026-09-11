import AVFoundation
import Foundation
import CisumUIComponents
import OSLog
import SwiftUI

enum MagicPlayManPlaybackRequestPolicy {
    static func basicValidationError(for url: URL) -> PlaybackState.PlaybackError? {
        guard url.isFileExist else {
            return .invalidAsset
        }

        guard url.isFileURL || url.isNetworkURL else {
            return .invalidURL(url.scheme ?? "nil")
        }

        guard url.isVideo || url.isAudio else {
            return .unsupportedFormat(url.pathExtension)
        }

        return nil
    }
}

enum MagicPlayManSeekPolicy {
    static func normalizedTime(_ time: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard time.isFinite else { return 0 }

        let lowerBoundedTime = max(time, 0)
        guard duration.isFinite, duration > 0 else {
            return lowerBoundedTime
        }

        return min(lowerBoundedTime, duration)
    }

    static func normalizedStartTime(_ time: TimeInterval?, duration: TimeInterval) -> TimeInterval? {
        guard let time else { return nil }
        let normalizedTime = normalizedTime(time, duration: duration)
        return normalizedTime > 0 ? normalizedTime : nil
    }
}

enum MagicPlayManControlInputPolicy {
    static func normalizedVolume(_ volume: Float) -> Float {
        guard volume.isFinite else { return 0 }
        return max(0, min(1, volume))
    }

    static func normalizedSkipInterval(_ seconds: TimeInterval) -> TimeInterval {
        guard seconds.isFinite else { return 0 }
        return max(seconds, 0)
    }
}

public extension MagicPlayMan {
    /// 设置播放模式
    /// - Parameter mode: 要设置的播放模式
    func changePlayMode(_ mode: MagicPlayMode) {
        Task { @MainActor in
            setPlayMode(mode)
        }
        os_log("\(self.t)Playback mode set to: \(mode.displayName)")
    }

    /// 清理所有缓存
    /// 清除媒体资源缓存，释放磁盘空间
    func clearCache() {
        do {
            try cache?.clear()
            os_log("\(self.t)🗑️ Cache cleared")
        } catch {
            if verbose { os_log("\(self.t)❌ Failed to clear cache: \(error.localizedDescription)") }
        }
    }

    /// 播放下一首
    /// 根据导航订阅者决定播放行为
    func next() {
        guard hasAsset else {
            reportNavigationFailure(.next, reason: "No media is currently loaded")
            return
        }

        guard let currentAsset = currentURL else {
            reportNavigationFailure(.next, reason: "The current media URL is unavailable")
            return
        }

        guard events.hasNavigationSubscribers else {
            reportNavigationFailure(.next, reason: "No playback navigation subscriber is registered")
            return
        }

        if self.verbose {
            os_log("\(self.t)➡️ Next track requested: \(currentAsset.lastPathComponent)")
        }

        // 如果有订阅者，发送请求下一首事件
        events.onNextRequested.send(currentAsset)
    }

    /// 暂停播放
    /// - Parameters:
    ///   - reason: 更新原因
    func pause(reason: String) {
        guard hasAsset else { return }

        if self.verbose {
            os_log("\(self.t)⏸️ (\(reason)) Pause")
        }

        _player.pause()
    }

    /// 开始播放当前加载的媒体资源，如果已播放完毕则从头开始播放
    /// - Parameters:
    ///   - reason: 原因
    func playCurrent(reason: String) {
        guard let url = currentURL else {
            os_log(.error, "\(self.t)Cannot play: no asset loaded")
            return
        }

        // 加载失败时 resetPlayerItemAfterFailedPlayback 会清空 item 但保留 currentURL，
        // 此时 AVPlayer.play() 对 nil item 是静默无效的（表现为「点播放没反应、进度不动」）。
        // 检测到 item 缺失就重新加载，让「点击播放」自动退化为「重试」。
        guard _player.currentItem != nil else {
            if self.verbose {
                os_log("\(self.t)🔄 (\(reason)) Player item is missing, reloading: \(url.lastPathComponent)")
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.play(url, autoPlay: true, reason: reason + ".reload")
            }
            return
        }

        if MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: currentTime, duration: duration) {
            self.seek(time: 0, reason: self.className + ".playCurrent")
        }

        if self.verbose {
            os_log("\(self.t)▶️ (\(reason)) Play current: \(url.lastPathComponent)")
        }

        // 让内核开始播放，MagicPlayMan初始化时监听了内核状态
        _player.play()
    }

    /// 加载并播放一个 URL
    /// - Parameters:
    ///   - url: 要播放的媒体 URL
    ///   - autoPlay: 是否自动开始播放，默认为 true
    ///   - startTime: 加载完成后定位到的起始时间，默认为 nil
    ///   - reason: 更新原因
    @MainActor
    public func play(_ url: URL, autoPlay: Bool = true, startTime: TimeInterval? = nil, reason: String) async {
        if self.verbose {
            os_log("\(self.t)🚀 (\(reason)) Play: \(url.title), AutoPlay: \(autoPlay)")
        }

        let requestGeneration = beginPlayRequest()

        // 立即暂停当前播放，避免显示新歌信息但还在放旧歌
        _player.pause()
        setCurrentDownloadObservers(nil)

        // 先记录用户请求的资源。即使后续校验或播放失败，调用方仍需要知道
        // 用户最后选择的是哪个文件，以便列表 selection 和 Hero 标题保持稳定。
        self.setCurrentURL(url)

        if let validationError = MagicPlayManPlaybackRequestPolicy.basicValidationError(for: url) {
            await resetPlayerItemAfterFailedPlayback(reason: reason + ".validation")
            setState(.failed(validationError), reason: reason + ".play")
            return
        }

        // iCloud 未下载（dataless 占位）文件：本地只有占位元数据，AVFoundation 读取会失败
        // （AVError -11800），从而被下面的可播性校验误判为 invalidAsset。
        // 必须在可播性校验之前先确保内容落到本地。
        if url.isFileURL, !url.hasLocalContent {
            if self.verbose {
                os_log("\(self.t)☁️ (\(reason)) iCloud asset is not available locally, downloading: \(url.lastPathComponent)")
            }

            setState(.loading(.downloading(0)), reason: reason + ".iCloudDownload")

            let progressTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled, let self else { return }
                    guard self.isCurrentPlayRequest(requestGeneration) else { return }

                    let progress = MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(
                        url.getDownloadProgressSnapshot(verbose: false)
                    )
                    self.setState(.loading(.downloading(progress)), reason: reason + ".iCloudDownload")
                }
            }
            defer { progressTask.cancel() }

            do {
                try await url.ensureLocalAvailability()
            } catch {
                os_log(.error, "\(self.t)❌ (\(reason)) iCloud download failed: \(error.localizedDescription)")
                await resetPlayerItemAfterFailedPlayback(reason: reason + ".iCloudDownload")
                setState(.failed(.networkError(error.localizedDescription)), reason: reason + ".play")
                return
            }

            // 下载期间用户可能已经切歌
            guard isCurrentPlayRequest(requestGeneration),
                  MagicPlayManAssetIdentity.representsSameAsset(self.currentURL, url) else {
                return
            }
        }

        if url.isFileURL {
            let asset = AVURLAsset(url: url)
            do {
                guard try await asset.load(.isPlayable) else {
                    guard isCurrentPlayRequest(requestGeneration) else { return }
                    await resetPlayerItemAfterFailedPlayback(reason: reason + ".unplayable")
                    setState(.failed(.invalidAsset), reason: reason + ".play")
                    return
                }
            } catch {
                guard isCurrentPlayRequest(requestGeneration) else { return }
                await resetPlayerItemAfterFailedPlayback(reason: reason + ".unplayable")
                setState(.failed(.invalidAsset), reason: reason + ".play")
                return
            }
        }

        guard isCurrentPlayRequest(requestGeneration) else { return }

        // 切换资源时清掉旧资源时长，避免新资源加载期间显示上一首的总时长。
        self.setDuration(0)
        self.setProgress(0)
        self.setCurrentTime(0, reason: reason + ".play")

        guard MagicPlayManAssetIdentity.representsSameAsset(self.currentURL, url) else {
            return
        }

        self.setState(.loading(.preparing), reason: reason + ".play")

        if url.isNetworkURL {
            let item = AVPlayerItem(url: url)
            load(item, autoPlay: autoPlay, startTime: startTime, requestGeneration: requestGeneration, reason: reason)
            return
        }

        downloadAndCache(url, reason: reason) { [weak self] in
            guard let self = self else { return }

            // 关键：确保当前仍是同一个 URL (用户可能在下载期间切歌了)
            guard self.isCurrentPlayRequest(requestGeneration),
                  MagicPlayManAssetIdentity.representsSameAsset(self.currentURL, url) else {
                if self.verbose {
                    os_log("\(self.t)⚠️ URL changed during download, ignoring playback request for: \(url.title)")
                }
                return
            }

            let item = AVPlayerItem(url: url)
            self.load(item, autoPlay: autoPlay, startTime: startTime, requestGeneration: requestGeneration, reason: reason)
        }
    }

    @MainActor
    /// 清理失败的 AVPlayer item，但保留当前资源 URL 作为用户选择。
    func resetPlayerItemAfterFailedPlayback(reason: String) async {
        setCurrentDownloadObservers(nil)
        _player.replaceCurrentItem(with: nil)
        setCurrentTime(0, reason: reason)
        setDuration(0)
        setProgress(0)
    }

    /// 播放上一首
    /// 根据导航订阅者决定播放行为
    func previous() {
        guard hasAsset else {
            reportNavigationFailure(.previous, reason: "No media is currently loaded")
            return
        }

        guard let currentAsset = currentURL else {
            reportNavigationFailure(.previous, reason: "The current media URL is unavailable")
            return
        }

        guard events.hasNavigationSubscribers else {
            reportNavigationFailure(.previous, reason: "No playback navigation subscriber is registered")
            return
        }

        if self.verbose {
            os_log("\(self.t)⬅️ Previous track requested: \(currentAsset.lastPathComponent)")
        }

        // 如果有订阅者，发送请求上一首事件
        events.onPreviousRequested.send(currentAsset)
    }

    private func reportNavigationFailure(
        _ direction: PlaybackEvents.NavigationDirection,
        reason: String
    ) {
        let label = direction == .next ? "next" : "previous"
        os_log(.error, "\(self.t)❌ Cannot navigate \(label): \(reason)")
        events.onNavigationFailed.send(.init(direction: direction, reason: reason))
    }

    /// 跳转到指定时间
    /// - Parameters:
    ///   - time: 目标时间位置（秒）
    ///   - reason: 更新原因
    func seek(time: TimeInterval, reason: String) {
        guard hasAsset else {
            os_log(.error, "\(self.t)⚠️ Cannot seek: no asset loaded")
            return
        }

        let targetTime = MagicPlayManSeekPolicy.normalizedTime(time, duration: duration)
        if verbose {
            os_log("\(self.t)⏩ (\(reason)) Seeking to \(Int(targetTime))s")
        }
        seekLoadedItem(time: targetTime, reason: reason)
    }

    /// 设置当前资源的喜欢状态
    /// - Parameters:
    ///   - isLiked: 是否喜欢
    ///   - reason: 更新原因
    func setLike(_ isLiked: Bool, reason: String) {
        guard let asset = currentURL else {
            if verbose { os_log("\(self.t)⚠️ Cannot set like: no asset loaded") }
            return
        }

        var newLikedAssets = likedAssets
        if isLiked {
            newLikedAssets.removeSameAsset(as: asset)
            newLikedAssets.insert(asset)
            if verbose {
                os_log("\(self.t)❤️ (\(reason)) Added to liked: \(asset.title)")
            }
        } else {
            newLikedAssets.removeSameAsset(as: asset)
            if verbose {
                os_log("\(self.t)💔 (\(reason)) Removed from liked: \(asset.title)")
            }
        }

        setLikedAssets(newLikedAssets)
        // 通知订阅者喜欢状态变化
        events.onLikeStatusChanged.send((asset: asset, isLiked: isLiked))
        updateNowPlayingInfo(includeThumbnail: false, reason: reason + ".setLike")
    }

    /// 静音控制
    /// - Parameter muted: 是否启用静音模式
    func setMuted(_ muted: Bool) {
        _player.isMuted = muted
        os_log("\(self.t)\(muted ? "🔇 Audio muted" : "🔊 Audio unmuted")")
    }

    /// 设置详细日志模式
    /// - Parameter enabled: 是否启用详细的调试日志输出
    func setVerboseMode(_ enabled: Bool) {
        self.verbose = enabled
        os_log("\(self.t)🔍 Verbose mode \(enabled ? "enabled" : "disabled")")
    }

    /// 调整音量
    /// - Parameter volume: 目标音量值，范围 0.0-1.0
    func setVolume(_ volume: Float) {
        let normalizedVolume = MagicPlayManControlInputPolicy.normalizedVolume(volume)
        _player.volume = normalizedVolume
        os_log("\(self.t)🔊 Volume set to \(Int(normalizedVolume * 100))%")
    }

    /// 快退指定时间
    /// - Parameter seconds: 快退的秒数，默认为10秒
    func skipBackward(_ seconds: TimeInterval = 10) {
        let interval = MagicPlayManControlInputPolicy.normalizedSkipInterval(seconds)
        seek(time: max(currentTime - interval, 0), reason: "skipBackward")
        os_log("\(self.t)⏪ Skipped backward \(Int(interval))s")
    }

    /// 快进指定时间
    /// - Parameter seconds: 快进的秒数，默认为10秒
    func skipForward(_ seconds: TimeInterval = 10) {
        let interval = MagicPlayManControlInputPolicy.normalizedSkipInterval(seconds)
        seek(
            time: MagicPlayManSeekPolicy.normalizedTime(currentTime + interval, duration: duration),
            reason: "skipForward"
        )
        os_log("\(self.t)⏩ Skipped forward \(Int(interval))s")
    }

    /// 停止播放
    /// 停止当前播放并将播放位置重置到开始位置
    @MainActor
    func stop(reason: String) async {
        beginPlayRequest()

        _player.pause()
        setCurrentDownloadObservers(nil)
        await _player.seek(to: .zero)
        setCurrentTime(0, reason: reason)
        setProgress(0)
        setState(.stopped, reason: reason)

        if self.verbose {
            os_log("\(self.t)⏹️ (\(reason)) Stopped playback")
        }
    }

    /// 重置播放器
    /// 完全卸载当前资源，将播放器恢复到初始状态
    /// - Parameter reason: 重置原因（用于日志记录）
    @MainActor
    func reset(reason: String) async {
        beginPlayRequest()

        // 停止播放
        _player.pause()
        setCurrentDownloadObservers(nil)

        // 清除 AVPlayer 的当前项
        _player.replaceCurrentItem(with: nil)

        // 重置所有状态
        setCurrentURL(nil)
        setCurrentTime(0, reason: reason)
        setDuration(0)
        setProgress(0)
        setState(.idle, reason: reason)

        if self.verbose {
            os_log("\(self.t)🔄 (\(reason)) Player reset to initial state")
        }
    }

    /// 切换当前资源的喜欢状态
    /// 在喜欢和不喜欢之间切换当前播放资源的喜欢状态
    func toggleLike() {
        guard let asset = currentURL else { return }
        setLike(!likedAssets.containsSameAsset(as: asset), reason: "toggleLike")
    }

    /// 切换播放状态
    /// 根据当前播放状态在播放/暂停之间切换，如果当前正在播放则暂停，如果当前已暂停或停止则开始播放
    /// - Parameter reason: 切换操作的原因描述
    func toggle(reason: String) {
        if self.verbose {
            os_log("\(self.t)⏯️ (\(reason)) Toggle requested; state=\(self.state.stateText), asset=\(self.currentURL?.lastPathComponent ?? "nil")")
        }
        switch state {
        case .playing:
            pause(reason: reason)
        case .paused, .stopped:
            playCurrent(reason: reason)
        case .failed:
            // 失败后再次点击播放视为重试：playCurrent 会重新加载已缺失的 item。
            playCurrent(reason: reason + ".retry")
        case .loading, .idle, .willPlay:
            // 在这些状态下不执行任何操作
            if verbose { os_log("\(self.t)Cannot toggle playback in current state: \(self.state.stateText)") }
            break
        }
    }
}

private extension MagicPlayMan {
    @MainActor
    func load(
        _ item: AVPlayerItem,
        autoPlay: Bool,
        startTime: TimeInterval?,
        requestGeneration: UInt64,
        reason: String
    ) {
        guard isCurrentPlayRequest(requestGeneration) else { return }

        _player.replaceCurrentItem(with: item)

        guard let startTime = MagicPlayManSeekPolicy.normalizedStartTime(startTime, duration: duration) else {
            if autoPlay {
                playCurrent(reason: reason + ".play")
            }
            return
        }

        seekLoadedItem(time: startTime, reason: reason + ".load") { [weak self] in
            guard let self else { return }
            guard self.isCurrentPlayRequest(requestGeneration) else { return }
            if autoPlay {
                self.playCurrent(reason: reason + ".play")
            }
        }
    }

    func seekLoadedItem(time: TimeInterval, reason: String, completion: (() -> Void)? = nil) {
        let targetTime = CMTime(seconds: time, preferredTimescale: 600)
        _player.seek(to: targetTime) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // 更新 Now Playing Info 中的播放时间，否则控制中心/锁屏界面的进度条不会更新
                self.updateNowPlayingInfo(includeThumbnail: true, reason: reason + ".seek")
                completion?()
            }
        }
    }
}

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
}
