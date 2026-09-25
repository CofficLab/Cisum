import CisumUIComponents
import Foundation
import MagicKit
import OSLog

/// 内置插件管理器。
///
/// 负责插件的注册、两阶段生命周期管理和启用状态控制。
///
/// ## 启动流程
///
/// ```
/// initializePlugins([myPlugin, ...])
///     ↓
/// onBoot(kernel:)    ← 阶段 1: 插件注册内核服务
///     ↓
/// onReady(kernel:)   ← 阶段 2: 插件执行依赖服务的异步初始化
/// ```
///
/// ## 插件启用策略
///
/// - 内核级插件 (`Policy.alwaysOn`): 始终启用，不可被用户禁用。
/// - 可配置插件 (`Policy.optOut` / `Policy.optIn`): 用户可通过
///   `PluginEnabledStateStore` 覆盖启用状态。
/// - 禁用插件 (`Policy.disabled`): 始终禁用，不可被用户启用。
@MainActor
public final class BuiltinPluginManager: ObservableObject {
    nonisolated(unsafe) public static var verbose = false
    nonisolated static let emoji = "🧩"

    /// 弱引用回到内核容器。
    weak var kernel: CisumKernelContainer?

    /// 所有已注册的插件实例（以版本化类型名称为键的字典，按注册顺序排序）。
    private var pluginRegistry: [String: any SuperPlugin] = [:]

    /// 版本化类型名称列表，保留注册顺序。
    private var orderedPluginKeys: [String] = []

    /// 已成功完成 `onBoot` 的插件键（按启动顺序），用于逆序清理与启动回滚。
    private var bootedPluginKeys: [String] = []

    /// 插件启用状态持久化存储（由存储插件注入到 `kernel.stateStore`，
    /// 写入 `<databaseRoot>/PluginManager/plugin-enabled-overrides.plist`）。
    /// 未注入时为 `nil`：启用状态回落策略默认值，运行期启停不持久化。
    private var stateStore: (any PluginStatePersisting)? {
        kernel?.stateStore
    }

    /// 已使用的插件 ID 集合，用于检测重复。
    private var usedIDs: Set<String> = []

    public init() {}

    // MARK: - Plugin Initialization

    /// 初始化插件列表。
    ///
    /// 按 `metadata.order` 升序排序后注册，保证 `onBoot` / `onReady` 与贡献
    /// 聚合都以稳定、确定的顺序执行（与旧版 `PluginVM.getAllPlugins()` 一致）。
    /// 此方法应在 `startup()` 之前调用。
    ///
    /// - Parameter plugins: 插件实例数组。
    public func initializePlugins(_ plugins: [any SuperPlugin]) {
        pluginRegistry.removeAll()
        orderedPluginKeys.removeAll()
        usedIDs.removeAll()
        bootedPluginKeys.removeAll()

        let sortedPlugins = plugins.sorted { type(of: $0).metadata.order < type(of: $1).metadata.order }
        for plugin in sortedPlugins {
            register(plugin)
        }

        if Self.verbose {
            os_log("\(Self.t)✅ Initialized \(self.pluginRegistry.count) plugins")
        }
    }

    // MARK: - Lifecycle Phases

