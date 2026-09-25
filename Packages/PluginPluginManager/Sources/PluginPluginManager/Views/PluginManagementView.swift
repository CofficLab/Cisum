import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI

/// 插件管理设置页（对齐 Lumi `PluginPluginManager.PluginManagementView`）。
///
/// 两栏布局：左侧为插件列表（搜索 + 分类筛选），右侧为选中插件的详情
/// 与启用状态。数据源：`PluginManaging` Provider。列表与详情直接读取
/// Provider 的状态，并监听 `.cisumEnabledPluginsDidChange` 通知在启停后
/// 自动刷新。
///
/// 该文件只保留容器 / 布局 / 状态逻辑；具体渲染拆分为：
/// - `PluginManagementHeader`：顶部统计
/// - `PluginListRow`：列表单行
/// - `PluginSettingsDetailView`：右侧详情面板
struct PluginManagementView: View {
    @LumiTheme private var theme
    /// 文档视图提供器：详情面板按插件 id 匹配 about 条目并展示。
    /// 为 nil 时（宿主未提供 DocsViewProviding）详情面板回退到元信息展示。
    let docsProvider: (any DocsViewProviding)?

    @ObservedObject private var viewModel: PluginManagementViewModel

    @State private var selectedPluginID: String?
    @State private var searchText = ""
    @State private var selectedCategory: PluginCategory?

    init(docsProvider: (any DocsViewProviding)? = nil, viewModel: PluginManagementViewModel) {
        self.docsProvider = docsProvider
        self.viewModel = viewModel
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                PluginManagementHeader(totalCount: plugins.count, enabledCount: enabledCount)

                HStack(spacing: 0) {
                    pluginListPane
                        .frame(width: 300)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    pluginDetailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 520, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if selectedPluginID == nil {
                selectedPluginID = selectedPlugin?.id
            }
        }
        .onChange(of: filteredPlugins.map(\.id)) { _, ids in
            guard let selectedPluginID, ids.contains(selectedPluginID) else {
                self.selectedPluginID = ids.first
                return
            }
        }
    }

    // MARK: - Data Source

    /// 列表数据源：仅显示用户可配置的插件（对齐 Lumi 行为）。
    /// `alwaysOn` / `disabled` 不可配置，展示在列表中没有可操作控件，故过滤掉，
    /// 只保留 `optOut` / `optIn`（`allowUserToggle == true`）。
    private var plugins: [any SuperPlugin] {
        viewModel.plugins
    }

    /// 列表上出现的分类（按 `sortOrder` 排序），用于筛选标签栏。
    private var availableCategories: [PluginCategory] {
        let present = Set(plugins.map { $0.metadata.category })
        return PluginCategory.allCases
            .filter { present.contains($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 按分类 + 搜索词过滤后的插件。
    private var filteredPlugins: [any SuperPlugin] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return plugins.filter { plugin in
            let metadata = plugin.metadata
            let matchesCategory = selectedCategory.map { metadata.category == $0 } ?? true
            let matchesKeyword = keyword.isEmpty
                || metadata.name.localizedCaseInsensitiveContains(keyword)
                || plugin.id.localizedCaseInsensitiveContains(keyword)
                || metadata.description.localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesKeyword
        }
    }

    private var selectedPlugin: (any SuperPlugin)? {
        if let selectedPluginID,
           let plugin = plugins.first(where: { $0.id == selectedPluginID }) {
            return plugin
        }
        return filteredPlugins.first ?? plugins.first
    }

    /// 当前列表中处于有效启用状态的可配置插件数。
    private var enabledCount: Int {
        plugins.filter { viewModel.isEnabled(id: $0.id) }.count
    }

    // MARK: - List Pane

    private var pluginListPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AppSearchBar(
                    text: $searchText,
                    placeholder: "Search Plugins"
                )

                // 分类筛选标签栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        categoryChip(title: String(localized: "All", bundle: .module), isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(availableCategories, id: \.self) { category in
                            categoryChip(title: category.displayName, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                }
            }
            .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredPlugins, id: \.id) { plugin in
                        PluginListRow(
                            plugin: plugin,
                            isSelected: selectedPluginID == plugin.id,
                            isEnabled: viewModel.isEnabled(id: plugin.id)
                        ) {
                            selectedPluginID = plugin.id
                        }
                        .id("\(plugin.id)-\(viewModel.revision)")
                    }

                    if filteredPlugins.isEmpty {
                        AppEmptyState(
                            icon: "magnifyingglass",
                            title: String(localized: "No Plugins Found", bundle: .module)
                        )
                        .padding(.vertical, 32)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? theme.primary.opacity(0.14) : theme.textSecondary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var pluginDetailPane: some View {
        if let selectedPlugin {
            PluginSettingsDetailView(viewModel: viewModel, plugin: selectedPlugin, docsProvider: docsProvider)
                .id(viewModel.revision)
        } else {
            AppEmptyState(
                icon: "puzzlepiece.extension",
                title: String(localized: "Select a Plugin", bundle: .module)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}