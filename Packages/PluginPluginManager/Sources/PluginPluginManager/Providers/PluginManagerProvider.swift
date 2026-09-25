import Foundation
import CisumKernelSupport
import ProviderPluginManaging

/// PluginPluginManager 自带的 `PluginManaging` 实现（不使用 Provider 包默认实现）。
///
/// 直接封装共享内核 `KernelCoreContainer`：读取全部插件与启用状态，驱动运行期
/// 启停（对齐 LumiKernel `enablePlugin/disablePlugin` 生命周期 + 贡献回收 +
/// 持久化），并在启停成功后发布 `.cisumEnabledPluginsDidChange` 通知，
/// 供宿主重建 UI 贡献聚合。
@MainActor
public final class PluginManagerProvider: PluginManaging {
    public private(set) var lastErrorDescription: String?
    private weak var kernel: KernelCoreContainer?

    private var observerCallbacks: [UUID: (PluginManagingEvent) -> Void] = [:]
    private var notificationToken: NSObjectProtocol?

    public init(kernel: KernelCoreContainer) {
        self.kernel = kernel

        // 订阅内核的已启用插件变更通知，转发为 Provider 语义事件。
        notificationToken = NotificationCenter.default.addObserver(
            forName: .cisumEnabledPluginsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.send(.enabledPluginsChanged)
            }
        }
    }

    // MARK: - PluginManaging

    public var allPlugins: [any SuperPlugin] {
        kernel?.allPlugins ?? []
    }

    public var configurablePlugins: [any SuperPlugin] {
        allPlugins.filter { $0.metadata.policy.isConfigurable }
    }

    public var pluginCount: Int {
        allPlugins.count
    }

    public var enabledCount: Int {
        guard let kernel else { return 0 }
        return kernel.allPlugins.filter { kernel.isPluginEnabled(id: $0.id) }.count
    }

    public func plugin(id: String) -> (any SuperPlugin)? {
        kernel?.resolvePlugin(id: id)
    }

    public func isRegistered(id: String) -> Bool {
        kernel?.isPluginRegistered(id: id) ?? false
    }

    public func enabledPlugins(from candidates: [any SuperPlugin]) -> [any SuperPlugin] {
        guard let kernel else { return [] }
        return candidates.filter { kernel.isPluginEnabled(id: $0.id) }
    }

    // MARK: - Plugin Control

    public func enablePlugin(id: String) async -> Bool {
        guard let kernel else {
            lastErrorDescription = "Kernel is not available"
            return false
        }
        do {
            try await kernel.enablePlugin(id: id)
            lastErrorDescription = nil
            notifyPluginsDidChange()
            return true
        } catch {
            lastErrorDescription = error.localizedDescription
            return false
        }
    }

    public func disablePlugin(id: String) async -> Bool {
        guard let kernel else {
            lastErrorDescription = "Kernel is not available"
            return false
        }
        do {
            try await kernel.disablePlugin(id: id)
            lastErrorDescription = nil
            notifyPluginsDidChange()
            return true
        } catch {
            lastErrorDescription = error.localizedDescription
            return false
        }
    }

    public func isEnabled(id: String) -> Bool {
        guard let kernel else { return false }
        return kernel.isPluginEnabled(id: id)
    }

    // MARK: - PluginManaging Observer

    public func addObserver(
        _ callback: @escaping (PluginManagingEvent) -> Void
    ) -> any PluginManagingObserverHandle {
        let id = UUID()
        observerCallbacks[id] = callback
        return PluginManagerObserverHandle(owner: self, id: id)
    }

    private func notifyPluginsDidChange() {
        NotificationCenter.default.post(name: .cisumEnabledPluginsDidChange, object: nil)
        send(.enabledPluginsChanged)
    }

    private func send(_ event: PluginManagingEvent) {
        let activeCallbacks = Array(observerCallbacks.values)
        for callback in activeCallbacks {
            callback(event)
        }
    }

    fileprivate func removeObserver(id: UUID) {
        observerCallbacks.removeValue(forKey: id)
    }
}

/// 插件管理监听句柄实现；`cancel()` 后从所属 Provider 移除回调。
@MainActor
private final class PluginManagerObserverHandle: PluginManagingObserverHandle {
    private weak var owner: PluginManagerProvider?
    private let id: UUID
    private var isCancelled = false

    init(owner: PluginManagerProvider, id: UUID) {
        self.owner = owner
        self.id = id
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.removeObserver(id: id)
    }
}
