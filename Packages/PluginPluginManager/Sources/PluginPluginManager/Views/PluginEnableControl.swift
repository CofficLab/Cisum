import CisumUIComponents
import CisumKernelSupport
import SwiftUI

/// 展示并控制单个插件的启用状态（对齐 Lumi `PluginPluginManager.PluginEnableControl`）。
///
/// 关闭 / 打开开关会调用 `PluginManaging.enablePlugin / disablePlugin`，
/// 完成运行期启停 + 贡献重建 + 持久化（写入 `PluginManagerStateStore`），
/// 并随 `.cisumEnabledPluginsDidChange` 通知自动刷新。
///
/// 不可配置的插件（alwaysOn / disabled）不渲染开关，只展示对应的策略标签。
struct PluginEnableControl: View {
    @LumiTheme private var theme

    @ObservedObject var viewModel: PluginManagementViewModel
    let plugin: any SuperPlugin

    /// 切换进行中标记：避免快速连点触发并发启停的竞态。
    @State private var isUpdating = false

    var body: some View {
        Group {
            if plugin.metadata.policy.isConfigurable {
                Toggle(isOn: Binding(
                    get: { viewModel.isEnabled(id: plugin.id) },
                    set: { newValue in toggle(newValue) }
                )) {
                    Text("Enable")
                        .font(.appBody)
                        .foregroundStyle(theme.textPrimary)
                }
                .toggleStyle(.switch)
                .disabled(isUpdating) // 切换期间短暂禁用，防止连点
            } else {
                policyTag
            }
        }
    }

    /// 触发运行期启停。管理 Provider 会写入用户覆盖并重建贡献；
    /// 失败时状态保持原样，开关随通知自动回落。
    private func toggle(_ newValue: Bool) {
        guard !isUpdating else { return }
        isUpdating = true
        let id = plugin.id
        Task { @MainActor in
            defer { isUpdating = false }
            if newValue {
                _ = await viewModel.setEnabled(true, for: id)
            } else {
                _ = await viewModel.setEnabled(false, for: id)
            }
        }
    }

    @ViewBuilder
    private var policyTag: some View {
        switch plugin.metadata.policy {
        case .required, .alwaysOn:
            AppTag(
                String(localized: "Always Enabled", bundle: .module),
                systemImage: "lock.fill",
                style: .accent
            )
        case .disabled:
            AppTag(
                String(localized: "Disabled", bundle: .module),
                systemImage: "minus.circle",
                style: .subtle
            )
        case .enabledByDefault, .disabledByDefault:
            EmptyView()
        }
    }
}
