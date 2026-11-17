import Foundation
import MagicKit
import OSLog

/// 载入横幅的观察者：把场景与播放事件转发给 `BookLoadingViewModel`。
///
/// 横幅只在有音频书载入时存在，不需要轮询；安装时先同步一次当前快照，
/// 再订阅后续变化。
@MainActor
final class BookLoadingObserver: SuperLog {
    nonisolated static let emoji = "☁️"
    nonisolated static let verbose = false

    private weak var viewModel: BookLoadingViewModel?
    private var sceneHandle: (any BookLoadingSceneObserverHandle)?
    private var playbackHandle: (any BookLoadingPlaybackObserverHandle)?

    init(
        scene: any BookLoadingSceneCapability,
        playback: any BookLoadingPlaybackCapability,
        viewModel: BookLoadingViewModel
    ) {
        self.viewModel = viewModel

        viewModel.handleSceneChanged(scene.currentScene)
        viewModel.handleAssetChanged(playback.currentURL)
        viewModel.handleStateChanged(playback.state)

        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(newScene) = event else { return }
            self?.viewModel?.handleSceneChanged(newScene)
        }

        playbackHandle = playback.addObserver { [weak self] event in
            switch event {
            case .stateChanged(let state):
                self?.viewModel?.handleStateChanged(state)
            case .assetChanged(let url):
                self?.viewModel?.handleAssetChanged(url)
            }
        }
    }

    func cancel() {
        sceneHandle?.cancel()
        sceneHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
    }
}
