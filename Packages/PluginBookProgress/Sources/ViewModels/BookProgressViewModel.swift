import Foundation
import MagicKit
import MagicPlayMan
import OSLog
import ProviderScene
import ProviderPlayback
import SwiftUI

/// 书籍播放进度的集中状态容器（迁移 Phase 5）。
///
/// 持有播放订阅、恢复代际与场景激活状态，统一处理进度恢复、URL变化持久化、
/// 暂停保存与删除清理；取代原 `BookProgressRootView` 内的全部
/// `@State` 与事件 handler。由 `BookProgressPlugin` 入口持有。
///
/// ViewModel 不直接持有 Kernel：外部播放状态由 `BookProgressObserver` 通过事件回写，
/// 播放、书库与提示操作经 Capabilities 目录的能力执行（见 `BookProgressPlaybackCapability`
/// / `BookProgressLibraryCapability` / `BookProgressToastCapability`）。
/// 原先注入的 6 个书库闭包已收敛为单一能力，解析与降级语义由 Adapter 统一承担。
@MainActor
final class BookProgressViewModel: ObservableObject, SuperLog {
    private static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "BookProgress")
    private static let tag = "📖"

    /// 播放、书库与提示能力（Capabilities 目录收窄），`weak` 持有。
    private weak var playback: (any BookProgressPlaybackCapability)?
    private weak var library: (any BookProgressLibraryCapability)?
    private weak var toast: (any BookProgressToastCapability)?
    private var restoreGeneration = 0
    private var currentScene: AppScene?
    private let targetScene: AppScene

    init(
        targetScene: AppScene,
        playback: (any BookProgressPlaybackCapability)?,
        library: (any BookProgressLibraryCapability)?,
        toast: (any BookProgressToastCapability)? = nil
    ) {
        self.targetScene = targetScene
        self.playback = playback
        self.library = library
        self.toast = toast
    }

    var shouldActivateProgress: Bool {
        currentScene == targetScene
    }

    // MARK: - Scene activation

    func handleSceneChange(_ sceneValue: AppScene?) {
        currentScene = sceneValue
        if sceneValue == targetScene {
            activateProgress()
        } else {
            deactivateProgress()
        }
    }

    private func activateProgress() {
        guard shouldActivateProgress else { return }

        if Self.verbose {
            Self.log.debug("\(Self.tag)👀 View appeared, restoring audiobook progress")
        }

        restoreBookProgress()

        guard playback != nil else { return }
    }

    private func deactivateProgress() {
        restoreGeneration += 1

        persistCurrentProgress(reason: "deactivateProgress")
    }

    // MARK: - Restore

    private func restoreBookProgress() {
        guard let playback = playback else { return }
        let startingAsset = playback.currentURL
        restoreGeneration += 1
        let generation = restoreGeneration

        Task { @MainActor in
            guard isCurrentRestoreRequest(generation) else { return }

            if let url = library?.currentBookURL() {
                let isPlayable = isPlayableBookURL(url)

                guard isPlayable else {
                    if BookProgressPersistencePolicy.shouldClearRestoredCurrentURL(currentURL: url, isPlayable: isPlayable) {
                        library?.storeCurrentBookURL(nil)
                    }
                    if BookProgressPersistencePolicy.shouldClearRestoredCurrentTime(currentURL: url, isPlayable: isPlayable) {
                        library?.storeCurrentBookTime(0)
                    }

                    if Self.verbose {
                        Self.log.debug("\(Self.tag)⚠️ Skipping stale audiobook progress: \(url.shortPath())")
                    }
                    return
                }

                let currentAsset = playback.currentURL

                // 恢复文件已被并发加载（如 PlaybackSceneObserver 的场景恢复，
                // 或用户已手动加载同一文件）：只补进度位置，不重复加载，
                // 避免「无 startTime 的重载」把已恢复的进度清零。
                if BookProgressFileLocationIdentity.representsSameFile(url, currentAsset) {
                    guard isCurrentRestoreRequest(generation) else { return }
                    let time = library?.currentBookTime() ?? 0
                    if time > 0 {
                        playback.seek(toTime: time)
                    }
                    if Self.verbose {
                        Self.log.debug("\(Self.tag)✅ Restored audiobook progress (seek only): \(url.lastPathComponent) @ \(time)s")
                    }
                    return
                }

                guard BookProgressPersistencePolicy.shouldApplyRestoreResult(
                    startingAsset: startingAsset,
                    currentAsset: currentAsset
                ) else { return }

                if BookProgressPersistencePolicy.shouldPlayRestoredAsset(
                    restoredAsset: url,
                    currentAsset: currentAsset
                ) {
                    guard isCurrentRestoreRequest(generation) else { return }
                    await playback.play(url, startTime: library?.currentBookTime() ?? 0)
                }

                if Self.verbose {
                    Self.log.debug("\(Self.tag)✅ Restored audiobook progress: \(url.lastPathComponent)")
                }
            }
        }
    }

    private func isCurrentRestoreRequest(_ generation: Int) -> Bool {
        BookProgressPersistencePolicy.shouldApplyRestoreRequest(
            currentGeneration: restoreGeneration,
            requestGeneration: generation,
            isSceneActive: shouldActivateProgress
        )
    }

    private func isPlayableBookURL(_ url: URL) -> Bool {
        BookProgressPersistencePolicy.shouldAcceptBookURL(url, bookDisk: library?.bookDisk)
    }

    // MARK: - URL change & persistence

    func handleCurrentURLChanged(_ url: URL?) {
        guard shouldActivateProgress else { return }
        guard let playback = playback else { return }

        let storedURL = library?.currentBookURL()

        guard let snapshot = BookProgressPersistencePolicy.currentURLChangeSnapshot(currentURL: url) else {
            if Self.verbose {
                Self.log.debug("\(Self.tag)📖 URL cleared")
            }

            library?.storeCurrentBookURL(nil)
            if BookProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(from: storedURL, to: nil) {
                library?.storeCurrentBookTime(0)
            }
            return
        }

        let url = snapshot.currentURL
        let bookDisk = library?.bookDisk

        if Self.verbose {
            Self.log.debug("\(Self.tag)📖 URL changed -> \(url.shortPath())")
        }

        let generation = restoreGeneration
        Task {
            guard BookProgressPersistencePolicy.shouldApplyCurrentURLChange(
                requestedURL: snapshot.currentURL,
                currentAsset: playback.currentURL,
                currentGeneration: restoreGeneration,
                requestGeneration: generation,
                isSceneActive: shouldActivateProgress
            ) else { return }

            guard BookProgressPersistencePolicy.shouldPersistCurrentURLChange(from: storedURL, to: url) else { return }

            guard BookProgressPersistencePolicy.shouldAcceptBookURL(url, bookDisk: bookDisk) else {
                if Self.verbose {
                    Self.log.debug("\(Self.tag)⚠️ Skipping audio outside the audiobook library: \(url.shortPath())")
                }
                return
            }

            library?.storeCurrentBookURL(url)
            if BookProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(from: storedURL, to: url) {
                library?.storeCurrentBookTime(0)
            }

            await saveBookState(currentURL: snapshot.currentURL, time: snapshot.time)

            if url.isNotDownloaded {
                do {
                    try await url.download(reason: "BookProgressViewModel")
                    guard BookProgressPersistencePolicy.shouldApplyCurrentURLChange(
                        requestedURL: snapshot.currentURL,
                        currentAsset: playback.currentURL,
                        currentGeneration: restoreGeneration,
                        requestGeneration: generation,
                        isSceneActive: shouldActivateProgress
                    ) else { return }
                    if Self.verbose {
                        Self.log.debug("\(Self.tag)✅ Audiobook file download completed")
                    }
                } catch {
                    guard BookProgressPersistencePolicy.shouldApplyCurrentURLChange(
                        requestedURL: snapshot.currentURL,
                        currentAsset: playback.currentURL,
                        currentGeneration: restoreGeneration,
                        requestGeneration: generation,
                        isSceneActive: shouldActivateProgress
                    ) else { return }
                    Self.log.error("\(Self.tag)❌ Audiobook file download failed: \(error.localizedDescription)")
                    toast?.error(String(localized: "Download failed: \(error.localizedDescription)", bundle: .module))
                }
            }
        }
    }

    func handlePlayManStateChanged(_ isPlaying: Bool) {
        guard shouldActivateProgress, let playback = playback, playback.state == .paused else { return }

        persistCurrentProgress(reason: "handlePlayManStateChanged")
    }

    func handleBookDBDeleted(deletedURLs: [URL]) {
        guard BookProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
            storedURL: library?.currentBookURL(),
            deletedURLs: deletedURLs
        ) else { return }

        library?.storeCurrentBookURL(nil)
        library?.storeCurrentBookTime(0)
    }

    private func persistCurrentProgress(reason: String) {
        guard let playback = playback else { return }
        guard BookProgressPersistencePolicy.shouldPersistPlaybackProgress(
            currentURL: playback.currentURL,
            bookDisk: library?.bookDisk
        ) else { return }

        guard let snapshot = BookProgressPersistencePolicy.snapshot(
            currentURL: playback.currentURL,
            currentTime: playback.currentTime,
            trigger: .playbackPositionChanged
        ) else { return }

        library?.storeCurrentBookTime(snapshot.time ?? 0)

        Task {
            await saveBookState(currentURL: snapshot.currentURL, time: snapshot.time)
        }

        if Self.verbose {
            Self.log.debug("\(Self.tag)💾 (\(reason)) Saved audiobook playback time: \(snapshot.time ?? 0)s")
        }
    }

    private func saveBookState(currentURL: URL, time: TimeInterval?) async {
        guard let bookURL = await findBookForURL(currentURL) else {
            if Self.verbose {
                Self.log.debug("\(Self.tag)⚠️ Could not find the audiobook for \(currentURL.lastPathComponent)")
            }
            return
        }

        do {
            try await library?.savePlaybackState(for: bookURL, currentURL: currentURL, time: time)
            if Self.verbose {
                if let time {
                    Self.log.debug("\(Self.tag)💾 Saved audiobook state: \(bookURL.lastPathComponent) -> \(currentURL.lastPathComponent) @ \(time)s")
                } else {
                    Self.log.debug("\(Self.tag)💾 Saved audiobook current chapter: \(bookURL.lastPathComponent) -> \(currentURL.lastPathComponent)")
                }
            }
        } catch {
            // 保存失败必须留痕：静默吞掉会让进度丢落后无法追查。
            Self.log.error("\(Self.tag)❌ Failed to save book state: \(error.localizedDescription)")
        }
    }

    private func findBookForURL(_ url: URL) async -> URL? {
        if let bookURL = BookProgressBookLookup.bookURL(for: url, bookDisk: library?.bookDisk) {
            return bookURL
        }

        if Self.verbose {
            let parentURL = bookRoot(containing: url)
            do {
                _ = try FileManager.default.contentsOfDirectory(at: parentURL, includingPropertiesForKeys: nil)
            } catch {
                Self.log.debug("\(Self.tag)⚠️ Could not read directory contents: \(error.localizedDescription)")
            }

            Self.log.debug("\(Self.tag)⚠️ Parent path is not an audiobook directory: \(parentURL.shortPath())")
        }

        return nil
    }

    private func bookRoot(containing url: URL) -> URL {
        BookProgressBookRootResolver.bookRoot(containing: url, bookDisk: library?.bookDisk)
    }
}
