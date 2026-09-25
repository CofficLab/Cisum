import ProviderScene
import ProviderDocsView
import ProviderPlayback
import CisumKernelSupport
import CisumUIComponents
import OSLog
import SwiftUI
import MagicKit

@MainActor
public final class BookPlayModePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: BookPlayModePlugin.self)

    nonisolated static let verbose = false

    public static let shared = BookPlayModePlugin()
    public let order = BookPlayModePluginInfo.order
    public let iconName = BookPlayModePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: BookPlayModePlugin.self),
        name: BookPlayModePluginInfo.title,
        description: BookPlayModePluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var viewModel: BookPlayModeViewModel?
    nonisolated(unsafe) private var observer: BookPlayModeObserver?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { BookPlayModePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { BookPlayModePluginManualView() })
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
        return AnyView(BookPlayModePluginRootView(content: content))
    }

    // MARK: - State assembly

    /// 创建并持有播放模式 ViewModel 与观察者（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard viewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self),
              let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        sceneBox.scene = scene
        if Self.verbose { os_log("\(Self.t)🔧 installState") }

        let viewModel = BookPlayModeViewModel(
            playbackCapability: makePlaybackCapability(from: playback),
            loadPlayMode: makeLoadPlayMode(),
            storePlayMode: makeStorePlayMode()
        )
        self.viewModel = viewModel
        observer = BookPlayModeObserver(scene: scene, playback: playback, viewModel: viewModel)
    }

    @MainActor
    private func teardownState() {
        if Self.verbose { os_log("\(Self.t)🧹 teardownState") }
        observer?.cancel()
        observer = nil
        viewModel = nil
    }

    /// 将内核能力收窄后注入 ViewModel；ViewModel 不持有 Kernel。
    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any BookPlayModePlaybackCapability)? {
        guard let playback else { return nil }
        return BookPlayModePlaybackCapabilityAdapter(playback: playback)
    }

    /// 播放模式持久化的读取入口（由插件入口组装，不暴露单例给 ViewModel）。
    @MainActor
    private func makeLoadPlayMode() -> BookPlayModeLoadAction {
        { @MainActor in
            await BookPlayModeStore.shared.getPlayMode()
        }
    }

    /// 播放模式持久化的保存入口（由插件入口组装，不暴露单例给 ViewModel）。
    @MainActor
    private func makeStorePlayMode() -> BookPlayModeStoreAction {
        { @MainActor mode in
            await BookPlayModeStore.shared.storePlayMode(mode)
        }
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}