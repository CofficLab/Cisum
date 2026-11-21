import Combine
import Foundation
import ProviderControlView
import ProviderScene

/// 有声书封面观察者：汇总播放、书库与场景事件，驱动封面 ViewModel
/// 与控制区「是否呈现封面区」的布局信号。
@MainActor
final class BookHeroObserver {
    private weak var viewModel: BookHeroViewModel?
    private var playbackHandle: (any BookHeroPlaybackObserverHandle)?
    private var libraryHandle: (any BookHeroLibraryObserverHandle)?
    private var sceneHandle: (any SceneProvidingObserverHandle)?
    private var viewModelCancellable: AnyCancellable?

    /// 最近一次场景事件；布局信号只在本场景内写。
    private var currentScene: AppScene?

    init(
        playback: any BookHeroPlaybackCapability,
        library: any BookHeroLibraryCapability,
        scene: any SceneProviding,
        viewModel: BookHeroViewModel
    ) {
        self.viewModel = viewModel
        self.currentScene = scene.currentScene

        playbackHandle = playback.addObserver { [weak self] event in
            guard case let .assetChanged(url) = event else { return }
            self?.viewModel?.applyAssetChanged(url)
            self?.publishVisibility()
        }

        libraryHandle = library.addObserver { [weak self] _ in
            self?.viewModel?.applyLibraryChanged()
            self?.publishVisibility()
        }

        // 书库初载是异步完成的，不经过上面的事件回调；跟随 ViewModel 发布补发信号。
        viewModelCancellable = viewModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.publishVisibility()
            }

        publishVisibility()
        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(newScene) = event else { return }
            self?.currentScene = newScene
            self?.publishVisibility()
        }
    }

    /// 只在本插件自己的有声书场景写布局信号；其他场景由该场景的封面插件负责。
    private func publishVisibility() {
        guard currentScene == .audiobooks else { return }
        ControlHeroVisibility.shared.isProgressVisible = true
        guard let viewModel else {
            ControlHeroVisibility.shared.isVisible = true
            return
        }
        ControlHeroVisibility.shared.isVisible =
            viewModel.isHeroVisible || viewModel.showsIdlePlaceholder
    }

    func cancel() {
        playbackHandle?.cancel()
        playbackHandle = nil
        libraryHandle?.cancel()
        libraryHandle = nil
        sceneHandle?.cancel()
        sceneHandle = nil
        viewModelCancellable?.cancel()
        viewModelCancellable = nil
    }
}
