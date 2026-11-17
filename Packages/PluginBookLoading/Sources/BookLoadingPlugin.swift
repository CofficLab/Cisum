import Combine
import KernelCore
import MagicKit
import OSLog
import ProviderBook
import ProviderControlView
import ProviderDocsView
import ProviderPlayback
import ProviderPlugin
import ProviderScene
import SwiftUI

/// 有声书载入插件：在控制区插槽里显示 iCloud 载入进度与失败恢复入口。
///
/// 只订阅「场景 + 播放状态」，不接管播放引擎；音乐场景下插槽始终休眠，
/// 音乐侧的载入显示仍由音乐自己的部件负责。
@MainActor
public final class BookLoadingPlugin: AsyncSuperPlugin, SuperLog {
    public let id = "com.coffic.cisum.plugin.book-loading"

    nonisolated static let verbose = false

    public static let shared = BookLoadingPlugin()
    public let order = BookLoadingPluginInfo.order
    public let iconName = BookLoadingPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: "com.coffic.cisum.plugin.book-loading",
        name: BookLoadingPluginInfo.title,
        description: BookLoadingPluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var viewModel: BookLoadingViewModel?
    nonisolated(unsafe) private var observer: BookLoadingObserver?
    /// ViewModel 以 `weak` 持有能力，入口必须显式强持有。
    nonisolated(unsafe) private var playbackCapability: BookLoadingPlaybackCapabilityAdapter?
    nonisolated(unsafe) private var sceneCapability: BookLoadingSceneCapabilityAdapter?
    /// ViewModel 同样 `weak` 持有书籍库能力，入口必须显式强持有。
    nonisolated(unsafe) private var libraryCapability: BookLoadingLibraryCapabilityAdapter?
    nonisolated(unsafe) private weak var controlProvider: (any ControlViewProviding)?
    nonisolated(unsafe) private var loadingSlot: ControlLoadingSlot?
    nonisolated(unsafe) private var activation: AnyCancellable?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { BookLoadingAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { BookLoadingManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        // 跨插件 Provider（Scene / Playback / ControlView）在 onReady 中解析。
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        teardownState()
        self.kernel = nil
    }

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard viewModel == nil else { return }
        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }

        let playbackCapability = BookLoadingPlaybackCapabilityAdapter(playback: playback)
        let sceneCapability = BookLoadingSceneCapabilityAdapter(scene: scene)
        let libraryCapability = BookLoadingLibraryCapabilityAdapter { @MainActor [weak self] in
            self?.kernel?.resolveProvider((any BookDatabaseProviding).self)
        }
        self.playbackCapability = playbackCapability
        self.sceneCapability = sceneCapability
        self.libraryCapability = libraryCapability

        let viewModel = BookLoadingViewModel(
            playback: playbackCapability,
            scene: scene.currentScene,
            library: libraryCapability
        )
        self.viewModel = viewModel
        observer = BookLoadingObserver(
            scene: sceneCapability,
            playback: playbackCapability,
            viewModel: viewModel
        )

        installSlot(
            control: kernel.resolveProvider((any ControlViewProviding).self),
            viewModel: viewModel
        )
    }

    /// 把横幅装进控制区插槽，并让插槽的激活态始终跟随横幅模式。
    @MainActor
    private func installSlot(
        control: (any ControlViewProviding)?,
        viewModel: BookLoadingViewModel
    ) {
        guard let control else { return }
        controlProvider = control

        let slot = ControlLoadingSlot(
            view: AnyView(BookLoadingBanner(viewModel: viewModel)),
            isActive: viewModel.mode != .hidden
        )
        loadingSlot = slot
        control.setLoadingSlot(slot)

        activation = viewModel.$mode
            .map { $0 != .hidden }
            .removeDuplicates()
            .sink { [weak slot] isActive in
                slot?.isActive = isActive
            }
    }

    @MainActor
    private func teardownState() {
        activation?.cancel()
        activation = nil
        observer?.cancel()
        observer = nil

        viewModel?.stop()
        loadingSlot?.isActive = false
        controlProvider?.setLoadingSlot(nil)
        loadingSlot = nil
        controlProvider = nil

        viewModel = nil
        playbackCapability = nil
        sceneCapability = nil
        libraryCapability = nil
    }
}
