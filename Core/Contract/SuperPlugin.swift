import OSLog
import SwiftUI

/// `SuperPlugin` 是 Cisum 应用的插件系统核心协议。
/// 所有插件必须实现此协议以便集成到应用程序中。
///
/// 该协议定义了插件的基本属性和行为，包括：
/// - 插件的标识和显示信息
/// - 插件在不同界面区域的视图渲染方法
/// - 插件的生命周期管理方法
protocol SuperPlugin: Actor {
    // MARK: - Basic Properties

    /// 插件的唯一标识符
    nonisolated var id: String { get }

    /// 插件的标签（用于显示和标识）
    nonisolated var label: String { get }

    /// 插件的标题
    nonisolated var title: String { get }

    /// 插件的描述
    nonisolated var description: String { get }

    /// 插件的图标名称
    nonisolated var iconName: String { get }

    /// 返回插件的场景名称，如果插件提供场景则返回场景名称，否则返回 nil

    @MainActor func addSceneItem() -> String?

    /// 插件注册顺序，数字越小越先注册
    static var order: Int { get }

    /// 插件是否应该注册到系统中
    /// 开发者可通过此属性控制插件是否启用
    static var shouldRegister: Bool { get }

    // MARK: - View Methods

    /// 添加根视图包裹
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View

    /// 添加引导视图
    @MainActor func addGuideView() -> AnyView?

    /// 添加弹窗视图
    @MainActor func addSheetView(storage: StorageLocation?) -> AnyView?

    /// 添加状态视图
    @MainActor func addStateView(currentSceneName: String?) -> AnyView?

    /// 添加海报视图
    @MainActor func addPosterView() -> AnyView?

    /// 添加标签页视图
    @MainActor func addTabView(reason: String, currentSceneName: String?, demoMode: Bool) -> (view: AnyView, label: String)?

    /// 添加设置视图
    @MainActor func addSettingView() -> AnyView?

    /// 添加状态栏视图
    @MainActor func addStatusView() -> AnyView?

    /// 添加工具栏按钮
    @MainActor func addToolBarButtons() -> [(id: String, view: AnyView)]

    // MARK: - Lifecycle Methods

    /// 插件注册完成后的回调
    ///
    /// 在插件成功注册到 PluginProvider 后调用。
    /// 用于执行初始化操作，如启动后台任务、注册监听器、初始化资源等。
    ///
    /// ## 使用示例
    /// ```swift
    /// actor MyPlugin: SuperPlugin {
    ///     nonisolated func onRegister() {
    ///         Task {
    ///             // 启动后台任务
    ///             await startBackgroundJob()
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// ## 注意事项
    /// - 此方法不在主线程上执行（使用 `nonisolated`）
    /// - 适合执行轻量级初始化和启动异步任务
    /// - 如果需要访问 actor 隔离状态，请使用 `Task { await ... }`
    /// - 不要在此方法中执行阻塞操作
    nonisolated func onRegister()
}

// MARK: - Default Implementations

extension SuperPlugin {
    // MARK: - Basic Properties Defaults

    nonisolated var id: String { self.label }

    nonisolated var label: String { String(describing: type(of: self)) }

    nonisolated var title: String { self.label }

    /// 默认的场景项实现，返回 nil 表示不提供场景
    @MainActor func addSceneItem() -> String? { nil }

    /// 默认的注册顺序实现
    static var order: Int {
        return 9999
    }

    // MARK: - View Methods Defaults

    nonisolated func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View { nil }

    nonisolated func addGuideView() -> AnyView? { nil }

    nonisolated func addSheetView(storage: StorageLocation?) -> AnyView? { nil }

    nonisolated func addStateView(currentSceneName: String?) -> AnyView? { nil }

    @MainActor func addTabView(reason: String, currentSceneName: String?, demoMode: Bool = false) -> (view: AnyView, label: String)? { nil }

    nonisolated func addPosterView() -> AnyView? { nil }

    nonisolated func addToolBarButtons() -> [(id: String, view: AnyView)] { [] }

    nonisolated func addStatusView() -> AnyView? { nil }

    nonisolated func addSettingView() -> AnyView? { nil }

    // MARK: - Lifecycle Defaults

    /// 默认的注册回调实现
    ///
    /// 默认不做任何事，子插件可以重写此方法以自定义注册后的行为。
    nonisolated func onRegister() {
        // 默认空实现，子类可以重写
    }
}

// MARK: - Convenience

extension SuperPlugin {
    @MainActor
    func provideRootView(_ content: AnyView) -> AnyView? {
        self.addRootView { content }
    }

    @MainActor
    func wrapRoot(_ content: AnyView) -> AnyView {
        if let wrapped = self.provideRootView(content) {
            return wrapped
        }
        return content
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
