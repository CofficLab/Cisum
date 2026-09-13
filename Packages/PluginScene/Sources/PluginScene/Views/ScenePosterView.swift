import CisumUIComponents
import ProviderScene
import SwiftUI

/// 场景海报视图 —— 由 PluginScene 自实现。
///
/// 展示单个场景的图标、名称、简介与进入按钮；点击进入后调用场景
/// Provider 的 `setCurrentScene` 并关闭海报弹窗。不再依赖其他插件
/// 的 `addPosterView()` 贡献。
struct ScenePosterView: View {
    let iconName: String
    let title: String
    let description: String
    let enterTitle: String
    let enterAction: @MainActor () -> Void
    let dismissAction: @MainActor () -> Void
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 52))
                .foregroundStyle(theme.primary)
                .frame(width: 110, height: 110)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(
                            colors: [
                                theme.primary.opacity(0.18),
                                theme.primarySecondary.opacity(0.22),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )

            Text(title)
                .font(.title2.weight(.semibold))

            Text(description)
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: {
                enterAction()
                dismissAction()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle")
                    Text(enterTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(minWidth: 210, maxWidth: 280, minHeight: 44)
            }
        }
        .padding()
    }
}
