import ProviderDocsView
import CisumUIComponents
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
import ProviderSettingView
import SwiftUI
import MagicKit
import ProviderStore

@MainActor
public final class StorePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: StorePlugin.self)

    nonisolated static let verbose = false

    public static let shared = StorePlugin()
    public let order = 80
    public let iconName = StorePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: StorePlugin.self),
        name: String(localized: String.LocalizationValue(StorePluginInfo.titleKey), bundle: .module),
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private var storeViewModel: StoreViewModel?
    nonisolated(unsafe) private var storeObserver: StoreObserver?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { StorePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { StorePluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        StoreService.bootstrap()
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let entry = makeSettingEntry() { kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([entry]) }
        }
        installState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["store"])
        teardownState()
    }

    @MainActor
    public func makeSettingEntry() -> SettingEntryItem? {
        let viewModel = resolveViewModel()
        return SettingEntryItem(
            id: "store",
            title: String(localized: String.LocalizationValue(StorePluginInfo.titleKey), bundle: .module),
            systemImage: iconName,
            order: 80,
            detail: {
            StoreSetting(viewModel: viewModel)
        }
        )
    }

    // MARK: - State assembly

    @MainActor
    private func installState() {
        guard storeViewModel == nil else { return }
        let viewModel = StoreViewModel()
        let observer = StoreObserver(viewModel: viewModel)
        storeViewModel = viewModel
        storeObserver = observer
    }

    @MainActor
    private func teardownState() {
        storeObserver?.cancel()
        storeObserver = nil
        storeViewModel = nil
    }

    @MainActor
    private func resolveViewModel() -> StoreViewModel {
        if let storeViewModel {
            return storeViewModel
        }
        let viewModel = StoreViewModel()
        storeViewModel = viewModel
        return viewModel
    }
}
