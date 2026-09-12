import CisumUIComponents
import KernelCore
import ProviderDocsView
import ProviderAudioLibrary
import SwiftUI
import MagicKit

public actor AudioSettingsPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = AudioSettingsPlugin()
    public static let metadata = PluginMetadata(
        displayName: AudioSettingsPluginInfo.title,
        description: AudioSettingsPluginInfo.description,
        iconName: AudioSettingsPluginInfo.iconName,
        order: AudioSettingsPluginInfo.order,
        category: .settings,
    )

    nonisolated(unsafe) private var settingsViewModel: AudioSettingsViewModel?
    nonisolated(unsafe) private var settingsObserver: AudioSettingsObserver?
    nonisolated(unsafe) private weak var kernel: CisumKernel?

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        self.kernel = kernel
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioSettingsPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioSettingsPluginManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
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

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        let viewModel = resolveViewModel()
        return PluginSettingNavigationItem(
            id: "audio-settings",
            title: AudioSettingsPluginInfo.title,
            description: Self.metadata.description,
            iconName: "slider.horizontal.3",
            order: AudioSettingsPluginInfo.order,
            destination: AnyView(AudioSettingsPluginView(viewModel: viewModel))
        )
    }

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: CisumKernel) {
        guard settingsViewModel == nil else { return }
        let viewModel = AudioSettingsViewModel(audioDisk: { [weak self] in self?.kernelAudioDisk() })
        guard let storage = kernel.storage else { return }
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
        kernel?.audioLibrary?.audioDisk
    }
}
