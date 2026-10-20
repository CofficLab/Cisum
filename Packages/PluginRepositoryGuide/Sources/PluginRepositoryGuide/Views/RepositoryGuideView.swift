import LumiUI
import SwiftUI

/// 空仓库引导面板。
///
/// 呈现时机：仓库为空、且仓库视图收起（控制区占满窗口）时，出现在窗口顶部
/// 主要区域。
///
/// 引导只做一件事：告诉用户**仓库视图在哪**——控制按钮组最左边那颗「⋯」
/// 就是展开/收起仓库视图的开关，引导面板就贴在它上方。
///
/// **刻意不提示拖放**：拖放是仓库视图的能力。在引导里教「把文件拖进来」，
/// 会让用户以为引导面板能接文件，反而不知道真正的拖放入口在仓库视图里。
struct RepositoryGuideView: View {
    @LumiTheme private var appTheme

    var body: some View {
        VStack(spacing: 16) {
            header
            Spacer(minLength: 0)
            repositoryHint
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 区块

    private var header: some View {
        VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(appTheme.surface.opacity(0.72))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(appTheme.primary)
                }
                .shadowSm()

            Text(String(localized: "Start using Cisum", bundle: .module))
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(appTheme.textPrimary)

            Text(String(localized: "Put your music in the repository", bundle: .module))
                .font(.system(size: 12.5))
                .foregroundStyle(appTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    /// 指向控制按钮组里的「⋯」按钮——它按下就会展开仓库视图。
    private var repositoryHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(appTheme.textTertiary)

            // 和控制按钮组里那颗「⋯」长得一模一样，方便用户一眼对上。
            Image(systemName: "ellipsis")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(appTheme.textSecondary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(DesignTokens.Material.glassUltra))
                .overlay(
                    Circle()
                        .stroke(appTheme.textSecondary.opacity(0.12), lineWidth: 1)
                )
                .shadow(
                    color: DesignTokens.Shadow.subtle,
                    radius: 4,
                    y: 1
                )

            Text(String(localized: "Tap the ⋯ button below to open the repository", bundle: .module))
                .font(.system(size: 13))
                .foregroundStyle(appTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("cisum.repository.guide.hint")
    }
}
