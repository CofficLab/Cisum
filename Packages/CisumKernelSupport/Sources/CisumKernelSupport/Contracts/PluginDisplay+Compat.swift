import KernelCore
import SwiftUI

// MARK: - PluginCategory 展示兼容（对齐旧 Cisum PluginCategory）

extension PluginCategory: CaseIterable {
    public static var allCases: [PluginCategory] {
        [.core, .chat, .llm, .editor, .project, .feature, .system, .design, .integration, .general]
    }
}

public extension PluginCategory {
    /// 分类展示名（插件管理筛选栏 / 详情 chips）。
    var displayName: String {
        switch self {
        case .core: "Core"
        case .chat: "Chat"
        case .llm: "LLM"
        case .editor: "Editor"
        case .project: "Project"
        case .feature: "Feature"
        case .system: "System"
        case .design: "Design"
        case .integration: "Integration"
        case .general: "General"
        }
    }

    /// 分类展示图标。
    var systemImage: String {
        switch self {
        case .core: "sparkles"
        case .chat: "bubble.left.and.bubble.right"
        case .llm: "brain.head.profile"
        case .editor: "pencil.and.outline"
        case .project: "folder"
        case .feature: "hammer"
        case .system: "cpu"
        case .design: "paintpalette"
        case .integration: "square.stack.3d.up"
        case .general: "square.grid.2x2"
        }
    }

    /// 分类在筛选栏的排序（按枚举声明顺序）。
    var sortOrder: Int {
        PluginCategory.allCases.firstIndex(of: self) ?? 999
    }
}

// MARK: - PluginStage 展示兼容

public extension PluginStage {
    /// 阶段展示名。
    var displayName: String {
        switch self {
        case .experimental: "Experimental"
        case .preview: "Preview"
        case .stable: "Stable"
        case .deprecated: "Deprecated"
        }
    }
}

// MARK: - PluginEnablePolicy 展示兼容

public extension PluginEnablePolicy {
    /// 策略展示名。
    var displayName: String {
        switch self {
        case .required: "Required"
        case .alwaysOn: "Always Enabled"
        case .enabledByDefault: "Enabled by Default"
        case .disabledByDefault: "Disabled by Default"
        case .disabled: "Disabled"
        }
    }
}
