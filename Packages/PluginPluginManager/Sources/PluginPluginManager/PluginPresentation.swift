import KernelCore

/// UI-only presentation values for KernelCore's display-agnostic plugin metadata.
enum PluginCategoryPresentation {
    static let categories: [PluginCategory] = [
        .core, .chat, .llm, .editor, .project, .feature, .system, .design, .integration, .general,
    ]

    static func title(for category: PluginCategory) -> String {
        switch category {
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

    static func icon(for category: PluginCategory) -> String {
        switch category {
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

    static func order(of category: PluginCategory) -> Int {
        categories.firstIndex(of: category) ?? categories.count
    }
}

enum PluginStagePresentation {
    static func title(for stage: PluginStage) -> String {
        switch stage {
        case .experimental: "Experimental"
        case .preview: "Preview"
        case .stable: "Stable"
        case .deprecated: "Deprecated"
        }
    }
}
