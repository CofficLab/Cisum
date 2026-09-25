import ProviderRootView
import ProviderAudioNavigation
import ProviderScene
import ProviderDocsView
import ProviderToast
import ProviderPlayback
import CisumUIComponents
import CisumKernelSupport
import MagicKit
import MagicPlayMan
import OSLog
import SwiftUI

/// 播放控制按钮插件：向播放控制区注入底部控制按钮组
/// （更多 / 上一曲 / 播放暂停 / 下一曲 / 播放模式）。
@MainActor
public final class AudioControlButtonsPlugin: SuperPlugin {
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

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { PluginControlButtonsAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { PluginControlButtonsManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addControlButtonsView() { contrib.addControlButtonsView(view) }
        }
        self.kernel = kernel
        // 跨插件 Provider 依赖在 onReady 阶段组装。
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        teardownState()
        guard let playback = kernel.resolveProvider((any PlaybackProviding).self) else {
            throw CisumKernelError.serviceNotAvailable(service: "PlaybackProviding")
        }
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else {
            throw CisumKernelError.serviceNotAvailable(service: "SceneProviding")
        }
        let capability = PlaybackCapabilityAdapter(playback: playback)
        let navigationCapability = kernel.resolveProvider((any AudioTrackNavigationProviding).self)
            .map(NavigationCapabilityAdapter.init(navigation:))
        let viewModel = ControlButtonsViewModel(
            playbackCapability: capability,
            navigationCapability: navigationCapability,
            toastProvider: kernel.resolveProvider((any ToastProviding).self),
            currentScene: scene.currentScene
        )
        self.viewModel = viewModel
        observer = ControlButtonsObserver(scene: scene, playback: playback, viewModel: viewModel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        guard viewModel == nil else { return }
        guard let playback = kernel.resolveProvider((any PlaybackProviding).self) else {
            throw CisumKernelError.serviceNotAvailable(service: "PlaybackProviding")
        }
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else {
            throw CisumKernelError.serviceNotAvailable(service: "SceneProviding")
        }
        let capability = PlaybackCapabilityAdapter(playback: playback)
        let navigationCapability = kernel.resolveProvider((any AudioTrackNavigationProviding).self)
            .map(NavigationCapabilityAdapter.init(navigation:))
        let viewModel = ControlButtonsViewModel(
            playbackCapability: capability,
            navigationCapability: navigationCapability,
            toastProvider: kernel.resolveProvider((any ToastProviding).self),
            currentScene: scene.currentScene
        )
        self.viewModel = viewModel
        observer = ControlButtonsObserver(scene: scene, playback: playback, viewModel: viewModel)
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
        guard kernel?.resolveProvider((any SceneProviding).self)?.currentScene == .music else { return nil }
        let viewModel = viewModel ?? ControlButtonsViewModel(
            playbackCapability: nil,
            toastProvider: kernel?.resolveProvider((any ToastProviding).self)
        )
        return AnyView(
            ControlButtonsView(viewModel: viewModel) { [weak self] in
                guard let kernel = self?.kernel else { return }
                kernel.resolveProvider((any RootViewProviding).self)?.toggleContentView()
            }
        )
    }

    @MainActor
    private func teardownState() {
        observer?.cancel()
        observer = nil
        viewModel = nil
    }
}
