import Foundation
import ProviderPlayback
import ProviderScene
import MagicKit

/// 音频喜欢状态通知的集中观察者（迁移 Phase 2）。
///
/// 订阅 `.AudioLikeStatusChanged` 通知，驱动 `AudioLikeViewModel`
/// 刷新喜欢列表；取代 `AudioLikeSettingsView` 直接 `.onReceive` 订阅。
@MainActor
final class AudioLikeObserver: SuperLog {
    nonisolated static let emoji = "❤️"
    nonisolated static let verbose = false

    private weak var viewModel: AudioLikeViewModel?
    private var token: NSObjectProtocol?
    private var sceneHandle: (any SceneProvidingObserverHandle)?
    private var playbackHandle: (any PlaybackProvidingObserverHandle)?

    init(scene: any SceneProviding, playback: any PlaybackProviding, viewModel: AudioLikeViewModel) {
        self.viewModel = viewModel
        viewModel.handleSceneChange(scene.currentScene, targetScene: .music)
        sceneHandle = scene.addObserver { [weak self] event in
            guard case .selectionChanged(let scene) = event else { return }
            self?.viewModel?.handleSceneChange(scene, targetScene: .music)
        }
        playbackHandle = playback.addObserver { [weak self] event in
            guard case .likeStatusChanged(let asset, let isLiked) = event else { return }
            self?.viewModel?.handleLikeStatusChanged(asset: asset, liked: isLiked)
        }
        token = NotificationCenter.default.addObserver(
            forName: .AudioLikeStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.viewModel?.reloadLikedAudios()
            }
        }
    }

    func cancel() {
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
