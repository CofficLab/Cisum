import Foundation
import MagicPlayMan
import ProviderScene
import MagicKit
import os

/// 场景监听器：订阅 `SceneProviding` 的场景切换事件，驱动「场景 + 文件」的
/// 当前播放记录恢复。
///
/// 内核存在场景概念（`AppScene` 固定枚举，如「音乐库」「有声书」），因此当前
/// 播放文件从单一全局记录升级为按场景分槽：每个场景各自记住上次播放的文件。
/// 本观察者负责：
/// - 场景切换时加载新场景上次播放的文件（`autoPlay: false`，仅加载不自动播放）；
/// - 场景切换时停止旧场景的播放：目标场景无历史记录时显式 `stop()`，
///   避免切到有声书场景后音乐仍在播放；
/// - 持有 `currentScene`，供插件在播放文件变化时写入对应场景的槽位。
@MainActor
final class PlaybackSceneObserver: SuperLog {
    nonisolated static let emoji = "🎭"
    nonisolated static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "Playback.Scene")

    private weak var player: MagicPlayMan?
    private let store: PlaybackStateStore
    private var handle: (any SceneProvidingObserverHandle)?

    /// 恢复代际：快速连续切换场景时，仅最新一次恢复生效。
    private var restoreGeneration = 0

    /// 当前激活场景；文件落盘时用它定位场景槽位。
    private(set) var currentScene: AppScene?

    init(scene: (any SceneProviding)?, player: MagicPlayMan, store: PlaybackStateStore) {
        self.player = player
        self.store = store
        // Initial sync：先同步当前快照再安装监听，避免丢失监听安装前的状态。
        restore(scene?.currentScene)
        handle = scene?.addObserver { [weak self] event in
            guard case .selectionChanged(let scene) = event else { return }
            self?.restore(scene)
        }
        if Self.verbose {
            Self.log.info("\(Self.t)👀 Scene observer installed; scene=\(String(describing: scene?.currentScene))")
        }
    }

    func cancel() {
        if Self.verbose {
            Self.log.info("\(Self.t)🛑 Scene observer cancelled")
        }
        handle?.cancel()
        handle = nil
    }

    /// 把当前播放文件记录到当前场景的槽位；场景未知时忽略。
    func saveCurrentFile(_ url: URL?) {
        guard let currentScene else { return }
        if Self.verbose {
            let scene = currentScene.rawValue
            Self.log.info("\(Self.t)💾 Save current file: \(url?.lastPathComponent ?? "nil") for scene=\(scene)")
        }
        store.saveCurrentFile(url, for: currentScene)
    }

    private func restore(_ scene: AppScene?) {
        currentScene = scene
        guard let scene, let player else { return }

        restoreGeneration += 1
        let generation = restoreGeneration

        if Self.verbose {
            Self.log.info("\(Self.t)🎬 Restore for scene=\(scene.rawValue); stored=\(self.store.loadCurrentFile(for: scene)?.lastPathComponent ?? "nil")")
        }

        guard let url = store.loadCurrentFile(for: scene) else {
            // 目标场景无历史记录：显式停止当前播放，而不是保持引擎现状，
            // 避免切到有声书场景后音乐仍在播放。
            // 用 stop() 而非 reset()：保留 currentURL、不触发 assetChanged(nil)，
            // 不清除任何场景槽位，切回原场景时仍可按槽位恢复。
            Task { @MainActor in
                guard generation == self.restoreGeneration else { return }
                await player.stop(reason: "PluginPlayBack.sceneSwitch.noHistory")
            }
            return
        }

        Task { @MainActor in
            guard generation == self.restoreGeneration else { return }

            // 恢复期间文件已被并发加载（如 BookProgressViewModel 的进度恢复
            // 带 startTime 先完成加载），不再重载，避免把已恢复的进度清零。
            if let current = player.currentURL, current.absoluteString == url.absoluteString {
                return
            }

            await player.play(url, autoPlay: false, reason: "PluginPlayBack.sceneRestore")
        }
    }
}
