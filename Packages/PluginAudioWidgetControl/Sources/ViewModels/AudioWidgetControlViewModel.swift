import CoreFoundation
import Foundation
import MagicKit
import OSLog
import ProviderPlayback

/// Widget 控制命令的集中状态容器（迁移 Phase 4）。
///
/// 持有播放导航任务队列，处理 Widget 发来的播放/暂停/上一首/下一首
/// 命令；取代原 `AudioWidgetControlRootView` 内的 `@State navigationTask`
/// 与全部命令处理逻辑。
@MainActor
final class AudioWidgetControlViewModel: ObservableObject, SuperLog {
    private static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "AudioWidgetControl")

    private let playbackProvider: (any PlaybackProviding)?
    private var navigationTask: Task<Void, Never>?

    private let nextAsset: AudioWidgetAdjacentAssetProvider
    private let previousAsset: AudioWidgetAdjacentAssetProvider
    private let firstAsset: AudioWidgetFirstAssetProvider
    private let lastAsset: AudioWidgetLastAssetProvider

    init(
        playbackProvider: (any PlaybackProviding)?,
        nextAsset: @escaping AudioWidgetAdjacentAssetProvider,
        previousAsset: @escaping AudioWidgetAdjacentAssetProvider,
        firstAsset: @escaping AudioWidgetFirstAssetProvider,
        lastAsset: @escaping AudioWidgetLastAssetProvider
    ) {
        self.playbackProvider = playbackProvider
        self.nextAsset = nextAsset
        self.previousAsset = previousAsset
        self.firstAsset = firstAsset
        self.lastAsset = lastAsset
    }

    func handleWidgetCommands() {
        let sharedDefaults = UserDefaults(suiteName: AudioWidgetCommandStore.suiteName)
        guard let sharedDefaults else { return }

        consumeWidgetCommand(key: "widgetPlayPauseTrigger", from: sharedDefaults, handler: handlePlayPause)
        consumeWidgetCommand(key: "widgetNextTrigger", from: sharedDefaults, handler: handleNext)
        consumeWidgetCommand(key: "widgetPreviousTrigger", from: sharedDefaults, handler: handlePrevious)
    }

    private func consumeWidgetCommand(
        key: String,
        from sharedDefaults: UserDefaults,
        handler: (Int) -> Void
    ) {
        let count = AudioWidgetCommandStore.withLock {
            AudioWidgetPlaybackRequestPolicy.commandCount(
                from: sharedDefaults.object(forKey: key)
            )
        }
        guard count > 0 else { return }

        handler(count)

        AudioWidgetCommandStore.withLock {
            let remainingCount = AudioWidgetPlaybackRequestPolicy.remainingCommandCount(
                afterConsuming: count,
                storedValue: sharedDefaults.object(forKey: key)
            )
            if remainingCount > 0 {
                sharedDefaults.set(remainingCount, forKey: key)
            } else {
                sharedDefaults.removeObject(forKey: key)
            }
            sharedDefaults.synchronize()
        }
    }

    private func handlePlayPause(count: Int) {
        guard let playback = playbackProvider else { return }
        switch AudioWidgetPlaybackRequestPolicy.playPauseAction(
            currentState: playback.state,
            commandCount: count
        ) {
        case .play:
            playback.toggle()
        case .pause:
            playback.pause()
        case .none:
            break
        }
    }

    private func handleNext(count: Int) {
        guard let playback = playbackProvider else { return }
        enqueueNavigationTask { [weak self] in
            guard let self else { return }
            for _ in 0..<count {
                guard let asset = playback.currentURL else { return }

                do {
                    if let next = try await self.nextAsset(asset, Self.verbose) {
                        guard AudioWidgetPlaybackRequestPolicy.shouldApplyNavigationResult(
                            requestedAsset: asset,
                            currentAsset: playback.currentURL
                        ) else {
                            return
                        }
                        await playback.play(next)
                    } else if playback.playMode == .repeatAll, let first = try await self.firstAsset() {
                        guard AudioWidgetPlaybackRequestPolicy.shouldApplyNavigationResult(
                            requestedAsset: asset,
                            currentAsset: playback.currentURL
                        ) else {
                            return
                        }
                        await playback.play(first)
                    }
                } catch {
                    Self.log.error("Failed to get next asset: \(error.localizedDescription)")
                    return
                }
            }
        }
    }

    private func handlePrevious(count: Int) {
        guard let playback = playbackProvider else { return }
        enqueueNavigationTask { [weak self] in
            guard let self else { return }
            for _ in 0..<count {
                guard let asset = playback.currentURL else { return }

                do {
                    if let previous = try await self.previousAsset(asset, Self.verbose) {
                        guard AudioWidgetPlaybackRequestPolicy.shouldApplyNavigationResult(
                            requestedAsset: asset,
                            currentAsset: playback.currentURL
                        ) else {
                            return
                        }
                        await playback.play(previous)
                    } else if playback.playMode == .repeatAll, let last = try await self.lastAsset() {
                        guard AudioWidgetPlaybackRequestPolicy.shouldApplyNavigationResult(
                            requestedAsset: asset,
                            currentAsset: playback.currentURL
                        ) else {
                            return
                        }
                        await playback.play(last)
                    }
                } catch {
                    Self.log.error("Failed to get previous asset: \(error.localizedDescription)")
                    return
                }
            }
        }
    }

    private func enqueueNavigationTask(_ operation: @escaping @MainActor () async -> Void) {
        let previousTask = navigationTask
        navigationTask = Task { @MainActor in
            if AudioWidgetPlaybackRequestPolicy.shouldWaitForPreviousNavigation(hasPreviousTask: previousTask != nil) {
                await previousTask?.value
            }
            await operation()
        }
    }
}
