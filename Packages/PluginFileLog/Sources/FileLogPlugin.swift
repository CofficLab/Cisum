import CisumUIComponents
import CisumKernel
import ProviderDocsView
import Foundation
import MagicKit

public actor FileLogPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = FileLogPlugin()
    public static let metadata = PluginMetadata(
        displayName: FileLogPluginInfo.title,
        description: FileLogPluginInfo.description,
        iconName: FileLogPluginInfo.iconName,
        order: 1,
        category: .system,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { FileLogPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { FileLogPluginManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        FileLogCoordinator.shared.configuration = AppFileLogConfiguration()
        FileLogCoordinator.shared.start()

        #if os(macOS)
            FileLogTerminationObserver.shared.start()
        #endif
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        #if os(macOS)
            FileLogTerminationObserver.shared.stopObserving()
        #endif
        FileLogCoordinator.shared.stop()
    }
}
