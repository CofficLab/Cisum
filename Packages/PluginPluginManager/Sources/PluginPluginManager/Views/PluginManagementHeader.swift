import CisumUIComponents
import LumiUI
import SwiftUI

/// 插件管理页头部统计（对齐 Lumi `PluginPluginManager.PluginManagementHeader`）：
/// 展示当前可配置插件总数与已启用数量。
///
/// 由 `PluginManagementView` 内部使用。
struct PluginManagementHeader: View {
    @LumiTheme private var theme

    /// 可配置插件总数（与列表口径一致）。
    let totalCount: Int

    /// 当前已启用的可配置插件数。
    let enabledCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Label(
                "\(totalCount) plugins",
                systemImage: "puzzlepiece.extension"
            )
            Text("\(enabledCount) enabled")
            Spacer()
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }
}
