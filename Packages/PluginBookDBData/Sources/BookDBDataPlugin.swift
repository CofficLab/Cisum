import ProviderStorage
import CisumKernelSupport
import OSLog
import ProviderBook

/// 有声书数据库数据层插件。
///
/// 该插件是书籍 SwiftData 容器、BookRepo 和文件库监听的唯一组装入口；
/// UI 插件通过 `BookDatabaseProviding` 使用它，不再自行构造数据库。
@MainActor
public final class BookDBDataPlugin: SuperPlugin {
    public let id = String(describing: BookDBDataPlugin.self)

    public static let shared = BookDBDataPlugin()
    public let order = 11
    public let iconName = "externaldrive.badge.timemachine"
    public let metadata = PluginMetadata(
        id: String(describing: BookDBDataPlugin.self),
        name: "Audiobook Database Data",
        description: "Provides the audiobook database and repository service.",
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var provider: BookDatabaseProvider?

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        try installProvider(kernel: kernel)
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        try installProvider(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        try installProvider(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        removeProvider(from: kernel)
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        removeProvider(from: kernel)
        self.kernel = nil
    }

    @MainActor
    private func installProvider(kernel: KernelCoreContainer) throws {
        guard provider == nil, let storage = kernel.resolveProvider((any StorageProviding).self) else { return }
        let provider = BookDatabaseProvider(storage: storage)
        do {
            try kernel.registerProvider(BookDatabaseProviding.self, provider)
            self.provider = provider
        } catch {
            provider.shutdown()
            throw error
        }
    }

    @MainActor
    private func removeProvider(from kernel: KernelCoreContainer) {
        guard provider != nil else { return }
        provider?.shutdown()
        kernel.unregisterProvider(BookDatabaseProviding.self)
        provider = nil
    }
}