    /// 阶段 1: OnBoot —— 注册内核服务。
    ///
    /// 先启动所有 `alwaysOn` 插件（核心服务先行，例如 Storage 提供数据目录），
    /// 再启动可配置插件（受启用策略 + 用户覆盖约束）。对内核感知插件调用
    /// 统一调用 `SuperPlugin` 的 Kernel 生命周期。
    ///
    /// 启动中途任一插件抛错时，已启动插件逆序执行 `onShutdown` 并统一
    /// `onUnregister`，随后清空注册表，避免留下半启动内核。
    ///
    /// - Parameter kernel: 内核容器实例。
    public func onBoot(kernel: CisumKernelContainer) async throws {
        guard !pluginRegistry.isEmpty else {
            if Self.verbose { os_log("\(Self.t)⚠️ No plugins initialized, skipping onBoot") }
            return
        }

        bootedPluginKeys.removeAll()

        do {
            // 注册阶段对所有参与装配的插件执行一次，允许插件登记目录型贡献。
            for key in orderedPluginKeys {
                guard let plugin = pluginRegistry[key] else { continue }
                if Self.verbose { os_log("\(Self.t)📋 onRegister for: \(plugin.id)") }
                kernel.activePluginID = plugin.id
                do {
                    try await plugin.onRegister(kernel: kernel)
                } catch {
                    kernel.activePluginID = nil
                    try rethrow(error, from: plugin)
                }
                kernel.activePluginID = nil
            }

            // 核心插件先启动
            for key in orderedPluginKeys {
                guard let plugin = pluginRegistry[key] else { continue }
                guard type(of: plugin).metadata.policy == .alwaysOn else { continue }
                try await bootPlugin(plugin, kernel: kernel)
                bootedPluginKeys.append(key)
            }

            // 可配置插件随后启动
            for key in orderedPluginKeys {
                guard let plugin = pluginRegistry[key] else { continue }
                guard type(of: plugin).metadata.policy != .alwaysOn else { continue }
                guard isPluginEnabled(plugin) else {
                    if Self.verbose { os_log("\(Self.t)⏭️ Skipping disabled plugin: \(plugin.id)") }
                    continue
                }
                try await bootPlugin(plugin, kernel: kernel)
                bootedPluginKeys.append(key)
            }
        } catch {
            await teardownAll(kernel: kernel)
            throw error
        }
    }

    /// 启动单个插件。
    private func bootPlugin(_ plugin: any SuperPlugin, kernel: CisumKernelContainer) async throws {
        if Self.verbose { os_log("\(Self.t)🔌 onBoot for plugin: \(plugin.id)") }
        kernel.activePluginID = plugin.id
        defer { kernel.activePluginID = nil }
        do {
            try await plugin.onBoot(kernel: kernel)
        } catch {
            try rethrow(error, from: plugin)
        }
    }

    /// 将插件抛出的错误包装为携带插件 ID 的 `pluginFailed`，便于报错视图定位来源。
    ///
    /// 已包装为 `pluginFailed` 的错误原样透传，避免重复包装。
    private func rethrow(_ error: Error, from plugin: any SuperPlugin) throws {
        if let kernelError = error as? CisumKernelError, case .pluginFailed = kernelError {
            throw error
        }
        throw CisumKernelError.pluginFailed(pluginID: plugin.id, message: error.localizedDescription)
    }

    /// 阶段 2: OnReady —— 依赖服务的异步初始化。
    ///
    /// 在所有 `onBoot` 完成后统一调用所有内核感知插件的 `onReady(kernel:)`。
    /// 任一插件失败时回滚全部已启动插件（逆序 `onShutdown` + `onUnregister`），
    /// 避免留下半初始化状态。
    ///
    /// - Parameter kernel: 内核容器实例。
    func onReady(kernel: CisumKernelContainer) async throws {
        do {
            for key in orderedPluginKeys {
                guard let plugin = pluginRegistry[key] else { continue }
                guard isPluginEnabled(plugin) else { continue }

                if Self.verbose { os_log("\(Self.t)🚀 onReady for: \(plugin.id)") }
                kernel.activePluginID = plugin.id
                do {
                    try await plugin.onReady(kernel: kernel)
                } catch {
                    kernel.activePluginID = nil
                    try rethrow(error, from: plugin)
                }
                kernel.activePluginID = nil
            }
        } catch {
            await teardownAll(kernel: kernel)
            throw error
        }
    }

    // MARK: - Shutdown & Rollback

    /// 停止并注销全部插件，供内核关闭时调用。
    ///
    /// 已启动插件按启动逆序执行 `onShutdown`，
    /// 随后全部插件逆序执行 `onUnregister`，最后清空注册表。清理过程中单个插件
    /// 的失败不会阻断其他插件清理。
    ///
    /// - Parameter kernel: 内核容器实例。
    public func shutdown(kernel: CisumKernelContainer) async {
        await teardownAll(kernel: kernel)
    }

