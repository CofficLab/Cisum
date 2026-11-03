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
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            // 迁移旧目录：FileLog → FileLogPlugin（对齐 Lumi 规范）
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
        let legacyDir = storage.databaseRoot.appendingPathComponent("FileLog", isDirectory: true)
        // 用只解析路径的 API：pluginDataDirectory 会创建目录，
        // 那样「新目录是否存在」的判断将永远为真，迁移就永远不会执行。
        let currentDir = storage.pluginDataDirectoryPath(for: self.id)
        PluginDataDirectoryMigration.migrate(from: legacyDir, to: currentDir)
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        #if os(macOS)
            FileLogTerminationObserver.shared.stopObserving()
        #endif
        FileLogCoordinator.shared.stop()
    }
}