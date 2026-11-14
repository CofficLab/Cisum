import Foundation
import Combine
import MagicPlayMan
import OSLog
import ProviderScene
import MagicKit
import ProviderPlayback

typealias BookPlayModeLoadAction = @MainActor () async -> PlaybackMode
typealias BookPlayModeStoreAction = @MainActor (_ mode: PlaybackMode) async -> Void

/// 播放模式按钮的状态容器。
///
/// 播放与提示经 Capabilities 目录的能力执行（见 `BookPlayModeCapability`
/// / `BookPlayModeToastCapability`），模式的持久化读写仍由本地
/// `BookPlayModeStore` 提供（非 Provider 依赖，不纳入能力）。
@MainActor
final class BookPlayModeViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    /// 播放与提示能力（Capabilities 目录收窄），`weak` 持有。
    private weak var playback: (any BookPlayModeCapability)?
    private weak var toast: (any BookPlayModeToastCapability)?
    private let targetScene: AppScene
    private let loadPlayMode: BookPlayModeLoadAction
    private let storePlayMode: BookPlayModeStoreAction
    private var currentScene: AppScene?
    private var generation = 0
    private var isActive = false

    init(
        targetScene: AppScene = .audiobooks,
        playback: (any BookPlayModeCapability)?,
        loadPlayMode: @escaping BookPlayModeLoadAction,
        storePlayMode: @escaping BookPlayModeStoreAction,
        toast: (any BookPlayModeToastCapability)? = nil
    ) {
        self.targetScene = targetScene
        self.playback = playback
        self.loadPlayMode = loadPlayMode
        self.storePlayMode = storePlayMode
        self.toast = toast
    }

    func handleSceneChange(_ scene: AppScene?) {
        currentScene = scene
        if scene == targetScene { activate() }
        else { generation += 1; isActive = false }
    }

    func handlePlayModeChanged(_ mode: PlaybackMode) {
        guard isActive else { return }
        if Self.verbose { os_log("\(Self.t)🔄 播放模式变更: \(mode.shortName)") }
        generation += 1
        let requestGeneration = generation
        Task { @MainActor [weak self] in
            guard let self, self.isActive, self.generation == requestGeneration else { return }
            await storePlayMode(mode)
            switch mode {
            case .loop: toast?.info(String(localized: "Repeat One", bundle: .module))
            case .sequence, .repeatAll: toast?.info(String(localized: "Sequential Play", bundle: .module))
            case .shuffle: toast?.info(String(localized: "Shuffle", bundle: .module))
            }
        }
    }

    private func activate() {
        guard !isActive, currentScene == targetScene, playback != nil else { return }
        isActive = true
        if Self.verbose { os_log("\(Self.t)🟢 播放模式视图激活") }
        let requestGeneration = generation
        Task { @MainActor [weak self] in
            guard let self else { return }
            let storedMode = await loadPlayMode()
            guard let playback, self.isActive, self.generation == requestGeneration, storedMode != playback.playMode else { return }
            if Self.verbose { os_log("\(Self.t)🔄 恢复播放模式: \(storedMode.shortName)") }
            playback.setPlayMode(storedMode)
        }
    }
}
