import ProviderScene
import ProviderPlayback
import Foundation
import OSLog
import MagicKit

/// 书籍喜欢状态变化观察者（迁移 Phase 5）。
///
/// 转发场景与播放喜欢状态到 `BookLikeViewModel`。
@MainActor
final class BookLikeObserver: SuperLog {
    nonisolated static let emoji = "💗"
    nonisolated static let verbose = false

    private weak var viewModel: BookLikeViewModel?
    private var sceneHandle: (any SceneProvidingObserverHandle)?
    private var playbackHandle: (any PlaybackProvidingObserverHandle)?

    init(scene: any SceneProviding, playback: any PlaybackProviding, viewModel: BookLikeViewModel) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookLikeObserver 初始化") }
        viewModel.handleSceneChange(scene.currentScene)
        sceneHandle = scene.addObserver { [weak self] event in
            guard case .selectionChanged(let scene) = event else { return }
            self?.viewModel?.handleSceneChange(scene)
        }
        playbackHandle = playback.addObserver { [weak self] event in
            guard case .likeStatusChanged(let asset, let isLiked) = event else { return }
            self?.viewModel?.handleLikeStatusChanged(asset: asset, liked: isLiked)
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookLikeObserver 取消") }
        sceneHandle?.cancel()
        sceneHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
    }
}
