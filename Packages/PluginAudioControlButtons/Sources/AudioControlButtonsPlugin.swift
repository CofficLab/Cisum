import ProviderToast
import ProviderAudioNavigation
import ProviderScene
import ProviderDocsView
import ProviderPlayback
import ProviderAudioLibrary
import ProviderAppState
import CisumProviderStorage
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
import MagicKit
import OSLog
import SwiftUI

/// 播放控制按钮插件：向播放控制区注入底部控制按钮组
/// （更多 / 上一曲 / 播放暂停 / 下一曲 / 播放模式）。
@MainActor
public final class AudioControlButtonsPlugin: AsyncSuperPlugin {
    public let id = String(describing: AudioControlButtonsPlugin.self)

    public static let shared = AudioControlButtonsPlugin()
    public let order = 20
    public let iconName = "playpause.fill"
    public let metadata = PluginMetadata(
        id: String(describing: AudioControlButtonsPlugin.self),
        name: String(localized: "Playback Control Buttons", bundle: .module),
        description: String(localized: "Provides the previous / play / next control buttons at the bottom of the player.", bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var viewModel: ControlButtonsViewModel?
    nonisolated(unsafe) private var observer: ControlButtonsObserver?

    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var playbackCapability: PlaybackControlCapabilityAdapter?
    nonisolated(unsafe) private var navigationCapability: TrackNavigationCapabilityAdapter?
    nonisolated(unsafe) private var toastCapability: PlaybackControlToastCapabilityAdapter?
    nonisolated(unsafe) private var environmentCapability: PlaybackEnvironmentCapabilityAdapter?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { PluginControlButtonsAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { PluginControlButtonsManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        // 跨插件 Provider 依赖在 onReady 阶段组装。
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        teardownState()
        try installState(kernel: kernel)
        registerContribution(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        guard viewModel == nil else { return }
        try installState(kernel: kernel)
        registerContribution(kernel: kernel)
    }

    /// 组装 ViewModel、Observer 与四项能力 Adapter（幂等由调用方保证）。
    ///
    /// 播放与场景 Provider 是硬依赖：缺失时控制按钮无意义，直接抛错让内核
    /// 记录；导航与提示为软依赖，缺失时按钮仍可用但会提示「服务不可用」。
    @MainActor
    private func installState(kernel: KernelCoreContainer) throws {
        guard let playbackProvider = kernel.resolveProvider((any PlaybackProviding).self) else {
            throw KernelCoreError.providerNotFound(type: (any PlaybackProviding).self)
        }
        guard let sceneProvider = kernel.resolveProvider((any SceneProviding).self) else {
            throw KernelCoreError.providerNotFound(type: (any SceneProviding).self)
        }

        let playback = PlaybackControlCapabilityAdapter(playback: playbackProvider)
        let navigation = TrackNavigationCapabilityAdapter(
            navigation: kernel.resolveProvider((any AudioTrackNavigationProviding).self)
        )
        let toast = PlaybackControlToastCapabilityAdapter(
            toast: kernel.resolveProvider((any ToastProviding).self)
        )
        let environment = PlaybackEnvironmentCapabilityAdapter(
            scene: sceneProvider,
            library: kernel.resolveProvider((any AudioLibraryProviding).self),
            storage: kernel.resolveProvider((any StorageProviding).self)
        )
        playbackCapability = playback
        navigationCapability = navigation
        toastCapability = toast
        environmentCapability = environment

        let viewModel = ControlButtonsViewModel(
            playback: playback,
            navigation: navigation,
            toast: toast,
            currentScene: environment.currentScene
        )
        self.viewModel = viewModel
        observer = ControlButtonsObserver(
            playback: playback,
            environment: environment,
            viewModel: viewModel
        )
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

    /// 向 `ControlViewProviding` 注入播放控制按钮组。
    @MainActor
    public func addControlButtonsView() -> AnyView? {
        // 视图贡献可能早于 onReady：此时按钮处于不可用状态，等待后续装配。
        let viewModel = viewModel ?? ControlButtonsViewModel(playback: nil)
        return AnyView(
            ControlButtonsView(viewModel: viewModel) { [weak self] in
                guard let kernel = self?.kernel else { return }
                // 走显隐服务而不是直接 toggleContentView()：内容区显隐有唯一真源
                // （AppState，落盘），直接改根视图的内存态会让这次操作不落盘，
                // 且在内存态与落盘态分叉时得到「点了没反应」的按钮。
                kernel.resolveProvider((any ContentViewVisibilityProviding).self)?
                    .toggleContentView()
            }
            .appDebugBadge("Audio Controls", alignment: .bottomTrailing)
        )
    }

    @MainActor
    private func registerContribution(kernel: KernelCoreContainer) {
        guard let view = addControlButtonsView(),
              let contribution = kernel.resolveProvider((any PluginContributionProviding).self) else { return }
        contribution.addControlButtonsView(ownerPluginID: id, view)
    }

    @MainActor
    private func teardownState() {
        observer?.cancel()
        observer = nil
        viewModel = nil
        playbackCapability = nil
        navigationCapability = nil
        toastCapability = nil
        environmentCapability = nil
    }
}
