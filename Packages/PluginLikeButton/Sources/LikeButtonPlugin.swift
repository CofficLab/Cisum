import ProviderDocsView
import ProviderPlayback
import CisumUIComponents
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
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
    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var playbackCapability: LikeButtonCapabilityAdapter?


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { LikeButtonPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { LikeButtonPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        // onBoot 时 viewModel 尚未就绪，延迟到 onReady 注册工具栏按钮。
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        installState(kernel: kernel)
        registerToolBarButtonsIfNeeded()
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
        registerToolBarButtonsIfNeeded()
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

    @MainActor
    private func registerToolBarButtonsIfNeeded() {
        guard let kernel else { return }
        guard let contrib = kernel.resolveProvider((any PluginContributionProviding).self) else { return }
        contrib.addToolBarButtons(ownerPluginID: id, addToolBarButtons())
    }

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard viewModel == nil else { return }

        guard let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }

        let capability = LikeButtonCapabilityAdapter(playback: playback)
        playbackCapability = capability
        let viewModel = LikeButtonViewModel(playback: capability)
        self.viewModel = viewModel
        observer = LikeButtonObserver(playback: capability, viewModel: viewModel)
    }

    @MainActor
    private func teardownState() {
        observer?.cancel()
        observer = nil
        viewModel = nil
        playbackCapability = nil
    }

}
