import AVFoundation
import Foundation
import MagicKit
import ProviderAudioLibrary
import OSLog
import ProviderAudioLike
import ProviderPlayback
import ProviderScene
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

/// 音频播放进度的集中状态容器（迁移 Phase 5）。
///
/// 持有恢复代际与场景激活状态，统一处理进度恢复、URL变化持久化、
/// 暂停保存、删除清理、Widget 同步与存储重置；取代原
/// `AudioProgressRootView` 内的全部 `@State` 与事件 handler。
/// 由 `AudioProgressPlugin` 入口持有。
///
/// 外部播放状态由 `AudioProgressObserver` 通过事件回写，外部播放操作通过
/// `PlaybackProgressCapability` 执行（见 Capabilities 目录）。
///
/// ## 未收窄的依赖
/// `audioLike` 仍以闭包形式直接持有 `any AudioLikeProviding`：它只在恢复进度时
/// 被调用一次（读一次 `isLiked`），无订阅、不持有、不重试，符合 Capabilities
/// 规范的「不必建」判据。为一次性的同步读取套一层 Adapter 属于仪式成本。
@MainActor
final class AudioProgressViewModel: ObservableObject, SuperLog {
    private static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "AudioProgress")
    private static let tag = "💾"

    /// 播放与音频库能力（Capabilities 目录收窄），`weak` 持有。
    private weak var playback: (any PlaybackProgressCapability)?
    private var restoreGeneration = 0
    private var currentScene: AppScene?
    private let audioScene: AppScene
    private let library: any ProgressAudioLibraryCapability
    private let audioLike: @MainActor () -> (any AudioLikeProviding)?
    private let saveWidgetData: @Sendable (String, String, Bool, Data?) -> Void

    init(
        audioScene: AppScene,
        playback: (any PlaybackProgressCapability)?,
        library: any ProgressAudioLibraryCapability,
        audioLike: @escaping @MainActor () -> (any AudioLikeProviding)?,
        saveWidgetData: @escaping @Sendable (String, String, Bool, Data?) -> Void
    ) {
        self.audioScene = audioScene
        self.playback = playback
        self.library = library
        self.audioLike = audioLike
        self.saveWidgetData = saveWidgetData
    }

    var shouldActivateProgress: Bool {
        currentScene == audioScene
    }

    // MARK: - Scene activation

    func handleSceneChange(from oldScene: AppScene?, to newScene: AppScene?) {
        currentScene = newScene

        if newScene != audioScene {
            restoreGeneration += 1
        }

        if AudioProgressPersistencePolicy.shouldPersistWhenSceneChanges(
            from: oldScene?.rawValue,
            to: newScene?.rawValue,
            audioSceneName: audioScene.rawValue
        ) {
            persistCurrentTime(reason: "handleCurrentSceneChanged")
        }

        restorePlayingIfNeeded(for: newScene)
    }

    func handleOnAppear() {
        restorePlayingIfNeeded(for: currentScene)
    }

    func handleOnDisappear() {
        restoreGeneration += 1
        guard shouldActivateProgress else { return }
        persistCurrentTime(reason: "handleOnDisappear")
    }

    private func restorePlayingIfNeeded(for sceneValue: AppScene?) {
        guard sceneValue == audioScene else { return }
        restorePlaying()
    }

    // MARK: - Restore

    private func restorePlaying() {
        guard let playback else { return }
        var assetTarget: URL?
        var timeTarget: TimeInterval = 0
        var liked = false
        let startingAsset = playback.currentURL
        restoreGeneration += 1
        let generation = restoreGeneration

        Task { @MainActor in
            guard isCurrentRestoreRequest(generation) else { return }

            guard library.isAvailable else {
                if Self.verbose {
                    Self.log.error("\(Self.tag)❌ Failed to get AudioRepo")
                }
                return
            }

            if let url = AudioStateRepo.getCurrent() {
                let isPlayable = await library.contains(url) && isPlayableAudioURL(url)

                if isPlayable {
                    assetTarget = url
                    liked = await audioLike()?.isLiked(url: url) ?? false

                    if let time = AudioStateRepo.getCurrentTime() {
                        timeTarget = time
                    }

                    if Self.verbose {
                        Self.log.debug("\(Self.tag)✅ Restored playback: \(url.lastPathComponent) @ \(timeTarget)s")
                    }
                } else {
                    if AudioProgressPersistencePolicy.shouldClearRestoredCurrentURL(storedURL: url, isPlayable: isPlayable) {
                        AudioStateRepo.storeCurrent(nil)
                    }
                    if AudioProgressPersistencePolicy.shouldClearRestoredCurrentTime(storedURL: url, isPlayable: isPlayable) {
                        AudioStateRepo.storeCurrentTime(0)
                    }

                    if Self.verbose {
                        Self.log.debug("\(Self.tag)⚠️ Last played file no longer exists: \(url.lastPathComponent)")
                    }

                    if let firstUrl = await firstPlayableAudio(in: library) {
                        assetTarget = firstUrl
                        liked = await audioLike()?.isLiked(url: firstUrl) ?? false

                        if Self.verbose {
                            Self.log.debug("\(Self.tag)✅ Playing first track: \(firstUrl.lastPathComponent)")
                        }
                    }
                }
            } else {
                if Self.verbose {
                    Self.log.debug("\(Self.tag)⚠️ No previous playback record")
                }
            }

            if let asset = assetTarget {
                let currentAsset = playback.currentURL

                // 恢复文件已被并发加载（如 PlaybackSceneObserver 的场景恢复，
                // 或用户已手动加载同一文件）：只补进度位置，不重复加载，
                // 避免「无 startTime 的重载」把已恢复的进度清零。
                if AudioProgressPersistencePolicy.representsSameFile(asset, currentAsset) {
                    guard isCurrentRestoreRequest(generation) else { return }
                    if timeTarget > 0 {
                        playback.seek(toTime: timeTarget)
                    }
                    guard isCurrentRestoreRequest(generation) else { return }
                    setLike(liked, using: playback)
                    return
                }

                guard AudioProgressPersistencePolicy.shouldApplyRestoreResult(
                    startingAsset: startingAsset,
                    currentAsset: currentAsset
                ) else { return }

                if AudioProgressPersistencePolicy.shouldPlayRestoredAsset(
                    restoredAsset: asset,
                    currentAsset: currentAsset
                ) {
                    guard isCurrentRestoreRequest(generation) else { return }
                    await playback.play(asset, startTime: timeTarget)
                }
                guard isCurrentRestoreRequest(generation) else { return }
                setLike(liked, using: playback)
            } else {
                if Self.verbose {
                    Self.log.debug("\(Self.tag)⚠️ No playback data to restore")
                }
            }
        }
    }

    private func isCurrentRestoreRequest(_ generation: Int) -> Bool {
        AudioProgressPersistencePolicy.shouldApplyRestoreRequest(
            currentGeneration: restoreGeneration,
            requestGeneration: generation,
            isSceneActive: shouldActivateProgress
        )
    }

    private func setLike(_ liked: Bool, using playback: any PlaybackProgressCapability) {
        let isCurrentlyLiked = playback.currentURL.map { playback.likedAssets.contains($0) } ?? false
        if isCurrentlyLiked != liked {
            playback.toggleCurrentLike()
        }
    }

    private func firstPlayableAudio(in library: any ProgressAudioLibraryCapability) async -> URL? {
        let urls = await library.allURLs(reason: "AudioProgressViewModel.firstPlayableAudio")
        return urls.first(where: isPlayableAudioURL)
    }

    private func isPlayableAudioURL(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
            && !url.isFolder
            && AudioPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Playback events

    func handlePlayManStateChanged(_ isPlaying: Bool) {
        guard shouldActivateProgress, let playback = playback else { return }

        syncToWidget(url: playback.currentURL, isPlaying: isPlaying)

        if playback.state == .paused {
            persistCurrentTime(reason: "handlePlayManStateChanged")
        }
    }

    func handlePlayManAssetChanged(_ url: URL?) {
        guard shouldActivateProgress, let playback = playback else { return }

        syncToWidget(url: url, isPlaying: playback.state == .playing)
        let generation = restoreGeneration

        Task {
            guard AudioProgressPersistencePolicy.shouldApplyCurrentURLChange(
                requestedURL: url,
                currentAsset: playback.currentURL,
                currentGeneration: restoreGeneration,
                requestGeneration: generation,
                isSceneActive: shouldActivateProgress
            ) else { return }

            let storedURL = AudioStateRepo.getCurrent()
            let urlToStore = AudioProgressPersistencePolicy.currentURLToStore(
                url,
                storedURL: storedURL,
                supportedExtensions: AudioPluginInfo.supportedExtensions
            )
            AudioStateRepo.storeCurrent(urlToStore)
            if AudioProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(from: storedURL, to: urlToStore) {
                AudioStateRepo.storeCurrentTime(0)
            }
        }
    }

    func handleDBDeleted(deletedURLs: [URL]) {
        guard AudioProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
            storedURL: AudioStateRepo.getCurrent(),
            deletedURLs: deletedURLs
        ) else { return }

        AudioStateRepo.storeCurrent(nil)
        AudioStateRepo.storeCurrentTime(0)
    }

    func handleStorageLocationDidReset() {
        guard shouldActivateProgress else { return }

        if Self.verbose {
            Self.log.debug("\(Self.tag)🛑 Storage location reset; recording playback progress")
        }

        persistCurrentTime(reason: "handleStorageLocationDidReset")
    }

    // MARK: - Widget & persistence

    private func syncToWidget(url: URL?, isPlaying: Bool) {
        guard let playback else { return }
        guard let url = url else {
            guard AudioProgressPersistencePolicy.shouldApplyWidgetClearResult(currentAsset: playback.currentURL) else {
                return
            }

            saveWidgetData("Not Playing", "Cisum", false, nil)
            return
        }

        let title = url.deletingPathExtension().lastPathComponent
        let artist = "Cisum"

        Task {
            var coverArt: Data? = nil
            let asset = AVAsset(url: url)
            do {
                let metadata = try await asset.load(.commonMetadata)
                if let artworkItem = metadata.first(where: { $0.commonKey == .commonKeyArtwork }),
                   let data = try await artworkItem.load(.value) as? Data {
                    coverArt = data
                }
            } catch {
                if Self.verbose {
                    Self.log.error("\(Self.tag) Failed to load artwork: \(error.localizedDescription)")
                }
            }

            guard AudioProgressPersistencePolicy.shouldApplyWidgetMetadataResult(
                requestedAsset: url,
                currentAsset: playback.currentURL
            ) else { return }

            saveWidgetData(title, artist, playback.state == .playing, coverArt)
        }
    }

    private func persistCurrentTime(reason: String) {
        guard let playback else { return }
        AudioStateRepo.storeCurrentTime(playback.currentTime)

        if Self.verbose {
            Self.log.debug("\(Self.tag)💾 (\(reason)) Saved playback progress: \(playback.currentTime)s")
        }
    }
}
