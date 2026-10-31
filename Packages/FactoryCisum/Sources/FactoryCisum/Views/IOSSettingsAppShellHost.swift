#if os(iOS)
import KernelCore
import LumiThemePack
import LumiUI
import ProviderSettingView
import ProviderSettingsHost
import ProviderTheme
import ProviderToolbar
import SwiftUI

/// iOS 设置外壳宿主：把主视图包进 `IOSSettingsAppShell`。
///
/// iOS 没有独立的设置窗口 Scene（macOS 用 `Window` + `openWindow`），
/// 因此设置页以 **sheet** 形式呈现。呈现链路：
///
/// 1. `SettingsButtonPlugin` 把齿轮贡献到 `IOSNavigationBarProviding`；
/// 2. 齿轮点击后广播 `SettingViewNavigation.openSettingsNotification`；
/// 3. `IOSSettingsAppShell` 监听该通知并弹出设置 sheet。
///
/// 导航栏归属用 `.host` 模式：Cisum 业务根视图自己创建 `NavigationStack`，
/// SwiftUI 不会把外层 `.toolbar` 传递进嵌套的导航栈，因此齿轮必须由
/// **导航栈的所有者**（业务根视图）在栈**内部的内容上**挂载 —— 见
/// `PluginRootView` 的 `IOSNavigationBarItemsBridge` 接入。
///
/// 主题：设置 sheet 出现时要把 `ThemeProviding` 选中的主题桥接到 LumiUI
/// 主题体系（`ActiveChromeTheme` / `LumiUIThemeStore`），否则设置详情页的
/// 系统控件（GroupBox / 导航栏）会与主题配色混搭。
@MainActor
struct IOSSettingsAppShellHost: View {
    let kernel: KernelCoreContainer
    let mainView: AnyView

    init(kernel: KernelCoreContainer, mainView: AnyView) {
        self.kernel = kernel
        self.mainView = mainView
    }

    var body: some View {
        Group {
            if let navigationBar = kernel.resolveProvider((any IOSNavigationBarProviding).self) {
                IOSSettingsAppShell(
                    title: AppBootstrap.appName,
                    mainView: mainView,
                    settingsView: makeSettingsView(),
                    navigationBarProvider: navigationBar,
                    navigationBarMode: .host
                )
            } else {
                mainView
            }
        }
    }

    /// 组装设置 sheet 内容：设置外壳 + 主题宿主。
    private func makeSettingsView() -> AnyView {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            return AnyView(Text("Settings unavailable", bundle: .module))
        }
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else {
            return AnyView(settings.makeSettingView())
        }
        return AnyView(
            IOSSettingsThemedHost(
                theme: theme,
                content: AnyView(settings.makeSettingView())
            )
        )
    }
}

/// 设置 sheet 的主题宿主：出现时及主题切换后重新桥接 LumiUI 主题，
/// 并用 `appThemedAppearance()` 把 sheet 的明暗外观（导航栏、GroupBox
/// 等系统控件）同步为当前主题，避免「主题暗色底 + 系统亮色控件」的混搭。
@MainActor
private struct IOSSettingsThemedHost: View {
    let theme: any ThemeProviding
    let content: AnyView

    @StateObject private var observation: ThemeObservationModel
    @State private var refreshTick = false

    init(theme: any ThemeProviding, content: AnyView) {
        self.theme = theme
        self.content = content
        _observation = StateObject(wrappedValue: ThemeObservationModel(theme: theme))
    }

    var body: some View {
        content
            .appThemedAppearance()
            .onAppear { syncTheme() }
            .onReceive(observation.$revision) { _ in
                refreshTick.toggle()
                syncTheme()
            }
    }

    private func syncTheme() {
        IOSSettingsAppShellHost.syncLumiTheme(theme)
    }
}

/// 监听 `ThemeProviding` 事件（主题切换 / 注册），驱动设置页重新桥接。
@MainActor
private final class ThemeObservationModel: ObservableObject {
    @Published private(set) var revision = 0
    private var handle: (any ThemeProvidingObserverHandle)?

    init(theme: any ThemeProviding) {
        handle = theme.addObserver { [weak self] _ in
            self?.revision += 1
        }
    }
}

extension IOSSettingsAppShellHost {
    /// 把 `ThemeProviding` 选中的主题桥接到 LumiUI 主题体系
    /// （`ResolvedSystemColorScheme` / `ActiveChromeTheme` / `LumiUIThemeStore`），
    /// 与 macOS 侧 `CisumThemeBridge` 保持同一套语义。
    static func syncLumiTheme(_ provider: any ThemeProviding) {
        guard let selected = provider.selectedTheme else { return }
        let colorScheme: ColorScheme
        switch selected.appearanceKind {
        case .dark:
            colorScheme = .dark
        case .light:
            colorScheme = .light
        case .system:
            colorScheme = SystemAppearanceResolver.effectiveColorScheme
        }

        ResolvedSystemColorScheme.current = colorScheme

        let chrome = LumiPaletteChromeTheme(theme: selected, colorScheme: colorScheme)
        ActiveChromeTheme.current = chrome
        LumiUIThemeStore.shared.setTheme(ChromeToUIThemeAdapter(chrome: chrome))
    }
}
#endif