    /// 逆序停止已启动插件，并注销全部插件、清空注册表。
    private func teardownAll(kernel: CisumKernelContainer) async {
        // 逆序停止已成功 onBoot 的插件
        for key in bootedPluginKeys.reversed() {
            guard let plugin = pluginRegistry[key] else { continue }
            await shutdownPlugin(plugin, kernel: kernel)
        }

        // 逆序注销全部已注册插件（撤回注册期贡献）
        for key in orderedPluginKeys.reversed() {
            guard let plugin = pluginRegistry[key] else { continue }
            if Self.verbose { os_log("\(Self.t)🗑️ onUnregister for: \(plugin.id)") }
            kernel.activePluginID = plugin.id
            try? await plugin.onUnregister(kernel: kernel)
            kernel.activePluginID = nil
        }

        bootedPluginKeys.removeAll()
        pluginRegistry.removeAll()
        orderedPluginKeys.removeAll()
        usedIDs.removeAll()

        if Self.verbose { os_log("\(Self.t)🧹 Teardown complete") }
    }

    /// 停止单个插件。
    private func shutdownPlugin(_ plugin: any SuperPlugin, kernel: CisumKernelContainer) async {
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown for: \(plugin.id)") }
        kernel.activePluginID = plugin.id
        try? await plugin.onShutdown(kernel: kernel)
        kernel.activePluginID = nil
    }

    // MARK: - Contribution Aggregation

    /// 启动期：失效插件视图缓存，并将主题贡献同步到 CisumUI。
    ///
    /// 在 `startup()` 的 `onReady` 之后调用一次。
    func registerPluginUIContributions(in kernel: CisumKernelContainer) {
        refreshContributions(in: kernel)
    }

    /// 运行期：插件启用/禁用变更后重建全部贡献。
    public func rebuildAllContributions(in kernel: CisumKernelContainer) {
        refreshContributions(in: kernel)
        kernel.eventManager.postEnabledPluginsDidChange()
    }

    /// 失效插件视图缓存 + 重新同步主题到 CisumUI。
    private func refreshContributions(in kernel: CisumKernelContainer) {
        kernel.plugin?.invalidateCaches()
        kernel.theme?.reloadThemes()
        kernel.theme?.syncToCisumUI()
    }

    // MARK: - Plugin Enable State

    /// 判断插件最终是否启用（结合策略 + 用户覆盖）。
    public func isPluginEnabled(_ plugin: any SuperPlugin) -> Bool {
        let metadata = type(of: plugin).metadata
        return Self.effectiveEnabled(
            policy: metadata.policy,
            override: stateStore?.override(for: plugin.id)
        )
    }

    /// 获取用户对某插件的启用/禁用覆盖值。
    public func override(for pluginID: String) -> Bool? {
        stateStore?.override(for: pluginID)
    }

    /// 设置用户对某插件的启用/禁用覆盖值。
    public func setOverride(_ enabled: Bool, for pluginID: String) {
        stateStore?.setOverride(enabled, for: pluginID)
    }

    /// 清除用户对某插件的覆盖，回落到策略默认值。
    public func clearOverride(for pluginID: String) {
        stateStore?.clearOverride(for: pluginID)
    }

    /// 运行期启用插件：写入用户覆盖 + 重建全部贡献（对齐 Lumi
    /// `KernelCore.enablePlugin(id:)`）。
    ///
    /// 不可由用户切换的插件（alwaysOn / disabled）会拒绝并抛错。
    public func enablePlugin(id: String, kernel: CisumKernelContainer) async throws {
        guard let plugin = plugin(by: id) else {
            throw CisumKernelError.pluginNotFound(id: id)
        }
        guard type(of: plugin).metadata.policy.allowUserToggle else {
            throw CisumKernelError.pluginNotConfigurable(id: id)
        }
        setOverride(true, for: id)
        kernel.activePluginID = id
        do {
            try await plugin.onEnable(kernel: kernel)
        } catch {
            kernel.activePluginID = nil
            setOverride(false, for: id)
            throw error
        }
        kernel.activePluginID = nil
        rebuildAllContributions(in: kernel)
    }

