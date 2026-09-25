import CisumUIComponents
import CisumKernel
import MagicKit
import ProviderDocsView
import ProviderPlayback
import SwiftUI

public actor OpenButtonPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = OpenButtonPlugin()
    public static let metadata = PluginMetadata(
        displayName: String(localized: "Open Current", bundle: .module),
        description: OpenButtonPluginInfo.description,
        iconName: OpenButtonPluginInfo.iconName,
        policy: .alwaysOn,
        category: .tool,
    )

    private nonisolated(unsafe) weak var kernel: CisumKernel?
    private nonisolated(unsafe) var viewModel: OpenButtonViewModel?
    private nonisolated(unsafe) var observer: OpenButtonObserver?

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { OpenButtonPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { OpenButtonPluginManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        // 跨插件 Provider（Playback）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        teardownState()
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        teardownState()
        self.kernel = nil
    }

    #if os(macOS)
        @MainActor
        public func addToolBarButtons() -> [(id: String, view: AnyView)] {
            guard let viewModel else { return [] }
            return [(id: OpenButtonPluginInfo.toolbarItemId, view: AnyView(OpenCurrentButtonView(viewModel: viewModel)))]
        }
    #endif

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: CisumKernel) {
        guard viewModel == nil else { return }

        guard let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }

        let viewModel = OpenButtonViewModel(
            playbackCapability: makePlaybackCapability(from: playback)
        )
        self.viewModel = viewModel
        observer = OpenButtonObserver(playback: playback, viewModel: viewModel)
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
    ) -> (any OpenButtonPlaybackCapability)? {
        guard let playback else { return nil }
        return OpenButtonPlaybackCapabilityAdapter(playback: playback)
    }
}
