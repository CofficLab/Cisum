import ProviderAudioNavigation
import ProviderDocsView
import ProviderPlayback
import CisumUIComponents
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
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

    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var playbackCapability: WidgetPlaybackCapabilityAdapter?
    nonisolated(unsafe) private var navigationCapability: WidgetNavigationCapabilityAdapter?

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
        // 播放为硬依赖（Widget 控制无播放对象即无意义）；导航为软依赖，
        // 缺失时上一曲/下一曲命令静默放弃，不影响播放/暂停。
        let playback = WidgetPlaybackCapabilityAdapter(
            playback: kernel?.resolveProvider((any PlaybackProviding).self)
        )
        let navigation = WidgetNavigationCapabilityAdapter(
            navigation: kernel?.resolveProvider((any AudioTrackNavigationProviding).self)
        )
        playbackCapability = playback
        navigationCapability = navigation

        let viewModel = AudioWidgetControlViewModel(playback: playback, navigation: navigation)
        let observer = AudioWidgetCommandObserver(viewModel: viewModel)
        widgetViewModel = viewModel
        widgetObserver = observer
    }

    @MainActor
    private func teardownState() {
        widgetObserver?.cancel()
        widgetObserver = nil
        widgetViewModel = nil
        playbackCapability = nil
        navigationCapability = nil
    }

    @MainActor
    private func resolveViewModel() -> AudioWidgetControlViewModel {
        if let widgetViewModel {
            return widgetViewModel
        }
        installState(kernel: kernel)
        return widgetViewModel!
    }

}
