import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit
import ProviderStore

public actor StorePlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = StorePlugin()
    public static let metadata = PluginMetadata(
        displayName: String(localized: String.LocalizationValue(StorePluginInfo.titleKey), bundle: .module),
        description: String(localized: String.LocalizationValue(StorePluginInfo.descriptionKey), bundle: .module),
        iconName: StorePluginInfo.iconName,
        order: 80,
        policy: .alwaysOn,
        category: .settings,
    )

    nonisolated(unsafe) private var storeViewModel: StoreViewModel?
    nonisolated(unsafe) private var storeObserver: StoreObserver?

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { StorePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { StorePluginManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        installState()
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        teardownState()
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        let viewModel = resolveViewModel()
        return PluginSettingNavigationItem(
            id: "store",
            title: String(localized: String.LocalizationValue(StorePluginInfo.titleKey), bundle: .module),
            description: Self.metadata.description,
            iconName: Self.metadata.iconName,
            order: 80,
            destination: AnyView(StoreSetting(viewModel: viewModel))
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
