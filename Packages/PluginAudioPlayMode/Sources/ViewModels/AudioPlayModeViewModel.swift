import Foundation
import Combine
import MagicPlayMan
import OSLog
import ProviderScene
import MagicKit
import ProviderToast
import ProviderPlayback

typealias AudioPlayModeSortAction = @MainActor (_ currentURL: URL?) async throws -> Void
typealias AudioPlayModeShuffleAction = @MainActor (_ currentURL: URL?) async throws -> Void
typealias AudioPlayModeLoadAction = @MainActor () async -> PlaybackMode
typealias AudioPlayModeStoreAction = @MainActor (_ rawValue: String, _ shortName: String) async -> Void

@MainActor
final class AudioPlayModeViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "AudioPlayMode")
    private let playbackProvider: (any PlaybackProviding)?
    private let targetScene: AppScene
    private let sort: AudioPlayModeSortAction
    private let shuffle: AudioPlayModeShuffleAction
    private let loadPlayMode: AudioPlayModeLoadAction
    private let storePlayMode: AudioPlayModeStoreAction
    private let toastProvider: (any ToastProviding)?
    private var currentScene: AppScene?
    private var generation = 0
    private var isActive = false

    init(
        targetScene: AppScene = .music,
        playbackProvider: (any PlaybackProviding)?,
        sort: @escaping AudioPlayModeSortAction,
        shuffle: @escaping AudioPlayModeShuffleAction,
        loadPlayMode: @escaping AudioPlayModeLoadAction,
        storePlayMode: @escaping AudioPlayModeStoreAction,
        toastProvider: (any ToastProviding)? = nil
    ) {
        self.targetScene = targetScene
        self.playbackProvider = playbackProvider
        self.sort = sort
        self.shuffle = shuffle
        self.loadPlayMode = loadPlayMode
        self.storePlayMode = storePlayMode
        self.toastProvider = toastProvider
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
        guard !isActive, currentScene == targetScene, let playbackProvider else { return }
        isActive = true
        let requestGeneration = generation
        Task { @MainActor [weak self] in
            guard let self else { return }
            let storedMode = await loadPlayMode()
            guard self.isActive, self.generation == requestGeneration, storedMode != playbackProvider.playMode else { return }
            playbackProvider.setPlayMode(storedMode)
        }
    }

    private func handlePlayModeChanged(_ mode: PlaybackMode) {
        guard isActive, let playbackProvider else { return }
        generation += 1
        let requestGeneration = generation
        let currentURL = playbackProvider.currentURL
        let modeRawValue = mode.rawValue

        Task { @MainActor [weak self] in
            guard let self, self.isActive, self.generation == requestGeneration else { return }
            await storePlayMode(modeRawValue, mode.shortName)
        }
        Task { @MainActor [weak self] in
            guard let self, self.isActive, self.generation == requestGeneration,
                  playbackProvider.playMode.rawValue == modeRawValue else { return }
            do {
                switch mode {
                case .loop: toastProvider?.info(String(localized: "Repeat One", bundle: .module))
                case .sequence, .repeatAll:
                    toastProvider?.info(String(localized: "Sequential Play", bundle: .module))
                    try await self.sort(currentURL)
                case .shuffle:
                    toastProvider?.info(String(localized: "Shuffle", bundle: .module))
                    try await self.shuffle(currentURL)
                }
            } catch {
                guard self.isActive, self.generation == requestGeneration else { return }
                Self.log.error("Failed to update audio play queue: \(error.localizedDescription)")
                toastProvider?.error(String(localized: "Cannot update play queue: \(error.localizedDescription)", bundle: .module))
            }
        }
    }
}
