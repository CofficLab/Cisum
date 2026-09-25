import ProviderDocsView
import ProviderStorage
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class SystemPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: SystemPlugin.self)

    nonisolated static let verbose = false

    public static let shared = SystemPlugin()
    public let order = ResetPluginInfo.order
    public let iconName = ResetPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: SystemPlugin.self),
        name: ResetPluginInfo.title,
        description: ResetPluginInfo.description,
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        self.kernel = kernel
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { SystemPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { SystemPluginManualView() })
        }
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addSettingNavigationItem() { contrib.addSettingNavigationItem(view) }
        }
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        PluginSettingNavigationItem(
            id: "system",
            title: ResetPluginInfo.title,
            description: metadata.description,
            iconName: "gearshape.2",
            order: ResetPluginInfo.order,
            destination: AnyView(
                SystemPluginSettingView(
                    resetSettings: { [weak self] in
                        await MainActor.run {
                            self?.kernel?.resolveProvider((any StorageProviding).self)?.resetStorageLocation()
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