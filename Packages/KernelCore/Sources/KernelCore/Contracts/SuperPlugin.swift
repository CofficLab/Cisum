import CisumUIComponents
import SwiftUI

public enum PluginPolicy: String, Sendable, Codable {
    case alwaysOn
    case optOut
    case optIn
    case disabled

    public var shouldRegister: Bool {
        self != .disabled
    }

    public var allowUserToggle: Bool {
        switch self {
        case .alwaysOn, .disabled:
            false
        case .optOut, .optIn:
            true
        }
    }

    public var defaultEnabled: Bool {
        switch self {
        case .alwaysOn, .optOut:
            true
        case .optIn, .disabled:
            false
        }
    }
}

/// 插件分类（对齐 Lumi `PluginCategory`），用于插件管理列表的分类筛选与图标。
public enum PluginCategory: String, Codable, Sendable, CaseIterable {
    /// 核心能力（场景、通用设置、插件管理等）。
    case core
    /// 媒体库（音乐库 / 有声书 / 存储）。
    case library
    /// 播放控制（控制 / 播放模式 / 进度 / 下载）。
    case playback
    /// 喜欢与收藏。
    case like
    /// 设置与商店。
    case settings
    /// 外观主题。
    case theme
    /// 工具（演示 / 复制 / 小组件 / 欢迎）。
    case tool
    /// 系统能力（设备 / 日志 / 迁移 / 重置）。
    case system
    /// 通用（未归类）。
    case general

    /// 分类展示名。
    public var displayName: String {
        switch self {
        case .core: String(localized: "Core", bundle: .module)
        case .library: String(localized: "Media Library", bundle: .module)
        case .playback: String(localized: "Play", bundle: .module)
        case .like: String(localized: "Favorite", bundle: .module)
        case .settings: String(localized: "Settings", bundle: .module)
        case .theme: String(localized: "Theme", bundle: .module)
        case .tool: String(localized: "Tools", bundle: .module)
        case .system: String(localized: "System", bundle: .module)
        case .general: String(localized: "General", bundle: .module)
        }
    }

    /// 分类展示图标。
    public var systemImage: String {
        switch self {
        case .core: "sparkles"
        case .library: "books.vertical"
        case .playback: "play.circle"
        case .like: "heart"
        case .settings: "gearshape"
        case .theme: "paintpalette"
        case .tool: "hammer"
        case .system: "cpu"
        case .general: "square.grid.2x2"
        }
    }

    /// 分类在筛选栏的排序。
    public var sortOrder: Int {
        switch self {
        case .core: 0
        case .library: 1
        case .playback: 2
        case .like: 3
        case .settings: 4
        case .theme: 5
        case .tool: 6
        case .system: 7
        case .general: 8
        }
    }
}

/// 插件成熟阶段（对齐 Lumi `PluginStage`），用于插件管理详情中的阶段标签。
public enum PluginStage: String, Codable, Sendable {
    case experimental
    case preview
    case stable
    case deprecated

    public var displayName: String {
        switch self {
        case .experimental: String(localized: "Experimental", bundle: .module)
        case .preview: String(localized: "Preview", bundle: .module)
        case .stable: String(localized: "Stable", bundle: .module)
        case .deprecated: String(localized: "Deprecated", bundle: .module)
        }
    }
}

/// 插件权限声明（对齐 Lumi `PluginPermission`），用于插件管理详情中的权限清单。
public struct PluginPermission: Hashable, Codable, Sendable {
    public let id: String
    public let reason: String

    public init(id: String, reason: String) {
        self.id = id
        self.reason = reason
    }
}

public struct PluginMetadata: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let iconName: String
    public let order: Int
    public let policy: PluginPolicy
    public let category: PluginCategory
    public let stage: PluginStage
    public let version: String
    public let permissions: [PluginPermission]

    /// 展示名别名（对齐 Lumi `PluginMetadata.name`）。
    public var name: String { displayName }

    public var shouldRegister: Bool {
        policy.shouldRegister
    }

    public init(
        id: String = "",
        displayName: String,
        description: String,
        iconName: String = "puzzlepiece.extension",
        order: Int = 9999,
        policy: PluginPolicy = .disabled,
        category: PluginCategory = .general,
        stage: PluginStage = .stable,
        version: String = "1.0.0",
        permissions: [PluginPermission] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.iconName = iconName
        self.order = order
        self.policy = policy
        self.category = category
        self.stage = stage
        self.version = version
        self.permissions = permissions
    }
}

public struct PluginSettingNavigationItem: Identifiable {
    public let id: String
    public let title: String
    public let description: String?
    public let iconName: String
    public let order: Int
    public let destination: AnyView

    public init(
        id: String,
        title: String,
        description: String? = nil,
        iconName: String,
        order: Int,
        destination: AnyView
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.iconName = iconName
        self.order = order
        self.destination = destination
    }
}

