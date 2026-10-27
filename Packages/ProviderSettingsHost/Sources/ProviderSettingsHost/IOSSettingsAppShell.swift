import ProviderSettingView
import ProviderToolbar
import SwiftUI

#if os(iOS)
/// GameFactory iOS host shell.
///
/// The app owns presentation of the settings sheet; the shared settings
/// component (`ProviderSettingView`) owns the list and the detail navigation.
///
/// 导航栏说明：导航栏归属由 `navigationBarMode` 决定。
///
/// - `.host`（推荐）：宿主 App 自己拥有 `NavigationStack`，系统导航栏由那条栈
///   渲染。插件贡献的导航栏项（设置齿轮等）由宿主在**栈级别**挂载 —— SwiftUI
///   不会把**外层**的 `.toolbar` 传递进嵌套的导航栈，所以必须由导航栈的
///   所有者来挂。外壳此时**不自绘**任何导航条，避免出现「自绘条 + 系统条」
///   的双导航栏。
/// - `.overlay`：宿主自身没有系统导航栈时使用，外壳自绘一条 48pt 导航条来
///   承载插件贡献的导航栏项。已有 `NavigationStack` 的宿主不要用这个模式。
@MainActor
public struct IOSSettingsAppShell: View {
    /// 导航栏归属模式。
    public enum NavigationBarMode: Sendable {
        /// 宿主 App 拥有自己的导航栈，由宿主在栈级别挂载导航栏项。
        case host
        /// 外壳自绘导航条承载导航栏项（兼容没有系统导航栈的宿主）。
        case overlay
    }

    private let settingsView: AnyView
    private let navigationBarMode: NavigationBarMode

    @State private var isSettingsPresented = false

    public init(
        title: String,
        mainView: AnyView,
        settingsView: AnyView,
        navigationBarProvider: any IOSNavigationBarProviding,
        navigationBarMode: NavigationBarMode = .overlay
    ) {
        // `title` 与 `navigationBarProvider` 仅在 `.overlay` 模式下用于自绘
        // 导航条；`.host` 模式下标题由宿主自己的导航栈决定，导航栏项由宿主
        // 用 `IOSNavigationBarItemsBridge` 自行挂载。
        self.title = title
        self.navigationBarProvider = navigationBarProvider
        self.navigationBarMode = navigationBarMode
        self.settingsView = settingsView
        self.mainView = mainView
    }

    private let title: String
    private let mainView: AnyView
    private let navigationBarProvider: any IOSNavigationBarProviding

    public var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: SettingViewNavigation.openSettingsNotification)) { _ in
                isSettingsPresented = true
            }
            .sheet(isPresented: $isSettingsPresented) {
                settingsView
                    // 设置根页是「页面选择器 + 列表」，半屏高度会挤掉分组、
                    // 搜索框和条目，因此固定全屏（仍可下拉关闭）。
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch navigationBarMode {
        case .host:
            mainView
        case .overlay:
            VStack(spacing: 0) {
                IOSNavigationBarHost(title: title, provider: navigationBarProvider)
                mainView
            }
        }
    }
}
#endif
