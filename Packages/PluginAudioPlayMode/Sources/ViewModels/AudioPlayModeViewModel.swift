import Foundation
import Combine
import MagicPlayMan
import OSLog
import ProviderScene
import MagicKit
import ProviderAudioLibrary
import ProviderPlayback

typealias AudioPlayModeLoadAction = @MainActor () async -> PlaybackMode
typealias AudioPlayModeStoreAction = @MainActor (_ rawValue: String, _ shortName: String) async -> Void

/// 音频播放模式按钮的状态容器。
///
/// 播放、队列排序、提示经 Capabilities 目录的能力执行（见
/// `AudioPlayModeCapability` / `AudioQueueOrderingCapability` /
/// `AudioPlayModeToastCapability`）；模式的持久化读写仍由本地动作提供。
@MainActor
final class AudioPlayModeViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "AudioPlayMode")
    /// 播放、队列排序与提示能力（Capabilities 目录收窄）。
    ///
    /// 与本批多数 ViewModel 不同，这里**强持有**能力：ViewModel 生命周期由入口
    /// 的 `teardownState` 控制（先置空 ViewModel 再释放 Adapter），因此强持有
    /// 不会让 Adapter 存活超过入口所有权；而 Adapter 内部对 Provider 已是 `weak`，
    /// 强持有能力并不会延长 Provider 的生命周期。
    private let playback: (any AudioPlayModeCapability)?
    private let ordering: (any AudioQueueOrderingCapability)?
    private let toast: (any AudioPlayModeToastCapability)?
    private let targetScene: AppScene
    private let loadPlayMode: AudioPlayModeLoadAction
    private let storePlayMode: AudioPlayModeStoreAction
    private var currentScene: AppScene?
    private var generation = 0
    private var isActive = false

    init(
        targetScene: AppScene = .music,
        playback: (any AudioPlayModeCapability)?,
        ordering: (any AudioQueueOrderingCapability)?,
        loadPlayMode: @escaping AudioPlayModeLoadAction,
        storePlayMode: @escaping AudioPlayModeStoreAction,
        toast: (any AudioPlayModeToastCapability)? = nil
    ) {
        self.targetScene = targetScene
        self.playback = playback
        self.ordering = ordering
        self.loadPlayMode = loadPlayMode
        self.storePlayMode = storePlayMode
        self.toast = toast
    }

    func handleSceneChange(_ scene: AppScene?) {
        currentScene = scene
        if scene == targetScene { activate() }
        else { generation += 1; isActive = false }
    }

    func applyPlayModeChanged(_ mode: PlaybackMode) {
        handlePlayModeChanged(mode)
    }

    private func activate() {
        guard !isActive, currentScene == targetScene, let playback else { return }
        isActive = true
        let requestGeneration = generation
        Task { @MainActor [weak self] in
            guard let self else { return }
            let storedMode = await loadPlayMode()
            guard self.isActive, self.generation == requestGeneration, storedMode != playback.playMode else { return }
            playback.setPlayMode(storedMode)
        }
    }

    private func handlePlayModeChanged(_ mode: PlaybackMode) {
        guard isActive, let playback else { return }
        generation += 1
        let requestGeneration = generation
        let currentURL = playback.currentURL
        let modeRawValue = mode.rawValue

        Task { @MainActor [weak self] in
            guard let self, self.isActive, self.generation == requestGeneration else { return }
            await storePlayMode(modeRawValue, mode.shortName)
        }
        Task { @MainActor [weak self] in
            guard let self, let playback = self.playback, self.isActive,
                  self.generation == requestGeneration,
                  playback.playMode.rawValue == modeRawValue else { return }
            do {
                guard let ordering = self.ordering else {
                    throw AudioLibraryProvidingError.unavailable
                }
                switch mode {
                case .loop: self.toast?.info(String(localized: "Repeat One", bundle: .module))
                case .sequence, .repeatAll:
                    self.toast?.info(String(localized: "Sequential Play", bundle: .module))
                    try await ordering.sort(currentURL: currentURL)
                case .shuffle:
                    self.toast?.info(String(localized: "Shuffle", bundle: .module))
                    try await ordering.shuffle(currentURL: currentURL)
                }
            } catch {
                guard self.isActive, self.generation == requestGeneration else { return }
                Self.log.error("Failed to update audio play queue: \(error.localizedDescription)")
                self.toast?.error(String(localized: "Cannot update play queue: \(error.localizedDescription)", bundle: .module))
            }
        }
    }
}
