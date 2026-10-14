import ProviderDocsView
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
import ProviderBook
import OSLog
import ProviderSettingView
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
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var settingsViewModel: BookSettingsViewModel?
    nonisolated(unsafe) private var settingsObserver: BookSettingsObserver?

    /// 本插件消费的能力 Adapter（见 Capabilities 规范第 5 条：入口强持有）。
    nonisolated(unsafe) private var bookSettingsLibraryCapability: BookSettingsLibraryCapabilityAdapter?

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
            if let entry = makeSettingEntry() { kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([entry]) }
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
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["book-settings"])
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        teardownState()
        self.kernel = nil
    }

    @MainActor
    public func makeSettingEntry() -> SettingEntryItem? {
        let viewModel = resolveViewModel()
        return SettingEntryItem(
            id: "book-settings",
            title: BookSettingsPluginInfo.title,
            systemImage: "book",
            order: BookSettingsPluginInfo.order,
            detail: {
            BookSettingsPluginView(viewModel: viewModel)
        }
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
        // 能力由入口组装并持有（观察者只在 init 期间使用能力安装订阅）。
        let libraryCapability = BookSettingsLibraryCapabilityAdapter(books: provider)
        bookSettingsLibraryCapability = libraryCapability
        let observer = BookSettingsObserver(viewModel: viewModel, library: libraryCapability)
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