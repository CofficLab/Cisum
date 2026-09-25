import CisumUIComponents
import CisumKernel
import SwiftUI

/// 插件管理页左侧列表中的单行渲染（对齐 Lumi `PluginPluginManager.PluginListRow`）。
///
/// 行为完全对齐 Lumi：左侧展示分类图标 + 启用状态点，
/// 右侧两行文字（名称 + 描述），整体被 `AppListRow` 包裹以提供选中态。
///
/// 仅供 `PluginManagementView` 内部使用。
struct PluginListRow: View {
    @LumiTheme private var theme

    /// 列表行绑定的目标插件。
    let plugin: any SuperPlugin

    /// 当前是否处于选中状态。
    let isSelected: Bool

    /// 当前是否有效启用（考虑策略 + 用户覆盖）。
    let isEnabled: Bool

    /// 点击整行触发的回调，用于通知父视图更新选中项。
    let onSelect: () -> Void

    var body: some View {
        AppListRow(isSelected: isSelected, action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                leadingAccessory
                textContent
            }
        }
    }

    // MARK: - Subviews

    /// 左侧图标 + 启用状态指示点。
    private var leadingAccessory: some View {
        VStack(spacing: 6) {
            Image(systemName: type(of: plugin).metadata.iconName)
                .font(.appBody)
                .foregroundStyle(isSelected ? theme.primary : theme.textSecondary)
                .frame(width: 22, height: 22)

            Circle()
                .fill(isEnabled ? theme.success : theme.textTertiary.opacity(0.5))
                .frame(width: 6, height: 6)
        }
        .frame(width: 22)
    }

    /// 右侧文本：名称 + 描述（描述为空时回退到 plugin.id）。
    private var textContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(type(of: plugin).metadata.displayName)
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
            }

            Text(type(of: plugin).metadata.description.isEmpty ? plugin.id : type(of: plugin).metadata.description)
                .font(.appMicro)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
