import CisumUIComponents
import KernelCore
import ProviderDocsView
import SwiftUI
import MagicKit

public actor SystemPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = SystemPlugin()
    public static let metadata = PluginMetadata(
        displayName: ResetPluginInfo.title,
        description: ResetPluginInfo.description,
        iconName: ResetPluginInfo.iconName,
        order: ResetPluginInfo.order,
        category: .system,
    )

    nonisolated(unsafe) private weak var kernel: CisumKernel?


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        self.kernel = kernel
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { SystemPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { SystemPluginManualView() })
        }
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        PluginSettingNavigationItem(
            id: "system",
            title: ResetPluginInfo.title,
            description: Self.metadata.description,
            iconName: "gearshape.2",
            order: ResetPluginInfo.order,
            destination: AnyView(
                SystemPluginSettingView(
                    resetSettings: { [weak self] in
                        await MainActor.run {
                            self?.kernel?.storage?.resetStorageLocation()
                        }
                    }
                )
            )
        )
    }
}

private struct SystemPluginSettingView: View {
    let resetSettings: @Sendable () async -> Void

    var body: some View {
        SystemSetting(
            appVersion: MagicApp.getVersion(),
            resetSettings: resetSettings
        )
    }
}
