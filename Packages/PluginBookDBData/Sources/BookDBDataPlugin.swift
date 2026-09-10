import KernelCore
import OSLog
import ProviderBook
import ProviderStorage

/// 有声书数据库数据层插件。
///
/// 该插件是书籍 SwiftData 容器、BookRepo 和文件库监听的唯一组装入口；
/// UI 插件通过 `BookDatabaseProviding` 使用它，不再自行构造数据库。
public actor BookDBDataPlugin: SuperPlugin {
    public static let shared = BookDBDataPlugin()
    public static let metadata = PluginMetadata(
        displayName: "Audiobook Database Data",
        description: "Provides the audiobook database and repository service.",
        iconName: "externaldrive.badge.timemachine",
        order: 11,
        policy: .alwaysOn,
        category: .library
    )

    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var provider: BookDatabaseProvider?

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        installProvider(kernel: kernel)
    }

    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        installProvider(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        installProvider(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        removeProvider(from: kernel)
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        removeProvider(from: kernel)
        self.kernel = nil
    }

    @MainActor
    private func installProvider(kernel: CisumKernel) {
        guard provider == nil, let storage = kernel.storage else { return }
        let provider = BookDatabaseProvider(storage: storage)
        self.provider = provider
        kernel.registerProvider(BookDatabaseProviding.self, provider)
    }

    @MainActor
    private func removeProvider(from kernel: CisumKernel) {
        guard provider != nil else { return }
        provider?.shutdown()
        kernel.unregisterProvider(BookDatabaseProviding.self)
        provider = nil
    }
}
