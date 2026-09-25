import ProviderScene
import ProviderDocsView
import ProviderPlayback
import CisumKernelSupport
import OSLog
import CisumUIComponents
import ProviderBook
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
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene
        let bookProvider = kernel.resolveProvider(BookDatabaseProviding.self)

        let viewModel = BookProgressViewModel(
            targetScene: .audiobooks,
            playbackCapability: makePlaybackCapability(from: playback),
            currentBookURL: { bookProvider?.currentBookURL() },
            currentBookTime: { bookProvider?.currentBookTime() },
            storeCurrentBookURL: { bookProvider?.storeCurrentBookURL($0) },
            storeCurrentBookTime: { bookProvider?.storeCurrentBookTime($0) },
            bookDisk: { bookProvider?.bookDisk },
            saveBookState: { bookURL, currentURL, time in
                do {
                    try await bookProvider?.savePlaybackState(
                        for: bookURL,
                        currentURL: currentURL,
                        time: time
                    )
                } catch {
                    os_log(.error, "BookProgressPlugin failed to save book state: \(error.localizedDescription)")
                }
            }
        )
        let observer = BookProgressObserver(
            scene: scene,
            playback: playback,
            bookProvider: bookProvider,
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
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModel() -> BookProgressViewModel {
        if let progressViewModel {
            return progressViewModel
        }
        let viewModel = BookProgressViewModel(
            targetScene: .audiobooks,
            playbackCapability: makePlaybackCapability(from: kernel?.resolveProvider((any PlaybackProviding).self)),
            currentBookURL: { nil },
            currentBookTime: { nil },
            storeCurrentBookURL: { _ in },
            storeCurrentBookTime: { _ in },
            bookDisk: { nil },
            saveBookState: { _, _, _ in }
        )
        progressViewModel = viewModel
        return viewModel
    }

    /// 将内核能力收窄后注入 ViewModel；ViewModel 不持有 Kernel。
    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any BookProgressPlaybackCapability)? {
        guard let playback else { return nil }
        return BookProgressPlaybackCapabilityAdapter(playback: playback)
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}