public protocol SuperPlugin: Actor {
    static var shared: Self { get }
    static var metadata: PluginMetadata { get }

    nonisolated var id: String { get }
    nonisolated var label: String { get }
    nonisolated var title: String { get }
    nonisolated var description: String { get }
    nonisolated var iconName: String { get }

    static var order: Int { get }
    static var shouldRegister: Bool { get }

    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View
    @MainActor func addGuideView() -> AnyView?
    @MainActor func completeGuidePage() -> Bool
    @MainActor func addStateView() -> AnyView?
    @MainActor func addPosterView() -> AnyView?
    @MainActor func addTabView(reason: String, demoMode: Bool) -> (view: AnyView, label: String)?
    @MainActor func addSettingView() -> AnyView?
    @MainActor func addSettingNavigationItem() -> PluginSettingNavigationItem?
    @MainActor func addStatusView() -> AnyView?
    @MainActor func addToolBarButtons() -> [(id: String, view: AnyView)]
    @MainActor func addThemeContributions() -> [LumiUIThemeContribution]
    @MainActor func addHeroView() -> AnyView?
    @MainActor func addRightAlbumView() -> AnyView?
    @MainActor func addControlButtonsView() -> AnyView?
    @MainActor func addProgressView() -> AnyView?

    /// 注册阶段：插件可向 Kernel 注册 Provider 或共享目录贡献。
    @MainActor func onRegister(kernel: CisumKernelContainer) async throws
    /// 启动阶段：所有已注册 Provider 可被插件使用。
    @MainActor func onBoot(kernel: CisumKernelContainer) async throws
    /// 就绪阶段：全部插件完成 Boot 后执行依赖初始化。
    @MainActor func onReady(kernel: CisumKernelContainer) async throws
    /// 停止阶段：撤回运行期 Provider、监听器和外部资源。
    @MainActor func onShutdown(kernel: CisumKernelContainer) async throws
    /// 注销阶段：撤回注册阶段的目录型贡献。
    @MainActor func onUnregister(kernel: CisumKernelContainer) async throws

    /// 运行时启用：恢复被禁用时停止的监听器与外部资源。
    @MainActor func onEnable(kernel: CisumKernelContainer) async throws
    /// 运行时禁用：停止监听器与外部资源。
    @MainActor func onDisable(kernel: CisumKernelContainer) async throws
}

public extension SuperPlugin {
    static var metadata: PluginMetadata {
        PluginMetadata(
            id: String(describing: Self.self),
            displayName: String(describing: Self.self),
            description: "",
            order: 9999,
            policy: .alwaysOn
        )
    }

    nonisolated var id: String {
        let metadataId = Self.metadata.id
        return metadataId.isEmpty ? String(describing: Self.self) : metadataId
    }
    nonisolated var label: String { id }
    nonisolated var title: String { Self.metadata.displayName }
    nonisolated var description: String { Self.metadata.description }
    nonisolated var iconName: String { Self.metadata.iconName }
    static var order: Int { metadata.order }
    static var shouldRegister: Bool { metadata.shouldRegister }

    nonisolated func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View { nil }
    nonisolated func addGuideView() -> AnyView? { nil }
    nonisolated func completeGuidePage() -> Bool { true }
    nonisolated func addStateView() -> AnyView? { nil }
    nonisolated func addPosterView() -> AnyView? { nil }
    @MainActor func addTabView(reason: String, demoMode: Bool = false) -> (view: AnyView, label: String)? { nil }
    nonisolated func addSettingView() -> AnyView? { nil }
    nonisolated func addSettingNavigationItem() -> PluginSettingNavigationItem? { nil }
    nonisolated func addStatusView() -> AnyView? { nil }
    nonisolated func addToolBarButtons() -> [(id: String, view: AnyView)] { [] }
    @MainActor func addThemeContributions() -> [LumiUIThemeContribution] { [] }
    @MainActor func addHeroView() -> AnyView? { nil }
    @MainActor func addRightAlbumView() -> AnyView? { nil }
    @MainActor func addControlButtonsView() -> AnyView? { nil }
    @MainActor func addProgressView() -> AnyView? { nil }

    @MainActor func onRegister(kernel: CisumKernelContainer) async throws {}
    @MainActor func onBoot(kernel: CisumKernelContainer) async throws {}
    @MainActor func onReady(kernel: CisumKernelContainer) async throws {}
    @MainActor func onShutdown(kernel: CisumKernelContainer) async throws {}
    @MainActor func onUnregister(kernel: CisumKernelContainer) async throws {}
    @MainActor func onEnable(kernel: CisumKernelContainer) async throws {}
    @MainActor func onDisable(kernel: CisumKernelContainer) async throws {}
}

public extension SuperPlugin {
    @MainActor
    func provideRootView(_ content: AnyView) -> AnyView? {
        addRootView { content }
    }

    @MainActor
    func wrapRoot(_ content: AnyView) -> AnyView {
        provideRootView(content) ?? content
    }
}
