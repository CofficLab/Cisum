import Combine
import Foundation
import MagicPlayMan
import MagicKit
import os
import ProviderScene
import ProviderPlayback
import ProviderToast

/// 播放控制按钮的状态容器。
///
/// 外部播放和场景事件由 Observer 回写；上一首/下一首等外部操作通过
/// 插件入口组装的 Capability 执行。ViewModel 不持有 Kernel 或具体 Provider。
@MainActor
final class ControlButtonsViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = true
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "ControlButtons")

    @Published private(set) var isPlaying = false
    @Published private(set) var playMode: MagicPlayMode = .sequence
    private let playbackCapability: (any PlaybackCapability)?
    private let navigationCapability: (any NavigationCapability)?
    private let toastProvider: (any ToastProviding)?
    private let targetScene: AppScene
    private var currentScene: AppScene?
    private var controlGeneration = 0
    /// 最近一次已提示过的失败，用于去重，避免状态抖动反复弹窗。
    private var lastPresentedFailure: PlaybackFailure?

    init(
        playbackCapability: (any PlaybackCapability)?,
        navigationCapability: (any NavigationCapability)? = nil,
        toastProvider: (any ToastProviding)? = nil,
        targetScene: AppScene = .music,
        currentScene: AppScene? = nil
    ) {
        self.playbackCapability = playbackCapability
        self.navigationCapability = navigationCapability
        self.toastProvider = toastProvider
        self.targetScene = targetScene
        self.currentScene = currentScene
        if let playbackCapability {
            isPlaying = playbackCapability.isPlaying
            playMode = playbackCapability.playMode
        }
    }

    var shouldActivateControl: Bool {
        currentScene == targetScene
    }

    func applyStateChanged(_ state: PlaybackStatus) {
        isPlaying = state == .playing

        guard case .failed(let failure) = state else {
            lastPresentedFailure = nil
            return
        }

        // 失败必须让用户看得见：之前 .failed 只折算成 isPlaying = false，
        // 表现为「点了播放没反应，也没有任何提示」。
        guard failure != lastPresentedFailure else { return }
        lastPresentedFailure = failure

        let message = Self.failureDescription(failure)
        Self.log.error("\(Self.t)❌ Playback failed: \(message)")
        presentError(
            title: String(localized: "Cannot play audio", bundle: .module),
            message: message
        )
    }

    private static func failureDescription(_ failure: PlaybackFailure) -> String {
        switch failure {
        case .noAsset:
            return String(localized: "The playback service is unavailable.", bundle: .module)
        case .invalidAsset:
            return String(localized: "The audio file is unavailable or not downloaded.", bundle: .module)
        case .networkError(let message), .playbackError(let message):
            return message
        case .unsupportedFormat(let ext):
            return String(localized: "Unsupported audio format", bundle: .module) + ": " + ext
        case .invalidURL(let scheme):
            return String(localized: "Invalid audio URL", bundle: .module) + ": " + scheme
        }
    }

    func applyPlayModeChanged(_ mode: MagicPlayMode) {
        playMode = mode
    }

    func handleSceneChange(_ scene: AppScene?) {
        currentScene = scene
        if scene != targetScene {
            controlGeneration = ControlButtonsPlaybackRequestPolicy.generationAfterDeactivation(controlGeneration)
        }
    }

    func toggle() {
        if Self.verbose {
            let asset = playbackCapability?.currentURL?.lastPathComponent ?? "nil"
            let isPlaying = playbackCapability?.isPlaying ?? false
            let sceneActive = shouldActivateControl
            Self.log.info("\(Self.t)⏯️ Play/Pause tapped; asset=\(asset), isPlaying=\(isPlaying), sceneActive=\(sceneActive)")
        }
        guard let playbackCapability else {
            Self.log.error("\(Self.t)playbackCapability is unavailable")
            reportUnavailable(operation: "toggle playback")
            return
        }
        playbackCapability.toggle()
    }

    func previous() {
        if Self.verbose {
            Self.log.info("\(Self.t)⬅️ Previous button tapped")
        }
        guard let asset = playbackCapability?.currentURL else {
            reportUnavailable(operation: "play previous", message: String(localized: "There is no current audio file.", bundle: .module))
            return
        }
        handlePreviousRequested(asset)
    }

    func next() {
        if Self.verbose {
            Self.log.info("\(Self.t)➡️ Next button tapped")
        }
        guard let asset = playbackCapability?.currentURL else {
            reportUnavailable(operation: "play next", message: String(localized: "There is no current audio file.", bundle: .module))
            return
        }
        handleNextRequested(asset)
    }

    func togglePlayMode() {
        if Self.verbose {
            let mode = playMode.displayName
            Self.log.info("\(Self.t)🔁 Play mode button tapped; mode=\(mode)")
        }
        guard let playbackCapability else {
            reportUnavailable(operation: "change playback mode")
            return
        }
        playbackCapability.togglePlayMode()
    }

    func handleNavigationFailure(_ failure: PlaybackNavigationFailure) {
        let title: String
        switch failure.direction {
        case .previous:
            title = String(localized: "Cannot play previous", bundle: .module)
        case .next:
            title = String(localized: "Cannot play next", bundle: .module)
        }
        Self.log.error("Playback navigation rejected: \(failure.reason)")
        presentError(title: title, message: failure.reason)
    }

    func handlePreviousRequested(_ asset: URL, ignoreSceneCheck: Bool = false) {
        guard shouldActivateControl || ignoreSceneCheck else {
            presentError(title: String(localized: "Cannot play previous", bundle: .module), message: String(localized: "The music scene is not active.", bundle: .module))
            return
        }
        guard let playback = playbackCapability else {
            reportUnavailable(operation: "play previous")
            return
        }
        guard let navigation = navigationCapability else {
            reportUnavailable(
                operation: "play previous",
                message: String(localized: "The audio library navigation service is unavailable.", bundle: .module)
            )
            return
        }

        let generation = controlGeneration
        Task { @MainActor in
            do {
                if let previous = try await navigation.previousURL(before: asset) {
                    guard shouldApply(asset: asset, playback: playback, generation: generation, ignoreSceneCheck: ignoreSceneCheck) else { return }
                    await playback.play(previous)
                    return
                }

                if playback.playMode == .repeatAll, let last = try await navigation.lastURL() {
                    guard shouldApply(asset: asset, playback: playback, generation: generation, ignoreSceneCheck: ignoreSceneCheck) else { return }
                    await playback.play(last)
                } else if playback.playMode == .repeatAll {
                    guard shouldApply(asset: asset, playback: playback, generation: generation, ignoreSceneCheck: ignoreSceneCheck) else { return }
                    await playback.reset()
                    alert_info(String(localized: "No files in library", bundle: .module))
                } else {
                    Self.log.error("Previous navigation reached the beginning of the audio library")
                    presentError(title: String(localized: "Cannot play previous", bundle: .module), message: String(localized: "No previous audio file", bundle: .module))
                }
            } catch {
                guard shouldReport(asset: asset, playback: playback, generation: generation, ignoreSceneCheck: ignoreSceneCheck) else { return }
                presentError(title: String(localized: "Cannot play previous", bundle: .module), error: error)
            }
        }
    }

    func handleNextRequested(_ asset: URL, ignoreSceneCheck: Bool = false) {
        guard shouldActivateControl || ignoreSceneCheck else {
            presentError(title: String(localized: "Cannot play next", bundle: .module), message: String(localized: "The music scene is not active.", bundle: .module))
            return
        }
        guard let playback = playbackCapability else {
            reportUnavailable(operation: "play next")
            return
        }
        guard let navigation = navigationCapability else {
            reportUnavailable(
                operation: "play next",
                message: String(localized: "The audio library navigation service is unavailable.", bundle: .module)
            )
            return
        }

        let generation = controlGeneration
        Task { @MainActor in
            do {
                if let next = try await navigation.nextURL(after: asset) {
                    guard shouldApply(asset: asset, playback: playback, generation: generation, ignoreSceneCheck: ignoreSceneCheck) else { return }
                    await playback.play(next)
                    return
                }

                guard playback.playMode == .repeatAll else {
                    Self.log.error("Next navigation reached the end of the audio library")
                    presentError(title: String(localized: "Cannot play next", bundle: .module), message: String(localized: "No next audio file", bundle: .module))
                    return
                }

                if let first = try await navigation.firstURL() {
                    guard shouldApply(asset: asset, playback: playback, generation: generation, ignoreSceneCheck: ignoreSceneCheck) else { return }
                    alert_info(String(localized: "Reached the last track, playing the first", bundle: .module))
                    await playback.play(first)
                } else {
                    guard shouldApply(asset: asset, playback: playback, generation: generation, ignoreSceneCheck: ignoreSceneCheck) else { return }
                    await playback.reset()
                    alert_info(String(localized: "No files in library", bundle: .module))
                }
            } catch {
                guard shouldReport(asset: asset, playback: playback, generation: generation, ignoreSceneCheck: ignoreSceneCheck) else { return }
                presentError(title: String(localized: "Cannot play next", bundle: .module), error: error)
            }
        }
    }

    func handleStorageLocationDidReset() {
        guard ControlButtonsPlaybackRequestPolicy.shouldResetForStorageLocationChange(isSceneActive: shouldActivateControl),
              let playback = playbackCapability else { return }

        let generation = controlGeneration
        Task { @MainActor in
            guard ControlButtonsPlaybackRequestPolicy.shouldApplyStorageReset(
                currentGeneration: controlGeneration,
                requestGeneration: generation,
                isSceneActive: shouldActivateControl
            ) else { return }
            await playback.reset()
        }
    }

    func handleDBDeleted(urlsToDelete: [URL]) {
        guard let playback = playbackCapability,
              ControlButtonsPlaybackRequestPolicy.currentAssetAffectedByDeletion(
                currentAsset: playback.currentURL,
                deletedURLs: urlsToDelete
              ) else { return }

        let generation = controlGeneration
        Task { @MainActor in
            guard ControlButtonsPlaybackRequestPolicy.currentAssetAffectedByDeletion(
                currentAsset: playback.currentURL,
                deletedURLs: urlsToDelete
            ) else { return }

            guard shouldActivateControl else {
                await playback.reset()
                return
            }

            do {
                if let navigation = navigationCapability, let first = try await navigation.firstURL() {
                    guard ControlButtonsPlaybackRequestPolicy.shouldApplyDeletionRecovery(
                        currentAsset: playback.currentURL,
                        deletedURLs: urlsToDelete,
                        currentGeneration: controlGeneration,
                        requestGeneration: generation
                    ) else { return }
                    alert_warning(String(localized: "Current file was deleted, playing the first", bundle: .module))
                    await playback.play(first)
                } else {
                    await playback.reset()
                    alert_info(String(localized: "No files in library", bundle: .module))
                }
            } catch {
                await playback.reset()
                presentError(title: String(localized: "Cannot recover deleted audio", bundle: .module), error: error)
            }
        }
    }

    private func shouldApply(
        asset: URL,
        playback: any PlaybackCapability,
        generation: Int,
        ignoreSceneCheck: Bool
    ) -> Bool {
        ControlButtonsPlaybackRequestPolicy.shouldApplyNavigationResult(
            requestedAsset: asset,
            currentAsset: playback.currentURL,
            isSceneActive: shouldActivateControl || ignoreSceneCheck,
            currentGeneration: controlGeneration,
            requestGeneration: generation
        )
    }

    private func shouldReport(
        asset: URL,
        playback: any PlaybackCapability,
        generation: Int,
        ignoreSceneCheck: Bool
    ) -> Bool {
        ControlButtonsPlaybackRequestPolicy.shouldReportNavigationFailure(
            requestedAsset: asset,
            currentAsset: playback.currentURL,
            isSceneActive: shouldActivateControl || ignoreSceneCheck,
            currentGeneration: controlGeneration,
            requestGeneration: generation
        )
    }

    private func reportUnavailable(operation: String, message: String? = nil) {
        let message = message ?? String(localized: "The playback service is unavailable.", bundle: .module)
        Self.log.error("Cannot \(operation): \(message)")
        presentError(title: String(localized: "Playback controls unavailable", bundle: .module), message: message)
    }

    private func presentError(title: String, error: Error) {
        let description = error.localizedDescription
        let reflected = String(reflecting: error)
        let message = reflected == description || reflected.isEmpty
            ? description
            : "\(description)\n\n\(reflected)"
        presentError(title: title, message: message)
    }

    private func presentError(title: String, message: String) {
        toastProvider?.presentError(title: title, message: message)
    }
}
