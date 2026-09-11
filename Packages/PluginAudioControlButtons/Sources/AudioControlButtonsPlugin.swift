import CisumUIComponents
import KernelCore
import MagicKit
import MagicPlayMan
import OSLog
import ProviderAudioNavigation
import ProviderDocsView
import ProviderPlayback
import ProviderRootView
import ProviderScene
import SwiftUI

/// 播放控制按钮插件：向播放控制区注入底部控制按钮组
/// （更多 / 上一曲 / 播放暂停 / 下一曲 / 播放模式）。
public actor AudioControlButtonsPlugin: SuperPlugin {
    public static let shared = AudioControlButtonsPlugin()
    public static let metadata = PluginMetadata(
        displayName: String(localized: "Playback Control Buttons", bundle: .module),
        description: String(localized: "Provides the previous / play / next control buttons at the bottom of the player.", bundle: .module),
        iconName: "playpause.fill",
        order: 20,
        policy: .alwaysOn,
        category: .playback,
        version: "1.0.0"
    )

    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var viewModel: ControlButtonsViewModel?
    nonisolated(unsafe) private var observer: ControlButtonsObserver?

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { PluginControlButtonsAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { PluginControlButtonsManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        // 跨插件 Provider 依赖在 onReady 阶段组装。
    }

    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
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
            toastProvider: kernel.toast,
            currentScene: scene.currentScene
        )
        self.viewModel = viewModel
        observer = ControlButtonsObserver(scene: scene, playback: playback, viewModel: viewModel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
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
            toastProvider: kernel.toast,
            currentScene: scene.currentScene
        )
        self.viewModel = viewModel
        observer = ControlButtonsObserver(scene: scene, playback: playback, viewModel: viewModel)
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

    /// 向 `ControlViewProviding` 注入播放控制按钮组。
    @MainActor
    public func addControlButtonsView() -> AnyView? {
        guard kernel?.scene?.currentScene == .music else { return nil }
        let viewModel = viewModel ?? ControlButtonsViewModel(
            playbackCapability: nil,
            toastProvider: kernel?.toast
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


