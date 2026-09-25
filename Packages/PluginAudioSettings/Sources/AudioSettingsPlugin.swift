import ProviderStorage
import ProviderAudioLibrary
import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class AudioSettingsPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: AudioSettingsPlugin.self)

    nonisolated static let verbose = false

    public static let shared = AudioSettingsPlugin()
    public let order = AudioSettingsPluginInfo.order
    public let iconName = AudioSettingsPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: AudioSettingsPlugin.self),
        name: AudioSettingsPluginInfo.title,
        description: AudioSettingsPluginInfo.description,
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private var settingsViewModel: AudioSettingsViewModel?
    nonisolated(unsafe) private var settingsObserver: AudioSettingsObserver?
    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        self.kernel = kernel
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { AudioSettingsPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { AudioSettingsPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addSettingNavigationItem() { contrib.addSettingNavigationItem(view) }
        }
        self.kernel = kernel
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
        self.kernel = nil
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        let viewModel = resolveViewModel()
        return PluginSettingNavigationItem(
            id: "audio-settings",
            title: AudioSettingsPluginInfo.title,
            description: metadata.description,
            iconName: "slider.horizontal.3",
            order: AudioSettingsPluginInfo.order,
            destination: AnyView(AudioSettingsPluginView(viewModel: viewModel))
        )
    }

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard settingsViewModel == nil else { return }
        let viewModel = AudioSettingsViewModel(audioDisk: { [weak self] in self?.kernelAudioDisk() })
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else { return }
        let observer = AudioSettingsObserver(provider: storage, viewModel: viewModel)
        settingsViewModel = viewModel
        settingsObserver = observer
    }

    @MainActor
    private func teardownState() {
        settingsObserver?.cancel()
        settingsObserver = nil
        settingsViewModel = nil
    }

    @MainActor
    private func resolveViewModel() -> AudioSettingsViewModel {
        if let settingsViewModel {
            return settingsViewModel
        }
        return settingsViewModel ?? AudioSettingsViewModel(audioDisk: { [weak self] in self?.kernelAudioDisk() })
    }

    @MainActor
    private func kernelAudioDisk() -> URL? {
        kernel?.resolveProvider((any AudioLibraryProviding).self)?.audioDisk
    }
}