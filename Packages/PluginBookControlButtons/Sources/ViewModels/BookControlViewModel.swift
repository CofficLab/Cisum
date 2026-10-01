import ProviderToast
import Foundation
import MagicKit
import MagicPlayMan
import OSLog
import ProviderBook
import ProviderPlayback
import ProviderPlayback
import ProviderScene
import SwiftUI

/// 书籍播放控制的集中状态容器（迁移 Phase 5）。
///
/// 持有播放订阅、代际保护与场景激活状态，统一处理上一章/下一章、
/// 删除恢复、章节缓存失效与存储重置；取代原 `BookControlRootView`
/// 内的全部 `@State` 与事件 handler。由 `BookControlButtonsPlugin` 入口持有。
///
/// ViewModel 不直接持有 Kernel：外部播放状态由 `BookControlObserver` 回写，
/// 播放操作直接调用 `PlaybackProviding`。
@MainActor
final class BookControlViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "BookControl")
    private static let tag = "⏭️"

    private let playbackProvider: (any PlaybackProviding)?
    private let bookDisk: @MainActor () -> URL?
    @Published private(set) var isPlaying = false
    @Published private(set) var playMode: PlaybackMode = .sequence
    private let toastProvider: (any ToastProviding)?
    private var controlGeneration = 0
    private var currentScene: AppScene?
    private let targetScene: AppScene

    init(
        targetScene: AppScene,
        playbackProvider: (any PlaybackProviding)?,
        toastProvider: (any ToastProviding)? = nil,
        bookDisk: @escaping @MainActor () -> URL? = { nil }
    ) {
        self.targetScene = targetScene
        self.playbackProvider = playbackProvider
        self.toastProvider = toastProvider
        self.bookDisk = bookDisk
        if let playbackProvider {
            isPlaying = playbackProvider.isPlaying
            playMode = playbackProvider.playMode
        }
    }

    var shouldActivateControl: Bool {
        currentScene == targetScene
    }

    // MARK: - Scene activation

    func handleSceneChange(_ sceneValue: AppScene?) {
        currentScene = sceneValue
        if sceneValue == targetScene {
            activateControl()
        } else {
            deactivateControl()
        }
    }

    func applyStateChanged(_ state: PlaybackStatus) {
        isPlaying = state == .playing
    }

    func applyPlayModeChanged(_ mode: PlaybackMode) {
        playMode = mode
    }

    func toggle() {
        guard let playbackProvider else {
            reportUnavailable(operation: "toggle playback")
            return
        }
        playbackProvider.toggle()
    }

    func previous() {
        if Self.verbose {
            Self.log.debug("\(Self.tag)⏮️ Previous chapter button tapped")
        }
        guard let asset = playbackProvider?.currentURL else {
            reportUnavailable(operation: "play previous chapter", message: String(localized: "There is no current audiobook chapter.", bundle: .module))
            return
        }
        handlePreviousRequested(asset)
    }

    func next() {
        if Self.verbose {
            Self.log.debug("\(Self.tag)⏭️ Next chapter button tapped")
        }
        guard let asset = playbackProvider?.currentURL else {
            reportUnavailable(operation: "play next chapter", message: String(localized: "There is no current audiobook chapter.", bundle: .module))
            return
        }
        handleNextRequested(asset)
    }

    func togglePlayMode() {
        guard let playbackProvider else {
            reportUnavailable(operation: "change playback mode")
            return
        }
        playbackProvider.togglePlayMode()
    }

    private func activateControl() {
        guard shouldActivateControl else {
            if Self.verbose {
                Self.log.debug("\(Self.tag) Skipping audiobook playback controls: current scene is not Books")
            }
            return
        }

        guard playbackProvider != nil else { return }
    }

    private func deactivateControl() {
        controlGeneration = BookControlPlaybackRequestPolicy.generationAfterDeactivation(controlGeneration)
        BookControlChapterCache.removeAll()
    }

    // MARK: - Navigation

    func handlePreviousRequested(_ asset: URL) {
        guard shouldActivateControl, let playback = playbackProvider else { return }

        if Self.verbose {
            Self.log.debug("\(Self.tag)⏮️ Previous chapter requested")
        }

        let bookDisk = bookDisk()
        guard BookControlPlaybackRequestPolicy.shouldNavigateBookAsset(asset, bookDisk: bookDisk) else {
            return
        }

        let root = BookControlBookRootResolver.bookRoot(containing: asset, bookDisk: bookDisk)
        let playMode = playback.playMode
        let generation = controlGeneration
        Task {
            let prev = await Self.adjacentAssetLoadingChapters(
                in: root,
                current: asset,
                offset: -1,
                playMode: playMode
            )

            if let prev {
                guard BookControlPlaybackRequestPolicy.shouldApplyNavigationResult(
                    requestedAsset: asset,
                    currentAsset: playback.currentURL,
                    isSceneActive: shouldActivateControl,
                    currentGeneration: controlGeneration,
                    requestGeneration: generation
                ) else { return }
                await playback.play(prev)
                if Self.verbose {
                    Self.log.debug("\(Self.tag)✅ Playing previous chapter: \(prev.lastPathComponent)")
                }
            } else {
                Self.log.error("\(Self.tag) No previous chapter")
                presentError(title: String(localized: "Cannot play previous chapter", bundle: .module), message: String(localized: "No previous chapter is available.", bundle: .module))
            }
        }
    }

    func handleNextRequested(_ asset: URL) {
        guard shouldActivateControl, let playback = playbackProvider else { return }

        if Self.verbose {
            Self.log.debug("\(Self.tag)⏭️ Next chapter requested")
        }

        let bookDisk = bookDisk()
        guard BookControlPlaybackRequestPolicy.shouldNavigateBookAsset(asset, bookDisk: bookDisk) else {
            return
        }

        let root = BookControlBookRootResolver.bookRoot(containing: asset, bookDisk: bookDisk)
        let playMode = playback.playMode
        let generation = controlGeneration
        Task {
            let next = await Self.adjacentAssetLoadingChapters(
                in: root,
                current: asset,
                offset: 1,
                playMode: playMode
            )

            if let next {
                guard BookControlPlaybackRequestPolicy.shouldApplyNavigationResult(
                    requestedAsset: asset,
                    currentAsset: playback.currentURL,
                    isSceneActive: shouldActivateControl,
                    currentGeneration: controlGeneration,
                    requestGeneration: generation
                ) else { return }
                await playback.play(next)
                if Self.verbose {
                    Self.log.debug("\(Self.tag)✅ Playing next chapter: \(next.lastPathComponent)")
                }
            } else {
                Self.log.error("\(Self.tag) No next chapter")
                presentError(title: String(localized: "Cannot play next chapter", bundle: .module), message: String(localized: "No next chapter is available.", bundle: .module))
            }
        }
    }

    static func adjacentAssetLoadingChapters(
        in root: URL,
        current asset: URL,
        offset: Int,
        playMode: PlaybackMode
    ) async -> URL? {
        if let chapters = BookControlChapterCache.cachedChapters(in: root) {
            return BookControlChapterLoader.adjacentAsset(
                in: chapters,
                current: asset,
                offset: offset,
                playMode: playMode
            )
        }

        let chapters = await Task.detached(priority: .userInitiated) {
            BookControlChapterLoader.playableChapters(in: root)
        }.value
        BookControlChapterCache.store(chapters, in: root)

        return BookControlChapterLoader.adjacentAsset(
            in: chapters,
            current: asset,
            offset: offset,
            playMode: playMode
        )
    }

    // MARK: - DB & storage events

    func handleBookDBDeleted(deletedURLs: [URL]) {
        guard let playback = playbackProvider else { return }

        if BookControlPlaybackRequestPolicy.shouldInvalidateChapterCacheAfterDeletion(deletedURLs: deletedURLs) {
            BookControlChapterCache.removeAll()
        }

        guard BookControlPlaybackRequestPolicy.currentAssetAffectedByDeletion(
            currentAsset: playback.currentURL,
            deletedURLs: deletedURLs
        ) else { return }

        let generation = controlGeneration
        Task {
            guard BookControlPlaybackRequestPolicy.shouldApplyDeletionReset(
                currentAsset: playback.currentURL,
                deletedURLs: deletedURLs,
                currentGeneration: controlGeneration,
                requestGeneration: generation
            ) else { return }
            await playback.reset()
        }
    }

    func handleBookDBRefreshed() {
        guard BookControlPlaybackRequestPolicy.shouldInvalidateChapterCacheAfterLibraryRefresh() else {
            return
        }
        BookControlChapterCache.removeAll()
    }

    func handleStorageLocationDidReset() {
        guard let playback = playbackProvider else { return }
        guard BookControlPlaybackRequestPolicy.shouldResetForStorageLocationChange(isSceneActive: shouldActivateControl) else {
            return
        }

        BookControlChapterCache.removeAll()

        let generation = controlGeneration
        Task {
            guard BookControlPlaybackRequestPolicy.shouldApplyStorageReset(
                currentGeneration: controlGeneration,
                requestGeneration: generation,
                isSceneActive: shouldActivateControl
            ) else { return }

            await playback.reset()
        }
    }

    private func reportUnavailable(operation: String, message: String? = nil) {
        let message = message ?? String(localized: "The playback service is unavailable.", bundle: .module)
        Self.log.error("\(Self.tag) Cannot \(operation): \(message)")
        presentError(title: String(localized: "Audiobook controls unavailable", bundle: .module), message: message)
    }

    private func presentError(title: String, message: String) {
        toastProvider?.presentError(title: title, message: message)
    }
}
