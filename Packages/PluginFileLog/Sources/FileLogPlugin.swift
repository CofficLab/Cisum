import ProviderDocsView
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
import Foundation
import MagicKit
import CisumProviderStorage

@MainActor
public final class FileLogPlugin: AsyncSuperPlugin, SuperLog {
    public let id = "com.coffic.cisum.plugin.file-log"

    nonisolated static let verbose = false

    public static let shared = FileLogPlugin()
    public let order = 1
    public let iconName = FileLogPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: "com.coffic.cisum.plugin.file-log",
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
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            // 迁移旧目录（FileLog → FileLogPlugin → 当前 id）。
            // 必须在目标目录被创建之前迁移，否则迁移永远不执行。
            migrateLegacyDirectoryIfNeeded(storage: storage)
            let logsDir = storage.pluginDataDirectory(for: self.id)
            FileLogCoordinator.shared.configuration = AppFileLogConfiguration(logsDirectory: logsDir)
        }
        FileLogCoordinator.shared.start()

        #if os(macOS)
            FileLogTerminationObserver.shared.start()
        #endif
    }

    /// 迁移旧目录到新目录（如果需要）。
    ///
    /// 旧版本使用 `<databaseRoot>/FileLog/` 目录，
    /// 新版本改用 `pluginDataDirectory(for: "FileLogPlugin")` 目录。
    /// 此方法在首次启动时迁移旧数据，确保用户的日志文件不丢失。
    @MainActor
    private func migrateLegacyDirectoryIfNeeded(storage: any StorageProviding) {
        PluginDataDirectoryMigration.migrate(
            legacyDirectoryNames: PluginDataDirectoryHistory.legacyDirectoryNames(for: self.id),
            pluginID: self.id,
            dataRootDirectory: storage.databaseRoot
        )
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        #if os(macOS)
            FileLogTerminationObserver.shared.stopObserving()
        #endif
        FileLogCoordinator.shared.stop()
    }
}