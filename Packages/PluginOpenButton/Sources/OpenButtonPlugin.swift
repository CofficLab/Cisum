import ProviderDocsView
import ProviderPlayback
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
import MagicKit
import SwiftUI

@MainActor
public final class OpenButtonPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: OpenButtonPlugin.self)

    nonisolated static let verbose = false

    public static let shared = OpenButtonPlugin()
    public let order = 9999
    public let iconName = OpenButtonPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: OpenButtonPlugin.self),
        name: String(localized: "Open Current", bundle: .module),
        description: OpenButtonPluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    private nonisolated(unsafe) weak var kernel: KernelCoreContainer?
    private nonisolated(unsafe) var viewModel: OpenButtonViewModel?
    private nonisolated(unsafe) var observer: OpenButtonObserver?
    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    private nonisolated(unsafe) var playbackCapability: OpenButtonCapabilityAdapter?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { OpenButtonPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { OpenButtonPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        #if os(macOS)
        self.kernel = kernel
        // onBoot 时 viewModel 尚未就绪，延迟到 onReady 注册工具栏按钮。
        #else
        self.kernel = kernel
        #endif
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        installState(kernel: kernel)
        #if os(macOS)
        registerToolBarButtonsIfNeeded()
        #endif
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
        #if os(macOS)
        registerToolBarButtonsIfNeeded()
        #endif
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        teardownState()
        self.kernel = nil
    }

    #if os(macOS)
        @MainActor
        public func addToolBarButtons() -> [(id: String, view: AnyView)] {
            guard let viewModel else { return [] }
            return [(id: OpenButtonPluginInfo.toolbarItemId, view: AnyView(OpenCurrentButtonView(viewModel: viewModel)))]
        }

        @MainActor
        private func registerToolBarButtonsIfNeeded() {
            guard let kernel else { return }
            guard let contrib = kernel.resolveProvider((any PluginContributionProviding).self) else { return }
            contrib.addToolBarButtons(ownerPluginID: id, addToolBarButtons())
        }
    #endif

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard viewModel == nil else { return }

        guard let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }

        let capability = OpenButtonCapabilityAdapter(playback: playback)
        playbackCapability = capability
        let viewModel = OpenButtonViewModel(playback: capability)
        self.viewModel = viewModel
        observer = OpenButtonObserver(playback: capability, viewModel: viewModel)
    }

    @MainActor
    private func teardownState() {
        observer?.cancel()
        observer = nil
        viewModel = nil
        playbackCapability = nil
    }

}
