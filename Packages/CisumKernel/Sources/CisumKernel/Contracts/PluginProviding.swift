import CisumUIComponents
import Foundation
import SwiftUI

@MainActor
public enum PluginProvidingEvent {
    case pluginsChanged
    case contributionsChanged
}

@MainActor
public protocol PluginProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 插件管理服务能力协议。
///
/// 提供插件的发现、生命周期管理以及 UI 贡献聚合。聚合规则继承自旧版
/// `PluginVM`：场景/海报/状态/标签页/工具栏/主题贡献的收集。当前场景的
/// 管理与持久化已独立到 `SceneProviding`（`kernel.scene`）。
///
/// ## 使用示例
///
/// ```swift
/// let allPlugins = kernel.plugin?.allPlugins ?? []
/// let tabs = kernel.plugin?.getTabViews(reason: "ContentView", demoMode: false) ?? []
/// ```
@MainActor
public protocol PluginProviding: AnyObject, ObservableObject {
    /// 所有已注册的插件。
    var allPlugins: [any SuperPlugin] { get }

    /// 获取所有插件提供的 status 视图。
    func getStatusViews() -> [AnyView]

    /// 获取所有插件提供的 state 视图。
    func getStateViews() -> [AnyView]

    /// 获取所有场景插件提供的海报视图。
    func getPosterViews() -> [AnyView]

    /// 获取首个引导视图（用于首启引导）。
    func getGuideView() -> AnyView?

    /// 获取所有插件提供的设置视图。
    func getSettingViews() -> [AnyView]

    /// 获取所有插件提供的设置导航项。
    func getSettingNavigationItems() -> [PluginSettingNavigationItem]

    /// 获取所有插件提供的标签页视图。
    ///
    /// - Parameters:
    ///   - reason: 调用原因（通常为调用者类名）。
    ///   - demoMode: 是否处于 Demo 模式。
    /// - Returns: 视图和标签名元组数组。
    func getTabViews(reason: String, demoMode: Bool) -> [(view: AnyView, label: String)]

    /// 用所有插件的 RootView 包裹内容视图。
    @MainActor func wrapWithCurrentRoot<Content: View>(@ViewBuilder content: () -> Content) -> AnyView?

    /// 获取所有插件提供的工具栏按钮。
    func getToolBarButtons() -> [(id: String, view: AnyView)]

    /// 获取所有插件贡献的主题（已重写 sortKey 并去重）。
    func getThemeContributions() -> [LumiUIThemeContribution]

    /// 获取首个插件提供的封面/标题视图。
    ///
    /// 播放控制区只保留一份封面区（单槽位），取第一个启用插件提供的贡献。
    func getHeroView() -> AnyView?

    /// 获取首个插件提供的右侧封面视图。
    func getRightAlbumView() -> AnyView?

    /// 获取首个插件提供的播放控制按钮视图。
    ///
    /// 播放控制区只保留一份按钮组（单槽位），取第一个启用插件提供的贡献。
    func getControlButtonsView() -> AnyView?

    /// 获取首个插件提供的播放进度视图。
    ///
    /// 播放控制区只保留一份进度条（单槽位），取第一个启用插件提供的贡献。
    func getProgressView() -> AnyView?

    /// 失效所有缓存的聚合结果。
    func invalidateCaches()

    @discardableResult
    func addObserver(_ callback: @escaping (PluginProvidingEvent) -> Void) -> any PluginProvidingObserverHandle
}

public extension PluginProviding {
    @discardableResult
    func addObserver(_ callback: @escaping (PluginProvidingEvent) -> Void) -> any PluginProvidingObserverHandle {
        NoopPluginProvidingObserverHandle()
    }
}

@MainActor
public final class NoopPluginProvidingObserverHandle: PluginProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}