    /// 运行期禁用插件：写入用户覆盖 + 重建全部贡献（对齐 Lumi
    /// `KernelCore.disablePlugin(id:)`）。
    ///
    /// 不可由用户切换的插件（alwaysOn / disabled）会拒绝并抛错。
    public func disablePlugin(id: String, kernel: CisumKernelContainer) async throws {
        guard let plugin = plugin(by: id) else {
            throw CisumKernelError.pluginNotFound(id: id)
        }
        guard type(of: plugin).metadata.policy.allowUserToggle else {
            throw CisumKernelError.pluginNotConfigurable(id: id)
        }
        kernel.activePluginID = id
        do {
            try await plugin.onDisable(kernel: kernel)
        } catch {
            kernel.activePluginID = nil
            throw error
        }
        kernel.activePluginID = nil
        setOverride(false, for: id)
        rebuildAllContributions(in: kernel)
    }

    /// 解析插件的最终启用状态。
    ///
    /// - Parameters:
    ///   - policy: 插件策略。
    ///   - override: 用户覆盖值（可能为 nil）。
    /// - Returns: 最终是否启用。
    static func effectiveEnabled(policy: PluginPolicy, override: Bool?) -> Bool {
        switch policy {
        case .alwaysOn:
            true
        case .disabled:
            false
        case .optOut:
            override ?? true
        case .optIn:
            override ?? false
        }
    }

    /// 获取所有已注册的插件实例（仅已启用的）。
    public var enabledPlugins: [any SuperPlugin] {
        orderedPluginKeys.compactMap { pluginRegistry[$0] }.filter { isPluginEnabled($0) }
    }

    /// 获取所有已注册的插件实例（包含未启用的）。
    public var allPlugins: [any SuperPlugin] {
        orderedPluginKeys.compactMap { pluginRegistry[$0] }
    }

    /// 根据插件 ID 查找插件。
    ///
    /// - Parameter id: 插件 ID。
    /// - Returns: 找到的插件或 nil。
    public func plugin(by id: String) -> (any SuperPlugin)? {
        pluginRegistry.values.first { $0.id == id }
    }

    // MARK: - Private

    /// 注册单个插件到内部注册表。
    private func register(_ plugin: any SuperPlugin) {
        let id = plugin.id

        // 重复检测
        guard !usedIDs.contains(id) else {
            let pluginType = String(describing: type(of: plugin))
            os_log(.error, "\(Self.t)❌ Duplicate plugin id '\(id)' in \(pluginType)")
            assertionFailure("Duplicate plugin id: \(id)")
            return
        }

        guard !id.isEmpty else {
            os_log(.error, "\(Self.t)❌ Plugin with empty ID: \(String(describing: type(of: plugin)))")
            assertionFailure("Plugin has empty ID")
            return
        }

        usedIDs.insert(id)

        // 使用版本化类型名称作为键，避免同类型多次注册时的冲突
        let key = String(describing: type(of: plugin))
        let versionedKey = makeVersionedKey(base: key, id: id)
        pluginRegistry[versionedKey] = plugin
        orderedPluginKeys.append(versionedKey)
    }

    /// 生成版本化键，避免名字冲突。
    private func makeVersionedKey(base: String, id: String) -> String {
        // 如果 base 键尚未使用，直接返回
        if pluginRegistry[base] == nil {
            return base
        }
        // 否则使用 ID 作为后缀
        return "\(base)-\(id)"
    }

    /// 获取日志前缀（静态，方便在非隔离上下文中使用）。
    nonisolated private static var t: String {
        let author = "BuiltinPluginManager"
        return "[KT] | \(Self.emoji) \(author.padding(toLength: 22, withPad: " ", startingAt: 0)) | "
    }
}
