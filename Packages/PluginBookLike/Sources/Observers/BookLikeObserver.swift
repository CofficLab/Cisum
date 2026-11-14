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
    private var sceneHandle: (any BookLikeSceneObserverHandle)?
    private var playbackHandle: (any BookLikePlaybackObserverHandle)?

    init(
        scene: any BookLikeSceneCapability,
        playback: any BookLikePlaybackCapability,
        viewModel: BookLikeViewModel
    ) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookLikeObserver 初始化") }
        viewModel.handleSceneChange(scene.currentScene)
        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(newScene) = event else { return }
            self?.viewModel?.handleSceneChange(newScene)
        }
        playbackHandle = playback.addObserver { [weak self] event in
            guard case let .likeStatusChanged(asset, isLiked) = event else { return }
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
