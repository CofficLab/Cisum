import Foundation
import Combine
import MagicPlayMan
import OSLog
import ProviderScene
import MagicKit
import ProviderToast
import ProviderPlayback

typealias BookPlayModeLoadAction = @MainActor () async -> PlaybackMode
typealias BookPlayModeStoreAction = @MainActor (_ mode: PlaybackMode) async -> Void

@MainActor
final class BookPlayModeViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    private let playbackProvider: (any PlaybackProviding)?
    private let targetScene: AppScene
    private let loadPlayMode: BookPlayModeLoadAction
    private let storePlayMode: BookPlayModeStoreAction
    private let toastProvider: (any ToastProviding)?
    private var currentScene: AppScene?
    private var generation = 0
    private var isActive = false

    init(
        targetScene: AppScene = .audiobooks,
        playbackProvider: (any PlaybackProviding)?,
        loadPlayMode: @escaping BookPlayModeLoadAction,
        storePlayMode: @escaping BookPlayModeStoreAction,
        toastProvider: (any ToastProviding)? = nil
    ) {
        self.targetScene = targetScene
        self.playbackProvider = playbackProvider
        self.loadPlayMode = loadPlayMode
        self.storePlayMode = storePlayMode
        self.toastProvider = toastProvider
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
            case .loop: toastProvider?.info(String(localized: "Repeat One", bundle: .module))
            case .sequence, .repeatAll: toastProvider?.info(String(localized: "Sequential Play", bundle: .module))
            case .shuffle: toastProvider?.info(String(localized: "Shuffle", bundle: .module))
            }
        }
    }

    private func activate() {
        guard !isActive, currentScene == targetScene, let playbackProvider else { return }
        isActive = true
        if Self.verbose { os_log("\(Self.t)🟢 播放模式视图激活") }
        let requestGeneration = generation
        Task { @MainActor [weak self] in
            guard let self else { return }
            let storedMode = await loadPlayMode()
            guard self.isActive, self.generation == requestGeneration, storedMode != playbackProvider.playMode else { return }
            if Self.verbose { os_log("\(Self.t)🔄 恢复播放模式: \(storedMode.shortName)") }
            playbackProvider.setPlayMode(storedMode)
        }
    }
}
