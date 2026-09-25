import KernelCore
import SwiftUI

// MARK: - PluginMetadata 兼容访问器（对齐 Lumi 命名）

extension PluginMetadata {
    /// 展示名（对齐旧 Cisum `PluginMetadata.displayName`）。
    public var displayName: String { name }
}

// MARK: - SuperPlugin 应用特有扩展（Cisum 宿主层）

public extension SuperPlugin {
    /// 插件展示图标（Cisum 应用特有；插件可覆盖）。
    var iconName: String { "puzzlepiece.extension" }

    /// 插件显示标签（对齐旧 Cisum `SuperPlugin.label`）。
    var label: String { id }

    /// 插件标题（对齐旧 Cisum `SuperPlugin.title`）。
    var title: String { metadata.name }

    /// 插件描述（对齐旧 Cisum `SuperPlugin.description`）。
    var description: String { metadata.description }
}
