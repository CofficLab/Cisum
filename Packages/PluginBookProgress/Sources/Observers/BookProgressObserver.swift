import Foundation
import OSLog
import MagicKit

/// 书籍进度的删除观察者（迁移 Phase 5）。
///
/// 订阅场景、播放与书库删除事件，转发到 `BookProgressViewModel`；
/// 取代原 `BookProgressRootView` 的 `.onReceive` 直接订阅。
@MainActor
final class BookProgressObserver: SuperLog {
    nonisolated static let emoji = "⏳"
    nonisolated static let verbose = false

    private weak var viewModel: BookProgressViewModel?
    private var sceneHandle: (any BookProgressSceneObserverHandle)?
    private var playbackHandle: (any BookProgressPlaybackObserverHandle)?
    private var libraryHandle: (any BookProgressLibraryObserverHandle)?

    init(
        scene: any BookProgressSceneCapability,
        playback: any BookProgressPlaybackCapability,
        library: any BookProgressLibraryCapability,
        viewModel: BookProgressViewModel
    ) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookProgressObserver 初始化") }

        viewModel.handleSceneChange(scene.currentScene)
        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(newScene) = event else { return }
            self?.viewModel?.handleSceneChange(newScene)
        }

        playbackHandle = playback.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .stateChanged(let state):
                self.viewModel?.handlePlayManStateChanged(state == .playing)
            case .assetChanged(let url):
                self.viewModel?.handleCurrentURLChanged(url)
            }
        }

        libraryHandle = library.addObserver { [weak self] event in
            guard case let .libraryDeleted(urls) = event else { return }
            Task { @MainActor in
                if Self.verbose { os_log("\(Self.t)🗑️ 收到书籍删除事件: \(urls.count) 个") }
                self?.viewModel?.handleBookDBDeleted(deletedURLs: urls)
            }
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookProgressObserver 取消") }
        sceneHandle?.cancel()
        sceneHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
        libraryHandle?.cancel()
        libraryHandle = nil
    }
}