import KernelCore
import CisumUIComponents
import SwiftUI

/// 设置窗口：各插件贡献的一级导航入口，双栏布局（对齐 Lumi `ProviderSettingView`）。
///
/// 每个插件通过 `addSettingNavigationItem()` 贡献自己的设置入口（对齐 Lumi
/// 各插件 `SettingViewProviding.addEntries` 一个入口的范式），窗口不再聚合
/// 「插件设置」列表。
///
/// - 左侧：插件 `addSettingNavigationItem` 贡献的导航入口；
/// - 右侧：选中导航入口的内容。
///
/// 本视图只依赖插件设置能力契约（`PluginProviding`），不依赖内核或工厂具体类型；
/// 由宿主（CisumFactory）从内核解析 Provider 后注入。
public struct SettingsWindow: View {
    @State private var selection: String
    @LumiTheme private var appTheme

    @StateObject private var viewModel: SettingsWindowViewModel

    private let settings: (any PluginProviding)?
    public init(
        settings: (any PluginProviding)?
    ) {
        self.settings = settings
        self._viewModel = StateObject(wrappedValue: SettingsWindowViewModel(settings: settings))
        self._selection = State(initialValue: "")
    }

    public var body: some View {
        let navItems = viewModel.navigationItems
        // 未选中时默认展示首个入口。
        let currentSelection = selection.isEmpty ? (navItems.first?.id ?? "") : selection

        Group {
            if !navItems.isEmpty {
                #if os(macOS)
                macOSSplitView(navItems: navItems, currentSelection: currentSelection)
                #else
                iOSList(navItems: navItems, currentSelection: currentSelection)
                #endif
            } else {
                ContentUnavailableView(
                    String(localized: "No settings available", bundle: .module),
                    systemImage: "gearshape",
                    description: Text("No plugin has contributed any settings yet")
                )
            }
        }
        .appThemedAppearance()
#if os(macOS)
        .overlay { ThemeWindowAppearanceBridge().allowsHitTesting(false) }
#endif
    }

    #if os(macOS)
    /// macOS：双栏，对齐 Lumi `AppSettingsSidebarShell`（HStack）结构
    /// （左侧 `AppSettingsSidebarContainer` 顶部 Header + 分隔线 + 入口列表，
    /// 右侧 `AppSettingsDetailPane` 铺满整窗），不再使用 `NavigationSplitView`
    /// 以避免 detail 列默认的顶部系统 inset 空白。
    private func macOSSplitView(
        navItems: [PluginSettingNavigationItem],
        currentSelection: String
    ) -> some View {
        AppSettingsSidebarShell {
            AppSettingsSidebarContainer(width: 220) {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsHeaderView()

                    AppSettingsDivider()

                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(navItems) { item in
                                AppSettingsSidebarItem(
                                    title: item.title,
                                    systemImage: item.iconName,
                                    isSelected: currentSelection == item.id
                                ) {
                                    selection = item.id
                                }
                            }
                        }
                        .padding(.leading)
                        .padding(.trailing)
                    }

                    Spacer()
                }
            }
        } detail: {
            AppSettingsDetailPane {
                detailContent(navItems: navItems, currentSelection: currentSelection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
    }
    #else
    /// iOS：各插件一级入口同样可交互选择，右侧展示选中入口内容。
    private func iOSList(
        navItems: [PluginSettingNavigationItem],
        currentSelection: String
    ) -> some View {
        NavigationSplitView {
            List {
                Section("Settings") {
                    ForEach(navItems) { item in
                        Button {
                            selection = item.id
                        } label: {
                            Label(item.title, systemImage: item.iconName)
                                .foregroundStyle(currentSelection == item.id ? appTheme.primary : appTheme.textPrimary)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            detailContent(navItems: navItems, currentSelection: currentSelection)
        }
    }
    #endif

    @ViewBuilder
    private func detailContent(
        navItems: [PluginSettingNavigationItem],
        currentSelection: String
    ) -> some View {
        if let selected = navItems.first(where: { $0.id == currentSelection }) {
            selected.destination
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ContentUnavailableView(
                String(localized: "Select a Setting", bundle: .module),
                systemImage: "gearshape",
                description: Text("Select a setting from the left")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
