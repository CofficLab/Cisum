import Foundation

/// 数据存储位置类型。
///
/// 由 `StorageProviding` 暴露，统一描述应用持久化数据可落入的根位置。
/// 取值与历史 `Config` / `StoragePluginLocation` 保持一致。
///
/// - Note: 配置本身**不**存在 `UserDefaults` 里，而是由 `PluginStorage`
///   写进自己的数据目录（`<dataRoot>/<pluginID>/storage-location.json`）。
///   历史版本曾用 `UserDefaults` key `"StorageLocation"`，该键已废弃且
///   **不做迁移**——旧值作废，重新走一次首启选择即可。
public enum StorageLocation: String, Sendable, Codable, CaseIterable {
    /// iCloud 云端文档目录。
    case icloud
    /// 应用本地文档目录。
    case local
    /// 用户自定义位置（保留位，当前不可用）。
    case custom

    /// 用于展示的带 emoji 标题。
    public var emojiTitle: String {
        switch self {
        case .icloud: "🌐 iCloud"
        case .local: "💾 Local"
        case .custom: "🔧 Custom"
        }
    }

    /// 仅 emoji。
    public var emoji: String {
        switch self {
        case .icloud: "🌐"
        case .local: "💾"
        case .custom: "🔧"
        }
    }

    /// 不含 emoji 的标题。
    public var title: String {
        switch self {
        case .icloud: "iCloud"
        case .local: "Local"
        case .custom: "Custom"
        }
    }

    /// 人类可读描述。
    public var description: String {
        switch self {
        case .icloud: "Store data in iCloud, synced across devices"
        case .local: "Store data locally on this device"
        case .custom: "Use a custom storage location"
        }
    }
}
