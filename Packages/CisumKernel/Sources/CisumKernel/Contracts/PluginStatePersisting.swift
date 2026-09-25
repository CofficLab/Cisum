import Foundation

// MARK: - Plugin enable-state persistence

/// 插件启用状态的持久化契约（对齐 Lumi `KernelCore.PluginStatePersisting`）。
///
/// KernelCore 不绑定具体的文件或 UserDefaults 实现；宿主（存储插件）负责注入存储。
@MainActor
public protocol PluginStatePersisting: AnyObject {
    /// 返回插件的持久化启用状态覆盖；`nil` 表示没有用户覆盖（应回到策略默认值）。
    func override(for pluginID: String) -> Bool?

    /// 保存插件的启用状态覆盖并持久化。
    func setOverride(_ enabled: Bool, for pluginID: String)

    /// 删除插件的状态记录（回到策略默认值）。
    func clearOverride(for pluginID: String)
}
