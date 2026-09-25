import CisumUIComponents
import CisumKernel
import ProviderDocsView
import ProviderPlayback
import SwiftUI
import MagicKit

public actor LikeButtonPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = LikeButtonPlugin()
    public static let metadata = PluginMetadata(
        displayName: String(localized: "Like Button", bundle: .module),
        description: LikeButtonPluginInfo.description,
        iconName: LikeButtonPluginInfo.iconName,
        policy: .disabled,
        category: .like,
    )

    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var viewModel: LikeButtonViewModel?
    nonisolated(unsafe) private var observer: LikeButtonObserver?


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { LikeButtonPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { LikeButtonPluginManualView() })
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
    }

    @MainActor
    public func addToolBarButtons() -> [(id: String, view: AnyView)] {
        guard let viewModel else { return [] }
        return [(id: LikeButtonPluginInfo.toolbarItemId, view: AnyView(LikeToggleButtonView(viewModel: viewModel)))]
    }

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: CisumKernel) {
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
