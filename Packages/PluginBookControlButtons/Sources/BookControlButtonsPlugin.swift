import ProviderScene
import ProviderDocsView
import ProviderToast
import ProviderPlayback
import LumiUI
import Foundation
import KernelCore
import ProviderPlugin
import KitAppEvents
import MagicKit
import OSLog
import ProviderBook
import ProviderAppState
import SwiftUI

@MainActor
public final class BookControlButtonsPlugin: AsyncSuperPlugin, SuperLog {
    public let id = "com.coffic.cisum.plugin.book-control-buttons"

    nonisolated static let verbose = false

    // MARK: - Plugin registration metadata

    public static let title = String(localized: "Book Playback Control", bundle: .module)
    public static let description = String(localized: "Book playback control, such as previous and next chapter", bundle: .module)
    public nonisolated static let emoji = "🎮📚"
    public static let iconName = "playpause"
    public static let order = 8

    public static let shared = BookControlButtonsPlugin()
    public let order = order
    public let iconName = iconName
    public let metadata = PluginMetadata(
        id: "com.coffic.cisum.plugin.book-control-buttons",
        name: title,
        description: description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .enabledByDefault,
        permissions: []
    )

    private nonisolated(unsafe) weak var kernel: KernelCoreContainer?
    private nonisolated(unsafe) var controlViewModel: BookControlViewModel?
    private nonisolated(unsafe) var sceneObserver: BookControlSceneObserver?
    private nonisolated(unsafe) var playbackObserver: BookControlPlaybackObserver?
    private nonisolated(unsafe) var libraryObserver: BookControlLibraryObserver?
    /// 场景激活句柄：书籍按钮组只在本插件自己的有声书场景登记。
    private nonisolated(unsafe) var sceneHandle: (any SceneProvidingObserverHandle)?

    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    private nonisolated(unsafe) var playbackCapability: BookControlPlaybackCapabilityAdapter?
    private nonisolated(unsafe) var sceneCapability: BookControlSceneCapabilityAdapter?
    private nonisolated(unsafe) var libraryCapability: BookControlLibraryCapabilityAdapter?
    private nonisolated(unsafe) var toastCapability: BookControlToastCapabilityAdapter?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { BookControlPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { BookControlPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)🚀 onBoot") }
        // 按钮贡献在有声书场景激活时登记（场景在 onReady 阶段才恢复），
        // 这里不按启动瞬间的场景做判断。
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)🟢 onReady") }
        installState(kernel: kernel)
        installSceneActivation(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        installState(kernel: kernel)
        installSceneActivation(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        sceneHandle?.cancel()
        sceneHandle = nil
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        sceneHandle?.cancel()
        sceneHandle = nil
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        teardownState()
    }

    /// 向播放控制区注入书籍专用按钮（由场景激活决定是否登记）。
    @MainActor
    public func addControlButtonsView() -> AnyView? {
        let viewModel = resolveViewModel()
        return AnyView(
            BookControlButtonsView(viewModel: viewModel) { [weak self] in
                guard let kernel = self?.kernel else { return }
                // 走显隐服务而不是直接 toggleContentView()：内容区显隐有唯一真源
                // （AppState，落盘），直接改根视图的内存态会让这次操作不落盘，
                // 且在内存态与落盘态分叉时得到「点了没反应」的按钮。
                kernel.resolveProvider((any ContentViewVisibilityProviding).self)?
                    .toggleContentView()
            }
            // .appDebugBadge("Book Controls", alignment: .bottomLeading)
        )
    }

    /// 有声书场景才登记按钮贡献；其他场景撤下，交给该场景自己的控制插件。
    @MainActor
    private func installSceneActivation(kernel: KernelCoreContainer) {
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        applyScene(scene.currentScene, kernel: kernel)

        guard sceneHandle == nil else { return }
        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(newScene) = event else { return }
            guard let self, let kernel = self.kernel else { return }
            self.applyScene(newScene, kernel: kernel)
        }
    }

    @MainActor
    private func applyScene(_ scene: AppScene?, kernel: KernelCoreContainer) {
        guard let contribution = kernel.resolveProvider((any PluginContributionProviding).self) else { return }
        guard scene == .audiobooks else {
            contribution.remove(owner: id)
            return
        }
        guard let view = addControlButtonsView() else { return }
        contribution.addControlButtonsView(ownerPluginID: id, view)
    }

    // MARK: - State assembly

    /// 创建并持有播放控制 ViewModel、场景 / 播放观察者与数据库通知（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard controlViewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        if Self.verbose { os_log("\(Self.t)🔧 installState") }
        // 入口强持有 Adapter，ViewModel / Observer 以 `weak` 或参数消费。
        let playbackCapability = BookControlPlaybackCapabilityAdapter(playback: playback)
        let sceneCapability = BookControlSceneCapabilityAdapter(scene: scene)
        let libraryCapability = BookControlLibraryCapabilityAdapter(
            books: kernel.resolveProvider(BookDatabaseProviding.self)
        )
        let toastCapability = BookControlToastCapabilityAdapter(
            toast: kernel.resolveProvider((any ToastProviding).self)
        )
        self.playbackCapability = playbackCapability
        self.sceneCapability = sceneCapability
        self.libraryCapability = libraryCapability
        self.toastCapability = toastCapability

        let viewModel = BookControlViewModel(
            targetScene: .audiobooks,
            playback: playbackCapability,
            library: libraryCapability,
            toast: toastCapability
        )
        sceneObserver = BookControlSceneObserver(scene: sceneCapability, viewModel: viewModel)
        playbackObserver = BookControlPlaybackObserver(
            playback: playbackCapability,
            viewModel: viewModel
        )
        libraryObserver = BookControlLibraryObserver(library: libraryCapability, viewModel: viewModel)
        controlViewModel = viewModel
    }


    @MainActor
    private func teardownState() {
        if Self.verbose { os_log("\(Self.t)🧹 teardownState") }
        sceneObserver?.cancel()
        sceneObserver = nil
        playbackObserver?.cancel()
        playbackObserver = nil
        libraryObserver?.cancel()
        libraryObserver = nil
        controlViewModel = nil
        playbackCapability = nil
        sceneCapability = nil
        libraryCapability = nil
        toastCapability = nil
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModel() -> BookControlViewModel {
        if let controlViewModel {
            return controlViewModel
        }
        // 视图贡献可能早于 onReady：此时控制按钮处于不可用状态，等待后续装配。
        let playbackCapability = BookControlPlaybackCapabilityAdapter(
            playback: kernel?.resolveProvider((any PlaybackProviding).self)
        )
        self.playbackCapability = playbackCapability
        let viewModel = BookControlViewModel(
            targetScene: .audiobooks,
            playback: playbackCapability,
            library: kernel?.resolveProvider(BookDatabaseProviding.self)
                .map(BookControlLibraryCapabilityAdapter.init),
            toast: kernel?.resolveProvider((any ToastProviding).self)
                .map(BookControlToastCapabilityAdapter.init)
        )
        controlViewModel = viewModel
        return viewModel
    }

}
