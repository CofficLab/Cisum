import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import ProviderBook
import OSLog
import SwiftUI
import MagicKit

@MainActor
public final class BookSettingsPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: BookSettingsPlugin.self)

    nonisolated static let verbose = false

    public static let shared = BookSettingsPlugin()
    public let order = BookSettingsPluginInfo.order
    public let iconName = BookSettingsPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: BookSettingsPlugin.self),
        name: BookSettingsPluginInfo.title,
        description: BookSettingsPluginInfo.description,
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var settingsViewModel: BookSettingsViewModel?
    nonisolated(unsafe) private var settingsObserver: BookSettingsObserver?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { BookSettingsPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { BookSettingsPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addSettingNavigationItem() { contrib.addSettingNavigationItem(view) }
        }
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)🚀 onBoot") }
        installState()
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        installState()
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        teardownState()
        self.kernel = nil
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        let viewModel = resolveViewModel()
        return PluginSettingNavigationItem(
            id: "book-settings",
            title: BookSettingsPluginInfo.title,
            description: metadata.description,
            iconName: "book",
            order: BookSettingsPluginInfo.order,
            destination: AnyView(BookSettingsPluginView(viewModel: viewModel))
        )
    }

    // MARK: - State assembly

    @MainActor
    private func installState() {
        guard settingsViewModel == nil else { return }
        if Self.verbose { os_log("\(Self.t)🔧 installState") }
        guard let provider = kernel?.resolveProvider(BookDatabaseProviding.self) else {
            return
        }
        let viewModel = BookSettingsViewModel(bookDisk: { provider.bookDisk })
        let observer = BookSettingsObserver(viewModel: viewModel, provider: provider)
        settingsViewModel = viewModel
        settingsObserver = observer
    }

    @MainActor
    private func teardownState() {
        if Self.verbose { os_log("\(Self.t)🧹 teardownState") }
        settingsObserver?.cancel()
        settingsObserver = nil
        settingsViewModel = nil
    }

    @MainActor
    private func resolveViewModel() -> BookSettingsViewModel {
        if let settingsViewModel {
            return settingsViewModel
        }
        installState()
        return settingsViewModel!
    }
}