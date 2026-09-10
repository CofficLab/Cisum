import Foundation
import MagicKit
import MagicPlayMan
import OSLog
import ProviderBook
import ProviderBook
import ProviderScene
import ProviderToast
import SwiftUI

/// 书籍播放控制的集中状态容器（迁移 Phase 5）。
///
/// 持有播放订阅、代际保护与场景激活状态，统一处理上一章/下一章、
/// 删除恢复、章节缓存失效与存储重置；取代原 `BookControlRootView`
/// 内的全部 `@State` 与事件 handler。由 `BookControlButtonsPlugin` 入口持有。
///
/// ViewModel 不直接持有 Kernel 或具体 Provider：外部播放状态由
/// `BookControlObserver` 通过 `apply...` 方法回写，外部播放操作通过
/// `BookControlPlaybackCapability` 执行。
@MainActor
final class BookControlViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "BookControl")
    private static let tag = "⏭️"

    private let playbackCapability: (any BookControlPlaybackCapability)?
    private let bookDisk: @MainActor () -> URL?
    @Published private(set) var isPlaying = false
    @Published private(set) var playMode: MagicPlayMode = .sequence
    private let toastProvider: (any ToastProviding)?
    private var controlGeneration = 0
    private var currentScene: AppScene?
    private let targetScene: AppScene

    init(
        targetScene: AppScene,
        playbackCapability: (any BookControlPlaybackCapability)?,
        toastProvider: (any ToastProviding)? = nil,
        bookDisk: @escaping @MainActor () -> URL? = { nil }
    ) {
        self.targetScene = targetScene
        self.playbackCapability = playbackCapability
        self.toastProvider = toastProvider
        self.bookDisk = bookDisk
        if let playbackCapability {
            isPlaying = playbackCapability.isPlaying
            playMode = playbackCapability.playMode
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

    func applyStateChanged(_ state: PlaybackState) {
        isPlaying = state == .playing
    }

    func applyPlayModeChanged(_ mode: MagicPlayMode) {
        playMode = mode
    }

    func toggle() {
        guard let playbackCapability else {
            reportUnavailable(operation: "toggle playback")
            return
        }
        playbackCapability.toggle()
    }

    func previous() {
        if Self.verbose {
            Self.log.debug("\(Self.tag)⏮️ Previous chapter button tapped")
        }
        guard let asset = playbackCapability?.currentURL else {
            reportUnavailable(operation: "play previous chapter", message: "There is no current audiobook chapter.")
            return
        }
        handlePreviousRequested(asset)
    }

    func next() {
        if Self.verbose {
            Self.log.debug("\(Self.tag)⏭️ Next chapter button tapped")
        }
        guard let asset = playbackCapability?.currentURL else {
            reportUnavailable(operation: "play next chapter", message: "There is no current audiobook chapter.")
            return
        }
        handleNextRequested(asset)
    }

    func togglePlayMode() {
        guard let playbackCapability else {
            reportUnavailable(operation: "change playback mode")
            return
        }
        playbackCapability.togglePlayMode()
    }

    private func activateControl() {
        guard shouldActivateControl else {
            if Self.verbose {
                Self.log.debug("\(Self.tag) Skipping audiobook playback controls: current scene is not Books")
            }
            return
        }

        guard playbackCapability != nil else { return }
    }

    private func deactivateControl() {
        controlGeneration = BookControlPlaybackRequestPolicy.generationAfterDeactivation(controlGeneration)
        BookControlChapterCache.removeAll()
    }

    // MARK: - Navigation

    func handlePreviousRequested(_ asset: URL) {
        guard shouldActivateControl, let playback = playbackCapability else { return }

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
                await playback.play(prev, reason: "handlePreviousRequested")
                if Self.verbose {
                    Self.log.debug("\(Self.tag)✅ Playing previous chapter: \(prev.lastPathComponent)")
                }
            } else {
                Self.log.error("\(Self.tag) No previous chapter")
                presentError(title: "Cannot play previous chapter", message: "No previous chapter is available.")
            }
        }
    }

    func handleNextRequested(_ asset: URL) {
        guard shouldActivateControl, let playback = playbackCapability else { return }

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
                await playback.play(next, reason: "handleNextRequested")
                if Self.verbose {
                    Self.log.debug("\(Self.tag)✅ Playing next chapter: \(next.lastPathComponent)")
                }
            } else {
                Self.log.error("\(Self.tag) No next chapter")
                presentError(title: "Cannot play next chapter", message: "No next chapter is available.")
            }
        }
    }

    static func adjacentAssetLoadingChapters(
        in root: URL,
        current asset: URL,
        offset: Int,
        playMode: MagicPlayMode
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
        guard let playback = playbackCapability else { return }

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
            await playback.reset(reason: "BookControlViewModel.deletedCurrentAsset")
        }
    }

    func handleBookDBRefreshed() {
        guard BookControlPlaybackRequestPolicy.shouldInvalidateChapterCacheAfterLibraryRefresh() else {
            return
        }
        BookControlChapterCache.removeAll()
    }

    func handleStorageLocationDidReset() {
        guard let playback = playbackCapability else { return }
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

            await playback.reset(reason: "BookControlViewModel.storageLocationDidReset")
        }
    }

    private func reportUnavailable(operation: String, message: String? = nil) {
        let message = message ?? "The playback service is unavailable."
        Self.log.error("\(Self.tag) Cannot \(operation): \(message)")
        presentError(title: "Audiobook controls unavailable", message: message)
    }

    private func presentError(title: String, message: String) {
        toastProvider?.presentError(title: title, message: message)
    }
}
