import ProviderRootView
import ProviderScene
import ProviderDocsView
import ProviderToast
import ProviderPlayback
import CisumUIComponents
import Foundation
import CisumKernelSupport
import MagicKit
import OSLog
import ProviderBook
import SwiftUI

@MainActor
public final class BookControlButtonsPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: BookControlButtonsPlugin.self)

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
        id: String(describing: BookControlButtonsPlugin.self),
        name: title,
        description: description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    private nonisolated(unsafe) weak var kernel: KernelCoreContainer?
    private nonisolated(unsafe) var controlViewModel: BookControlViewModel?
    private nonisolated(unsafe) var sceneObserver: BookControlSceneObserver?
    private nonisolated(unsafe) var playbackObserver: BookControlPlaybackObserver?
    private nonisolated(unsafe) var bookProviderObserver: (any BookProvidingObserverHandle)?

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
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addControlButtonsView() { contrib.addControlButtonsView(view) }
        }
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
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        teardownState()
    }

    /// 仅在有声书场景向播放控制区注入书籍专用按钮。
    @MainActor
    public func addControlButtonsView() -> AnyView? {
        guard kernel?.resolveProvider((any SceneProviding).self)?.currentScene == .audiobooks else { return nil }
        let viewModel = resolveViewModel()
        return AnyView(
            BookControlButtonsView(viewModel: viewModel) { [weak self] in
                guard let kernel = self?.kernel else { return }
                kernel.resolveProvider((any RootViewProviding).self)?.toggleContentView()
            }
        )
    }

    // MARK: - State assembly

    /// 创建并持有播放控制 ViewModel、场景 / 播放观察者与数据库通知（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard controlViewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        if Self.verbose { os_log("\(Self.t)🔧 installState") }
        let viewModel = BookControlViewModel(
            targetScene: .audiobooks,
            playbackCapability: makePlaybackCapability(from: playback),
            toastProvider: kernel.resolveProvider((any ToastProviding).self),
            bookDisk: { kernel.resolveProvider(BookDatabaseProviding.self)?.bookDisk }
        )
        sceneObserver = BookControlSceneObserver(scene: scene, viewModel: viewModel)
        playbackObserver = BookControlPlaybackObserver(playback: playback, viewModel: viewModel)
        installDatabaseObservers(
            viewModel: viewModel,
            provider: kernel.resolveProvider(BookDatabaseProviding.self)
        )
        controlViewModel = viewModel
    }

    /// 订阅书籍数据库与存储重置通知，转发到 ViewModel。
    @MainActor
    private func installDatabaseObservers(
        viewModel: BookControlViewModel,
        provider: (any BookDatabaseProviding)?
    ) {
        guard let provider else { return }
        bookProviderObserver = provider.addObserver { [weak viewModel] event in
            Task { @MainActor in
                switch event {
                case .libraryChanged:
                    viewModel?.handleBookDBRefreshed()
                case .librarySyncing, .librarySynced, .librarySorted, .playbackStateChanged:
                    break
                case let .libraryDeleted(urls):
                    viewModel?.handleBookDBDeleted(deletedURLs: urls)
                case .storageLocationChanged:
                    viewModel?.handleStorageLocationDidReset()
                }
            }
        }
    }

    @MainActor
    private func teardownState() {
        if Self.verbose { os_log("\(Self.t)🧹 teardownState") }
        sceneObserver?.cancel()
        sceneObserver = nil
        playbackObserver?.cancel()
        playbackObserver = nil
        bookProviderObserver?.cancel()
        bookProviderObserver = nil
        controlViewModel = nil
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModel() -> BookControlViewModel {
        if let controlViewModel {
            return controlViewModel
        }
        let viewModel = BookControlViewModel(
            targetScene: .audiobooks,
            playbackCapability: makePlaybackCapability(from: kernel?.resolveProvider((any PlaybackProviding).self)),
            toastProvider: kernel?.resolveProvider((any ToastProviding).self),
            bookDisk: { [weak self] in
                self?.kernel?.resolveProvider(BookDatabaseProviding.self)?.bookDisk
            }
        )
        controlViewModel = viewModel
        return viewModel
    }

    /// 将内核能力收窄后注入 ViewModel；ViewModel 不持有 Kernel。
    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any BookControlPlaybackCapability)? {
        guard let playback else { return nil }
        return BookControlPlaybackCapabilityAdapter(playback: playback)
    }
}