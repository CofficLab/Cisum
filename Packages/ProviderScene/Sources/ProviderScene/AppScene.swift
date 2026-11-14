import Foundation

/// 应用内置的固定场景。
///
/// 场景由场景 Provider 直接内置并固定（如「音乐库」「有声书」），不再由插件
/// 通过 `SuperPlugin.addSceneItem()` 动态贡献；插件只能消费场景，不能新增场景。
///
/// 枚举的 `rawValue` 与历史场景名保持一致（"Music Library" / "Audiobooks"），
/// 使已持久化的当前场景数据（JSON 与 UserDefaults 旧键）无需迁移即可继续恢复。
///
/// > 命名为 `AppScene` 而非 `Scene`，以避开与 `SwiftUI.Scene` 在同时 import
/// > 两个模块的文件中的命名歧义。
public enum AppScene: String, CaseIterable, Sendable, Codable, Identifiable {
    /// 音乐库场景。
    case music = "Music Library"
    /// 有声书场景。
    case audiobooks = "Audiobooks"

    public var id: String { rawValue }

    /// Stable machine-readable suffix for accessibility identifiers.
    public var accessibilityID: String {
        switch self {
        case .music: "music"
        case .audiobooks: "audiobooks"
        }
    }

    /// 场景展示名（当前直接使用固定场景名，与历史行为一致）。
    public var displayName: String { rawValue }

    /// 场景在工具栏 / 设置中的图标名。
    public var iconName: String {
        switch self {
        case .music: "music.note.list"
        case .audiobooks: "book.closed"
        }
    }

    /// 场景展示顺序。
    public var order: Int {
        switch self {
        case .music: 0
        case .audiobooks: 1
        }
    }
}
