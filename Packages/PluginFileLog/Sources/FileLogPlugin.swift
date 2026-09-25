import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import Foundation
import MagicKit

@MainActor
public final class FileLogPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: FileLogPlugin.self)

    nonisolated static let verbose = false

    public static let shared = FileLogPlugin()
    public let order = 1
    public let iconName = FileLogPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: FileLogPlugin.self),
        name: FileLogPluginInfo.title,
        description: FileLogPluginInfo.description,
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { FileLogPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { FileLogPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        FileLogCoordinator.shared.configuration = AppFileLogConfiguration()
        FileLogCoordinator.shared.start()

        #if os(macOS)
            FileLogTerminationObserver.shared.start()
        #endif
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        #if os(macOS)
            FileLogTerminationObserver.shared.stopObserving()
        #endif
        FileLogCoordinator.shared.stop()
    }
}