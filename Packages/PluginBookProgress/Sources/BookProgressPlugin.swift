import ProviderScene
import ProviderDocsView
import ProviderPlayback
import KernelCore
import ProviderPlugin
import KitAppEvents
import OSLog
import CisumUIComponents
import LumiUI
import ProviderBook
import ProviderToast
import SwiftUI
import MagicKit

@MainActor
public final class BookProgressPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: BookProgressPlugin.self)

    nonisolated static let verbose = false

    public static let shared = BookProgressPlugin()
    public let order = BookProgressPluginInfo.order
    public let iconName = BookProgressPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: BookProgressPlugin.self),
        name: BookProgressPluginInfo.title,
        description: BookProgressPluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var playbackCapability: BookProgressPlaybackCapabilityAdapter?
    nonisolated(unsafe) private var libraryCapability: BookProgressLibraryCapabilityAdapter?
    nonisolated(unsafe) private var sceneCapability: BookProgressSceneCapabilityAdapter?
    nonisolated(unsafe) private var toastCapability: BookProgressToastCapabilityAdapter?
    nonisolated(unsafe) private var progressViewModel: BookProgressViewModel?
    nonisolated(unsafe) private var progressObserver: BookProgressObserver?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { BookProgressPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { BookProgressPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)🚀 onBoot") }
        // 跨插件 Provider（Scene / Playback）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)🟢 onReady") }
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        sceneBox.scene = nil
        teardownState()
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        let viewModel = resolveViewModel()
        return AnyView(BookProgressPluginRootView(viewModel: viewModel, content: content))
    }

    // MARK: - State assembly

    /// 创建并持有播放进度 ViewModel 与观察者（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard progressViewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playbackProvider = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene

        // 入口持有 Adapter，ViewModel 以 `weak` 消费。
        let playback = BookProgressPlaybackCapabilityAdapter(playback: playbackProvider)
        let library = BookProgressLibraryCapabilityAdapter(
            books: kernel.resolveProvider(BookDatabaseProviding.self)
        )
        let sceneCapability = BookProgressSceneCapabilityAdapter(scene: scene)
        let toast = BookProgressToastCapabilityAdapter(
            toast: kernel.resolveProvider((any ToastProviding).self)
        )
        self.playbackCapability = playback
        self.libraryCapability = library
        self.sceneCapability = sceneCapability
        self.toastCapability = toast

        let viewModel = BookProgressViewModel(
            targetScene: .audiobooks,
            playback: playback,
            library: library,
            toast: toast
        )
        let observer = BookProgressObserver(
            scene: sceneCapability,
            playback: playback,
            library: library,
            viewModel: viewModel
        )
        progressViewModel = viewModel
        progressObserver = observer
    }

    @MainActor
    private func teardownState() {
        progressObserver?.cancel()
        progressObserver = nil
        progressViewModel = nil
        playbackCapability = nil
        libraryCapability = nil
        sceneCapability = nil
        toastCapability = nil
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModel() -> BookProgressViewModel {
        if let progressViewModel {
            return progressViewModel
        }
        // 视图贡献可能早于 onReady：此时进度条处于不可用状态，等待后续装配。
        let viewModel = BookProgressViewModel(
            targetScene: .audiobooks,
            playback: kernel?.resolveProvider((any PlaybackProviding).self)
                .map(BookProgressPlaybackCapabilityAdapter.init),
            library: BookProgressLibraryCapabilityAdapter(
                books: kernel?.resolveProvider(BookDatabaseProviding.self)
            ),
            toast: kernel?.resolveProvider((any ToastProviding).self)
                .map(BookProgressToastCapabilityAdapter.init)
        )
        progressViewModel = viewModel
        return viewModel
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}
