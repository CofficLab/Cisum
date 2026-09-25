import ProviderAudioNavigation
import ProviderDocsView
import ProviderPlayback
import CisumUIComponents
import CisumKernelSupport
import ProviderAudioLibrary
import SwiftUI
import MagicKit

@MainActor
public final class AudioWidgetControlPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: AudioWidgetControlPlugin.self)

    nonisolated static let verbose = false

    public static let shared = AudioWidgetControlPlugin()
    public let order = 100
    public let iconName = AudioWidgetControlPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: AudioWidgetControlPlugin.self),
        name: AudioWidgetControlPluginInfo.title,
        description: AudioWidgetControlPluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var widgetViewModel: AudioWidgetControlViewModel?
    nonisolated(unsafe) private var widgetObserver: AudioWidgetCommandObserver?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { AudioWidgetControlPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { AudioWidgetControlPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
    }

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
        teardownState()
        self.kernel = nil
    }

    public nonisolated var label: String { "widgetControl" }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        let viewModel = resolveViewModel()
        return AnyView(
            content()
                .background(
                    AudioWidgetControlRootView(viewModel: viewModel)
                )
        )
    }

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: KernelCoreContainer?) {
        guard widgetViewModel == nil else { return }
        let viewModel = AudioWidgetControlViewModel(
            playbackCapability: makePlaybackCapability(from: kernel?.resolveProvider((any PlaybackProviding).self)),
            nextAsset: { current, verbose in
                guard let navigation = kernel?.resolveProvider((any AudioTrackNavigationProviding).self) else {
                    return nil
                }
                return try await navigation.nextURL(after: current, verbose: verbose)
            },
            previousAsset: { current, verbose in
                guard let navigation = kernel?.resolveProvider((any AudioTrackNavigationProviding).self) else {
                    return nil
                }
                return try await navigation.previousURL(before: current, verbose: verbose)
            },
            firstAsset: {
                guard let navigation = kernel?.resolveProvider((any AudioTrackNavigationProviding).self) else {
                    return nil
                }
                return try await navigation.firstURL()
            },
            lastAsset: {
                guard let navigation = kernel?.resolveProvider((any AudioTrackNavigationProviding).self) else {
                    return nil
                }
                return try await navigation.lastURL()
            }
        )
        let observer = AudioWidgetCommandObserver(viewModel: viewModel)
        widgetViewModel = viewModel
        widgetObserver = observer
    }

    @MainActor
    private func teardownState() {
        widgetObserver?.cancel()
        widgetObserver = nil
        widgetViewModel = nil
    }

    @MainActor
    private func resolveViewModel() -> AudioWidgetControlViewModel {
        if let widgetViewModel {
            return widgetViewModel
        }
        installState(kernel: kernel)
        return widgetViewModel!
    }

    /// 将内核播放 Provider 收窄后注入 ViewModel。
    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any AudioWidgetPlaybackCapability)? {
        guard let playback else { return nil }
        return AudioWidgetPlaybackCapabilityAdapter(playback: playback)
    }
}