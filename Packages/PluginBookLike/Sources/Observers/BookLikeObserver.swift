import Foundation
import OSLog
import ProviderPlayback
import ProviderScene
import MagicKit

/// 书籍喜欢状态变化观察者（迁移 Phase 5）。
///
/// 订阅 `.BookLikeStatusChanged` 通知，转发到 `BookLikeViewModel`；
/// 取代原 `BookLikeSettingsView` 的 `.onReceive` 直接订阅。
@MainActor
final class BookLikeObserver: SuperLog {
    nonisolated static let emoji = "💗"
    nonisolated static let verbose = false

    private weak var viewModel: BookLikeViewModel?
    private var token: NSObjectProtocol?
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
        token = NotificationCenter.default.addObserver(forName: .BookLikeStatusChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.viewModel?.reloadLikedBooks() }
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookLikeObserver 取消") }
        sceneHandle?.cancel()
        sceneHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
        token = nil
    }
}
