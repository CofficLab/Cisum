import ProviderDocsView
import ProviderPlayback
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class LikeButtonPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: LikeButtonPlugin.self)

    nonisolated static let verbose = false

    public static let shared = LikeButtonPlugin()
    public let order = 9999
    public let iconName = LikeButtonPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: LikeButtonPlugin.self),
        name: String(localized: "Like Button", bundle: .module),
        description: LikeButtonPluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var viewModel: LikeButtonViewModel?
    nonisolated(unsafe) private var observer: LikeButtonObserver?


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { LikeButtonPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { LikeButtonPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            contrib.addToolBarButtons(self.addToolBarButtons())
        }
        self.kernel = kernel
        // 跨插件 Provider（Playback）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
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
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        teardownState()
    }

    @MainActor
    public func addToolBarButtons() -> [(id: String, view: AnyView)] {
        guard let viewModel else { return [] }
        return [(id: LikeButtonPluginInfo.toolbarItemId, view: AnyView(LikeToggleButtonView(viewModel: viewModel)))]
    }

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard viewModel == nil else { return }

        guard let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }

        let viewModel = LikeButtonViewModel(
            playbackCapability: makePlaybackCapability(from: playback)
        )
        self.viewModel = viewModel
        observer = LikeButtonObserver(playback: playback, viewModel: viewModel)
    }

    @MainActor
    private func teardownState() {
        observer?.cancel()
        observer = nil
        viewModel = nil
    }

    /// 将内核能力收窄后注入 ViewModel；ViewModel 不持有 Kernel。
    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any LikeButtonPlaybackCapability)? {
        guard let playback else { return nil }
        return LikeButtonPlaybackCapabilityAdapter(playback: playback)
    }
}